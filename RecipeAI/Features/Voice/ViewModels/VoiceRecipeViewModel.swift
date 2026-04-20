import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
final class VoiceRecipeViewModel: NSObject, ObservableObject {
    @Published var transcribedText = ""
    @Published var isListening = false
    @Published var isGenerating = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var statusMessage = "Tap the mic to speak"
    @Published var showAdPrompt = false
    @Published var voiceLanguageNotice: String?

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let usageTracker = RecipeUsageTracker.shared
    private let adManager = AdManager.shared

    override init() {
        let selectedLanguage = UserDefaultsManager.shared.selectedLanguage
        let selectedLocale = selectedLanguage.locale
        let recognizer = SFSpeechRecognizer(locale: selectedLocale)
        if let recognizer, recognizer.isAvailable {
            speechRecognizer = recognizer
            voiceLanguageNotice = nil
        } else {
            speechRecognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            if selectedLanguage != .en {
                voiceLanguageNotice = "Voice input is not available in \(selectedLanguage.displayName). Speak in English — your recipes will still be generated in \(selectedLanguage.displayName)."
            }
        }
        super.init()
    }

    // MARK: - Permissions

    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                switch status {
                case .authorized:
                    break
                case .denied, .restricted, .notDetermined:
                    self?.errorMessage = "Speech recognition permission is required for voice input"
                    self?.showError = true
                @unknown default:
                    break
                }
            }
        }

        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                if !granted {
                    self?.errorMessage = "Microphone permission is required for voice input"
                    self?.showError = true
                }
            }
        }
    }

    // MARK: - Speech Recognition

    func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    func startListening() {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition is not available on this device"
            showError = true
            return
        }

        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            requestPermissions()
            return
        }

        // Stop any existing task
        stopListening()

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Failed to set up audio session"
            showError = true
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let result {
                    self.transcribedText = result.bestTranscription.formattedString

                    if result.isFinal {
                        self.isListening = false
                        self.statusMessage = "Tap Generate or speak again"
                    }
                }

                if let error {
                    let nsError = error as NSError
                    // Ignore cancellation errors (code 216 = request was cancelled, 1 = connection invalidated)
                    if nsError.domain == "kAFAssistantErrorDomain" && (nsError.code == 216 || nsError.code == 1) {
                        return
                    }
                    self.isListening = false
                    self.statusMessage = "Didn't catch that. Please try again."
                }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            statusMessage = "Listening..."
        } catch {
            errorMessage = "Failed to start audio engine"
            showError = true
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false

        if !transcribedText.isEmpty {
            statusMessage = "Tap Generate or speak again"
        } else {
            statusMessage = "Tap the mic to speak"
        }
    }

    // MARK: - Recipe Generation

    func generateRecipes() async -> [Recipe] {
        let prompt = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            errorMessage = "Please speak a recipe request first"
            showError = true
            return []
        }

        guard usageTracker.canGenerateRecipe else {
            showAdPrompt = true
            return []
        }

        isGenerating = true

        do {
            // Build form data with prompt and user preferences
            var formData: [String: String] = [
                "prompt": prompt,
                "language": UserDefaultsManager.shared.selectedLanguage.rawValue
            ]

            let preferences = UserDefaultsManager.shared.getPreferences()
            if let categories = preferences.categories, !categories.isEmpty {
                formData["categories"] = categories.joined(separator: ",")
            }
            if let cuisines = preferences.cuisines, !cuisines.isEmpty {
                formData["cuisine"] = cuisines.joined(separator: ",")
            }
            if let dietaryRestrictions = preferences.dietaryRestrictions, !dietaryRestrictions.isEmpty {
                let prefsJSON: [String: Any] = ["dietaryRestrictions": dietaryRestrictions]
                if let jsonData = try? JSONSerialization.data(withJSONObject: prefsJSON),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    formData["preferences"] = jsonString
                }
            }

            let response: RecipeResponse = try await NetworkManager.shared.requestFormEncoded(
                endpoint: .generateByText,
                formData: formData
            )

            if response.success, let recipes = response.recipes {
                let recipeList = recipes.map { $0.recipe }
                usageTracker.incrementRecipeCount(by: recipeList.count)
                usageTracker.incrementButtonPressCount()
                isGenerating = false
                return recipeList
            } else {
                throw RecipeError.generationFailed(response.message ?? "No recipes generated")
            }
        } catch {
            isGenerating = false
            errorMessage = error.localizedDescription
            showError = true
            return []
        }
    }

    // MARK: - Ad Handling

    func watchAdAndContinue(completion: @escaping () -> Void) {
        showAdPrompt = false
        adManager.showRewardedAdWhenReady(
            onReward: { [weak self] in
                Task { @MainActor in
                    self?.usageTracker.grantExtraRecipeGeneration()
                    completion()
                }
            },
            onError: { [weak self] errorMessage in
                Task { @MainActor in
                    self?.errorMessage = errorMessage
                    self?.showError = true
                }
            }
        )
    }

    nonisolated deinit {
        // Audio cleanup happens in onDisappear via stopListening()
    }
}
