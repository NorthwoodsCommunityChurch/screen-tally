import AppKit
import Observation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var tslListener: TSLListener!
    private var statusBarController: StatusBarController!
    private var borderOverlayController: BorderOverlayController!
    private var observationTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            // Initialize components
            tslListener = TSLListener()
            statusBarController = StatusBarController()
            statusBarController.configure(tslListener: tslListener)
            borderOverlayController = BorderOverlayController()

            // Setup the border overlay window
            borderOverlayController.setup()

            // Start listening on configured port
            tslListener.startListening(port: UInt16(AppSettings.shared.port))

            // Observe tally changes
            startObserving()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        observationTask?.cancel()
        Task { @MainActor in
            statusBarController?.teardown()
            tslListener?.stopListening()
            borderOverlayController?.teardown()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        return true
    }

    // MARK: - Observation

    @MainActor private func startObserving() {
        observationTask = Task { @MainActor in
            while !Task.isCancelled {
                withObservationTracking {
                    let settings = AppSettings.shared
                    let liveTally = tslListener.monitoredTally
                    let isConnected = tslListener.isConnected
                    let _ = settings.showBorderOnPreview
                    let _ = settings.borderThickness

                    let tally = settings.debugTallyOverride ?? liveTally

                    statusBarController.updateIcon(for: tally, isConnected: isConnected || settings.debugTallyOverride != nil)
                    borderOverlayController.updateTally(tally)
                } onChange: {
                    // Continue loop on change
                }

                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }
}
