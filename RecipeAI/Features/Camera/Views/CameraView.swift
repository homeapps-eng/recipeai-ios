import SwiftUI
import AVFoundation

struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CameraViewModel()

    var onRecipesGenerated: ([Recipe]) -> Void
    var onCaloriesCalculated: (CaloriesResponse) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                // Camera Preview or Image Preview
                if let capturedImage = viewModel.capturedImage {
                    imagePreview(capturedImage)
                } else {
                    cameraPreview
                }

                // Controls Overlay
                controlsOverlay
            }
            .navigationTitle(viewModel.capturedImage != nil ? "Preview" : "Take Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .alert("Choose Action", isPresented: $viewModel.showActionSheet) {
                Button("Generate Recipes") {
                    Task {
                        await generateRecipes()
                    }
                }
                Button("Calculate Calories") {
                    Task {
                        await calculateCalories()
                    }
                }
                Button("Retake Photo", role: .destructive) {
                    viewModel.retakePhoto()
                }
                Button("Cancel", role: .cancel) {}
            }
            .loadingOverlay(isLoading: viewModel.isLoading)
            .onAppear {
                viewModel.checkCameraPermission()
            }
        }
    }

    // MARK: - Camera Preview

    private var cameraPreview: some View {
        ZStack {
            if viewModel.isCameraAuthorized {
                CameraPreviewView(session: viewModel.captureSession)
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)

                    Text("Camera access required")
                        .font(.appHeadline)

                    Text("Please enable camera access in Settings to take photos.")
                        .font(.appSubheadline)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)

                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.primary)
                    .frame(width: 200)
                }
                .padding()
            }
        }
    }

    // MARK: - Image Preview

    private func imagePreview(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .ignoresSafeArea()
    }

    // MARK: - Controls Overlay

    private var controlsOverlay: some View {
        VStack {
            Spacer()

            if viewModel.capturedImage != nil {
                // Preview controls
                HStack(spacing: 40) {
                    Button {
                        viewModel.retakePhoto()
                    } label: {
                        VStack {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.title)
                            Text("Retake")
                                .font(.appCaption1)
                        }
                        .foregroundColor(.white)
                    }

                    Button {
                        viewModel.showActionSheet = true
                    } label: {
                        VStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                            Text("Use Photo")
                                .font(.appCaption1)
                        }
                        .foregroundColor(.brandGreen)
                    }
                }
                .padding(.bottom, 40)
            } else {
                // Camera controls
                HStack {
                    Spacer()

                    Button {
                        viewModel.capturePhoto()
                    } label: {
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 70, height: 70)
                            .overlay {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 60, height: 60)
                            }
                    }

                    Spacer()
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Actions

    private func generateRecipes() async {
        let recipes = await viewModel.generateRecipes()
        if !recipes.isEmpty {
            onRecipesGenerated(recipes)
        }
    }

    private func calculateCalories() async {
        if let response = await viewModel.calculateCalories() {
            onCaloriesCalculated(response)
        }
    }
}

// MARK: - Camera Preview UIViewRepresentable

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}

#Preview {
    CameraView(
        onRecipesGenerated: { _ in },
        onCaloriesCalculated: { _ in }
    )
}
