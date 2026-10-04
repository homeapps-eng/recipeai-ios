import Foundation
import AVFoundation
import UIKit
import Combine

enum PendingCameraAction {
    case generateRecipes
    case calculateCalories
}

@MainActor
final class CameraViewModel: NSObject, ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var isCameraAuthorized = false
    @Published var isLoading = false
    @Published var loadingMode: AILoadingMode = .analyzingImage
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showActionSheet = false
    @Published var showAdPrompt = false

    let captureSession = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.homeapps.recipeai.camera-session")
    /// The capture as a 512px JPEG, base64-encoded, ready to send to the API.
    private var uploadImageBase64: String?
    private let adManager = AdManager.shared
    private let usageTracker = RecipeUsageTracker.shared
    private var pendingAction: PendingCameraAction?

    override init() {
        super.init()
        setupCaptureSession()
        Self.removeLegacyCaptures()
    }

    // MARK: - Camera Permission

    func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isCameraAuthorized = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.isCameraAuthorized = granted
                }
            }
        case .denied, .restricted:
            isCameraAuthorized = false
        @unknown default:
            isCameraAuthorized = false
        }
    }

    // MARK: - Capture Session Setup

    private func setupCaptureSession() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)

            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }

            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
            }

            captureSession.sessionPreset = .photo
        } catch {
            // Camera setup failed
        }
    }

    // MARK: - Capture Photo

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func retakePhoto() {
        capturedImage = nil
        uploadImageBase64 = nil

        // Restart capture session
        let session = captureSession
        sessionQueue.async {
            session.startRunning()
        }
    }

    // MARK: - Generate Recipes

    func generateRecipes() async -> [Recipe] {
        guard let base64Image = uploadImageBase64 else { return [] }

        // Check usage limits
        guard usageTracker.canGenerateRecipe else {
            pendingAction = .generateRecipes
            showAdPrompt = true
            return []
        }

        loadingMode = .generatingRecipes
        isLoading = true

        do {
            // Make API request
            let formData = [
                "image": base64Image,
                "language": UserDefaultsManager.shared.selectedLanguage.rawValue
            ]
            let response: RecipeResponse = try await NetworkManager.shared.requestFormEncoded(
                endpoint: .generateRecipes,
                formData: formData
            )

            if response.success, let recipes = response.recipes {
                let recipeList = recipes.map { $0.recipe }

                // Increment usage
                usageTracker.incrementRecipeCount(by: recipeList.count)
                usageTracker.incrementButtonPressCount()

                isLoading = false
                return recipeList
            } else {
                throw RecipeError.generationFailed(response.message ?? "No recipes generated")
            }
        } catch {
            isLoading = false
            errorMessage = "Unable to generate recipes. Please try again with a clearer photo."
            showError = true
            return []
        }
    }

    // MARK: - Calculate Calories

    func calculateCalories() async -> CaloriesResponse? {
        guard let base64Image = uploadImageBase64 else { return nil }

        // Check usage limits
        guard usageTracker.canCalculateCalories else {
            pendingAction = .calculateCalories
            showAdPrompt = true
            return nil
        }

        loadingMode = .calculatingCalories
        isLoading = true

        do {
            // Make API request
            let formData = [
                "image": base64Image,
                "language": UserDefaultsManager.shared.selectedLanguage.rawValue
            ]
            let response: CaloriesResponse = try await NetworkManager.shared.requestFormEncoded(
                endpoint: .calculateCalories,
                formData: formData
            )

            if response.success {
                // Increment usage
                usageTracker.incrementCaloriesCount()

                isLoading = false
                return response
            } else {
                throw RecipeError.caloriesCalculationFailed(response.message ?? "Calculation failed")
            }
        } catch {
            isLoading = false
            errorMessage = "Unable to calculate calories. Please try again with a clearer photo."
            showError = true
            return nil
        }
    }

    // MARK: - Ad Handling

    func watchAdAndContinue(onRecipesGenerated: @escaping ([Recipe]) -> Void, onCaloriesCalculated: @escaping (CaloriesResponse) -> Void) {
        showAdPrompt = false

        // Use retry logic to wait for alert to dismiss
        adManager.showRewardedAdWhenReady(
            onReward: { [weak self] in
                guard let self = self else { return }

                // Grant extra usage based on pending action
                switch self.pendingAction {
                case .generateRecipes:
                    self.usageTracker.grantExtraRecipeGeneration()
                    Task {
                        let recipes = await self.generateRecipes()
                        if !recipes.isEmpty {
                            onRecipesGenerated(recipes)
                        }
                    }
                case .calculateCalories:
                    self.usageTracker.grantExtraCaloriesCalculation()
                    Task {
                        if let response = await self.calculateCalories() {
                            onCaloriesCalculated(response)
                        }
                    }
                case .none:
                    break
                }

                self.pendingAction = nil
            },
            onError: { [weak self] errorMessage in
                self?.errorMessage = errorMessage
                self?.showError = true
                self?.pendingAction = nil
            }
        )
    }

    func dismissAdPrompt() {
        showAdPrompt = false
        pendingAction = nil
    }

    // MARK: - Image Processing

    private func didCapture(preview: UIImage, uploadImageBase64: String) {
        // Stop capture session
        let session = captureSession
        sessionQueue.async {
            session.stopRunning()
        }

        self.uploadImageBase64 = uploadImageBase64
        capturedImage = preview
    }

    /// Earlier versions saved every capture to Documents and never read or
    /// deleted it. Remove what they left behind.
    private nonisolated static func removeLegacyCaptures() {
        Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let files = (try? fileManager.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil)) ?? []
            for file in files where file.lastPathComponent.hasPrefix("captured_") && file.pathExtension == "jpg" {
                try? fileManager.removeItem(at: file)
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if error != nil {
            return
        }

        guard let imageData = photo.fileDataRepresentation() else {
            return
        }

        // Decode off the main thread, and only at the sizes actually used:
        // screen size for the preview and 512px for the Gemini API. Both have
        // the EXIF orientation applied.
        Task.detached(priority: .userInitiated) {
            guard let preview = ImageDownsampler.image(from: imageData, maxPixelSize: 2048),
                  let upload = ImageDownsampler.image(from: imageData, maxPixelSize: 512)?
                    .jpegData(compressionQuality: 0.6) else {
                return
            }

            await self.didCapture(preview: preview, uploadImageBase64: upload.base64EncodedString())
        }
    }
}

// MARK: - UIImage Extension

extension UIImage {
    func resizedForAPI(maxDimension: CGFloat) -> UIImage {
        let currentMax = max(size.width, size.height)
        guard currentMax > maxDimension else { return self }

        let scale = maxDimension / currentMax
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
