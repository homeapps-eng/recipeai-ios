import SwiftUI

struct VoiceView: View {
    @StateObject private var viewModel = VoiceRecipeViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isEditingRequest: Bool
    /// The request box appears with the first words heard and then stays, so
    /// that it does not vanish while the user clears it to type something else.
    @State private var showRequest = false

    var onRecipesGenerated: ([Recipe]) -> Void

    private var hasRequest: Bool {
        !viewModel.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Button {
                    viewModel.stopListening()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .foregroundColor(.textPrimary)
                }
                Spacer()
                Text("Voice Recipe")
                    .font(.appHeadline)
                Spacer()
                // Invisible spacer for centering
                Image(systemName: "xmark")
                    .font(.title3)
                    .opacity(0)
            }
            .padding(.horizontal)

            // Everything about speaking makes room for the keyboard while the
            // request is being edited
            if !isEditingRequest {
                // Instructions
                Text("Tap the microphone and tell us what recipe you'd like!")
                    .font(.appSubheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Language notice
                if let notice = viewModel.voiceLanguageNotice {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                        Text(notice)
                            .font(.appCaption1)
                            .foregroundColor(.textSecondary)
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }

                Spacer()

                // Mic Button
                Button {
                    viewModel.toggleListening()
                } label: {
                    ZStack {
                        Circle()
                            .fill(viewModel.isListening ? Color.brandGreen : Color.brandGreenLight)
                            .frame(width: 120, height: 120)
                            .shadow(color: viewModel.isListening ? .brandGreen.opacity(0.5) : .clear, radius: 16)

                        Image(systemName: "mic.fill")
                            .font(.system(size: 44))
                            .foregroundColor(viewModel.isListening ? .white : .brandGreen)
                    }
                }
                .disabled(viewModel.isGenerating)
                .scaleEffect(viewModel.isListening ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: viewModel.isListening)

                // Status
                Text(viewModel.statusMessage)
                    .font(.appSubheadline)
                    .foregroundColor(.brandGreen)
            }

            // Transcribed Text, which the user can correct before generating
            if showRequest {
                TextField("Type your request", text: $viewModel.transcribedText, axis: .vertical)
                    .font(.appBody)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1...6)
                    .focused($isEditingRequest)
                    .submitLabel(.done)
                    .onSubmit {
                        isEditingRequest = false
                    }
                    .disabled(viewModel.isListening || viewModel.isGenerating)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.backgroundSecondary)
                    .cornerRadius(12)
                    .padding(.horizontal)
            }

            Spacer()

            // Generate Button
            if showRequest {
                Button {
                    isEditingRequest = false
                    Task {
                        let recipes = await viewModel.generateRecipes()
                        if !recipes.isEmpty {
                            dismiss()
                            onRecipesGenerated(recipes)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isGenerating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(viewModel.isGenerating ? "Generating..." : "Generate Recipes")
                    }
                    .font(.appHeadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.brandGreen)
                    .cornerRadius(16)
                }
                .disabled(viewModel.isGenerating || !hasRequest)
                .opacity(hasRequest ? 1 : 0.5)
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .animation(.easeInOut(duration: 0.2), value: isEditingRequest)
        // A tap outside the request box ends editing
        .contentShape(Rectangle())
        .onTapGesture {
            isEditingRequest = false
        }
        .onChange(of: viewModel.transcribedText) { _, text in
            if !text.isEmpty {
                showRequest = true
            }
            // A box that grows over several lines takes Return as a new line;
            // here it means the user is done.
            if text.contains("\n") {
                viewModel.transcribedText = text.replacingOccurrences(of: "\n", with: " ")
                isEditingRequest = false
            }
        }
        .onAppear {
            viewModel.requestPermissions()
        }
        .onDisappear {
            viewModel.stopListening()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("Daily Limit Reached", isPresented: $viewModel.showAdPrompt) {
            Button("Watch Ad") {
                viewModel.watchAdAndContinue {
                    Task {
                        let recipes = await viewModel.generateRecipes()
                        if !recipes.isEmpty {
                            dismiss()
                            onRecipesGenerated(recipes)
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You've reached your daily limit. Watch a short ad to continue.")
        }
    }
}
