import Foundation
import AVFoundation
import UIKit

@MainActor
final class CameraViewModel: NSObject, ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var isCameraAuthorized = false
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showActionSheet = false

    let captureSession = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var capturedImagePath: String?

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
            print("Error setting up camera: \(error)")
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
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    // MARK: - Generate Recipes

    func generateRecipes() async -> [Recipe] {
        guard let image = capturedImage else { return [] }

        // Check usage limits
        guard RecipeUsageTracker.shared.canGenerateRecipe else {
            errorMessage = "Daily limit reached. Watch an ad to get more recipes!"
            showError = true
            return []
        }

        isLoading = true

        do {
            // Convert image to base64
            guard let base64Image = imageToBase64(image) else {
                throw RecipeError.generationFailed("Failed to process image")
            }

            // Make API request
            let formData = ["image": base64Image]
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
                RecipeUsageTracker.shared.incrementRecipeCount(by: recipeList.count)
                RecipeUsageTracker.shared.incrementButtonPressCount()

                isLoading = false
                return recipeList
            } else {
                throw RecipeError.generationFailed(response.message ?? "No recipes generated")
            }
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            showError = true
            return []
        }
    }

    // MARK: - Calculate Calories

    func calculateCalories() async -> CaloriesResponse? {
        guard let image = capturedImage else { return nil }

        isLoading = true

        do {
            // Convert image to base64
            guard let base64Image = imageToBase64(image) else {
                throw RecipeError.caloriesCalculationFailed("Failed to process image")
            }

            // Make API request
            let formData = ["image": base64Image]
            let response: CaloriesResponse = try await NetworkManager.shared.requestFormEncoded(
                endpoint: .calculateCalories,
                formData: formData
            )

            if response.success {
                isLoading = false
                return response
            } else {
                throw RecipeError.caloriesCalculationFailed(response.message ?? "Calculation failed")
            }
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            showError = true
            return nil
        }
    }

    // MARK: - Image Processing

    private func imageToBase64(_ image: UIImage, quality: CGFloat = 0.8) -> String? {
        // Fix orientation
        let fixedImage = image.fixedOrientation()

        // Compress image
        guard let imageData = fixedImage.jpegData(compressionQuality: quality) else {
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
            print("Error saving image: \(error)")
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
        if let error = error {
            print("Error capturing photo: \(error)")
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
}
