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
    private var capturedImagePath: String?
    private let adManager = AdManager.shared
    private let usageTracker = RecipeUsageTracker.shared
    private var pendingAction: PendingCameraAction?

    override init() {
        super.init()
        setupCaptureSession()
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
        capturedImagePath = nil

        // Restart capture session
        let session = captureSession
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    // MARK: - Generate Recipes

    func generateRecipes() async -> [Recipe] {
        guard let image = capturedImage else { return [] }

        // Check usage limits
        guard usageTracker.canGenerateRecipe else {
            pendingAction = .generateRecipes
            showAdPrompt = true
            return []
        }

        loadingMode = .generatingRecipes
        isLoading = true

        do {
            // Convert image to base64
            guard let base64Image = imageToBase64(image) else {
                throw RecipeError.generationFailed("Failed to process image")
            }

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
                let recipeList = recipes.map { generated -> Recipe in
                    var recipe = generated.recipe
                    recipe.capturedImagePath = capturedImagePath
                    return recipe
                }

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
        guard let image = capturedImage else { return nil }

        // Check usage limits
        guard usageTracker.canCalculateCalories else {
            pendingAction = .calculateCalories
            showAdPrompt = true
            return nil
        }

        loadingMode = .calculatingCalories
        isLoading = true

        do {
            // Convert image to base64
            guard let base64Image = imageToBase64(image) else {
                throw RecipeError.caloriesCalculationFailed("Failed to process image")
            }

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

    private func imageToBase64(_ image: UIImage) -> String? {
        // Fix orientation
        let fixedImage = image.fixedOrientation()

        // Resize image to max 512px for Gemini API
        let resizedImage = fixedImage.resizedForAPI(maxDimension: 512)

        // Compress with lower quality to reduce size
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.6) else {
            return nil
        }

        return imageData.base64EncodedString()
    }

    private func saveImageLocally(_ image: UIImage) -> String? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filename = "captured_\(UUID().uuidString).jpg"
        let filePath = documentsPath.appendingPathComponent(filename)

        guard let data = image.jpegData(compressionQuality: 0.8) else {
            return nil
        }

        do {
            try data.write(to: filePath)
            return filePath.path
        } catch {
            return nil
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

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            return
        }

        Task { @MainActor in
            // Stop capture session
            captureSession.stopRunning()

            // Save image locally
            capturedImagePath = saveImageLocally(image)

            // Update captured image
            capturedImage = image
        }
    }
}

// MARK: - UIImage Extension

extension UIImage {
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up {
            return self
        }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return normalizedImage ?? self
    }

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
