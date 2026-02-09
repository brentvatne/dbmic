import SwiftUI

@main
struct MicMeterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window — this is a menu-bar-only app.
        // Settings scene is provided for the standard Cmd+, shortcut,
        // but the primary settings UI is in the popover.
        Settings {
            EmptyView()
        }
    }
}
