import Foundation
#if canImport(AppIntents)
import AppIntents

@available(iOS 17.0, *)
struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Task"
    @Parameter(title: "Task ID") var id: String

    func perform() async throws -> some IntentResult {
        // TODO: Toggle a task in the shared store (App Group Core Data or snapshot)
        // For now, just succeed.
        return .result()
    }
}
#endif
