import SwiftUI

// Sync the app's selected accent color into the App Group so widgets can read it.

extension ThemeManager {
    func syncAccentToAppGroup() {
        #if os(iOS)
        let suite = UserDefaults(suiteName: APP_GROUP_ID)
        // Persist the same key the app uses
        suite?.set(self.accentColor.rawValue, forKey: "accentColor")
        suite?.synchronize()
        #endif
    }
}
