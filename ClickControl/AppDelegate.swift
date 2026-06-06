import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appState = AppState()
    
    private var menuBarController: MenuBarController?
    private let frontmostAppGate = FrontmostAppGate()
    private let forceClickPressureMonitor = ForceClickPressureMonitor()
    private let syntheticClickSender = SyntheticClickSender()
    private let trackpadSettingsController = TrackpadSettingsController()
 
    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController(appState: appState)
        menuBarController?.onEnabledChanged = { [weak self] in
            self?.updateFrontmostAppStatus()
        }
        menuBarController?.onRestoreForceClickSetting = { [weak self] in
            self?.restoreForceClickSetting()
        }
        menuBarController?.updateStatus("Ready")

        forceClickPressureMonitor.onForceClickBegan = { [weak self] in
            self?.handleForceClickBegan()
        }
        forceClickPressureMonitor.onForceClickEnded = { [weak self] in
            self?.handleForceClickEnded(sendMouseUp: true)
        }
        forceClickPressureMonitor.start()
        
        startFrontmostAppObservation()
        updateFrontmostAppStatus()
    }
    
    private func startFrontmostAppObservation() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(frontmostAppDidChange),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }
    
    @objc
    private func frontmostAppDidChange(_ notification: Notification) {
        updateFrontmostAppStatus()
    }
    
    private func updateFrontmostAppStatus() {
        let bundleId = frontmostAppGate.currentBundleIdentifier()
        let isTarget = frontmostAppGate.isTargetBrowserActive()

        appState.frontmostBundleIdentifier = bundleId
        appState.isTargetBrowserActive = isTarget

        let shouldDisableForceClick = isTarget && appState.isEnabled

        trackpadSettingsController.setForceClickDisabledForTargetApp(
            shouldDisableForceClick
        )

        if !shouldDisableForceClick {
            forceClickPressureMonitor.reset()
            syntheticClickSender.releaseCommandShiftIfNeeded()
        }

        if shouldDisableForceClick {
            menuBarController?.updateStatus("Target Browser / Force Click Off")
        } else if appState.isEnabled {
            menuBarController?.updateStatus("Not Target")
        } else {
            menuBarController?.updateStatus("Disabled")
        }

        print("frontmost:", bundleId ?? "nil", "isTarget:", isTarget)
    }

    private func handleForceClickBegan() {
        guard appState.isEnabled else { return }
        guard appState.isTargetBrowserActive else { return }

        syntheticClickSender.pressCommandShiftIfNeeded()
        menuBarController?.updateStatus("Force Click Modifiers Down")
    }

    private func handleForceClickEnded(sendMouseUp: Bool) {
        if sendMouseUp {
            syntheticClickSender.sendCommandShiftMouseUpAtCurrentLocationIfNeeded()
        }

        syntheticClickSender.releaseCommandShiftIfNeeded()
        menuBarController?.updateStatus(
            appState.isTargetBrowserActive ? "Target Browser / Force Click Off" : "Not Target"
        )
    }

    private func restoreForceClickSetting() {
        trackpadSettingsController.restoreForceClickSetting()
        updateFrontmostAppStatus()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        syntheticClickSender.releaseCommandShiftIfNeeded()
        forceClickPressureMonitor.stop()
        trackpadSettingsController.restoreSynchronouslyOnTerminate()
    }
    
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        syntheticClickSender.releaseCommandShiftIfNeeded()
        forceClickPressureMonitor.stop()
        trackpadSettingsController.restoreSynchronouslyOnTerminate()
    }
}
