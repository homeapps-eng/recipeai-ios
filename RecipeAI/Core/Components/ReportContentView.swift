import SwiftUI

/// "Report" for AI-generated recipes and calorie estimates: what's wrong, and
/// optional details. The report goes to support through the support endpoint,
/// which emails it and keeps it in Firestore (support_requests).
struct ReportContentView: View {
    /// Names the content in the report, e.g. "Recipe: Pad thai (id 42)".
    let subject: String

    @Environment(\.dismiss) private var dismiss
    @State private var reason = Reason.offensive
    @State private var details = ""
    @State private var isSending = false
    @State private var resultMessage: String?
    @State private var didSend = false

    enum Reason: String, CaseIterable, Identifiable {
        case offensive, unsafe, wrong, other
        var id: String { rawValue }

        var label: String {
            switch self {
            case .offensive: return "Offensive or inappropriate"
            case .unsafe: return "Unsafe, for example an allergy or food-safety risk"
            case .wrong: return "Wrong or doesn't make sense"
            case .other: return "Something else"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("What's wrong with it?") {
                    Picker("Reason", selection: $reason) {
                        ForEach(Reason.allCases) { reason in
                            Text(reason.label).tag(reason)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("More details (optional)") {
                    TextField("Details", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSending {
                        ProgressView()
                    } else {
                        Button("Send") { Task { await send() } }
                    }
                }
            }
            .alert(resultMessage ?? "", isPresented: Binding(
                get: { resultMessage != nil },
                set: { if !$0 { resultMessage = nil } }
            )) {
                Button("OK") {
                    if didSend { dismiss() }
                }
            }
        }
    }

    private func send() async {
        isSending = true
        defer { isSending = false }

        let defaults = UserDefaultsManager.shared
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        var lines = [
            "[AI content report]",
            "Reason: \(reason.rawValue)",
            subject,
        ]
        let trimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { lines.append("Details: \(trimmed)") }
        lines.append("User: \(defaults.userId ?? "unknown")")
        lines.append("App: iOS \(version) (\(build))")

        // The support endpoint needs an email address; guests don't have one.
        let email = defaults.userEmail.flatMap { $0.contains("@") ? $0 : nil } ?? "guest@recipe-ai.io"

        do {
            let _: SupportResponse = try await NetworkManager.shared.post(
                endpoint: .submitSupport,
                body: SupportRequest(email: email, message: lines.joined(separator: "\n"))
            )
            didSend = true
            resultMessage = "Thanks. We'll review it."
        } catch {
            resultMessage = "The report couldn't be sent. Please check your connection and try again."
        }
    }
}

#Preview {
    ReportContentView(subject: "Recipe: Pad thai (id 42)")
}
