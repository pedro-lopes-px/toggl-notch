import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = NotchStore()
    private var controller: NotchPanelController?
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = NotchPanelController(store: store)
        self.controller = controller
        controller.show()
        statusItem = StatusItemController(store: store, panelController: controller)

        if KeychainStore.readToken() != nil {
            Task { await store.bootstrap() }
        }
    }

    /// The SwiftUI keepalive host window is ordered off-screen; the real UI is the
    /// borderless NSPanel. Without this, AppKit quits once the host window closes.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
