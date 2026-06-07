import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appState = AppState()
    
    private var menuBarController: MenuBarController?
    private let frontmostAppGate = FrontmostAppGate()
    private let forceClickPressureMonitor = ForceClickPressureMonitor()
    private let syntheticClickSender = SyntheticClickSender()
    private let trackpadSettingsController = TrackpadSettingsController()
    private let permissionController = PermissionController()
    private var permissionRefreshTimer: Timer?
    private var isFrontmostAppObservationStarted = false
 
    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController(appState: appState)
        menuBarController?.onOpenAccessibilitySettings = { [weak self] in
            self?.permissionController.openAccessibilitySettings()
            self?.startPermissionRefreshTimerIfNeeded()
        }
        menuBarController?.onEnabledChanged = { [weak self] in
            self?.updateFrontmostAppStatus()
        }
        menuBarController?.onRestoreForceClickSetting = { [weak self] in
            self?.restoreForceClickSetting()
        }

        forceClickPressureMonitor.onForceClickBegan = { [weak self] in
            self?.handleForceClickBegan()
        }
        forceClickPressureMonitor.onForceClickEnded = { [weak self] in
            self?.handleForceClickEnded(sendMouseUp: true)
        }

        if !permissionController.isTrusted() {
            permissionController.requestTrustPrompt()
        }

        refreshPermissionStatus()
        startPermissionRefreshTimerIfNeeded()

        if permissionController.isTrusted() {
            startMonitoring()
        }
    }

    private func refreshPermissionStatus() {
        let isTrusted = permissionController.isTrusted()

        menuBarController?.updatePermissionStatus(isTrusted: isTrusted)

        if !isTrusted {
            menuBarController?.updateStatus("Permission required")
        }
    }

    private func startPermissionRefreshTimerIfNeeded() {
        guard !permissionController.isTrusted() else {
            permissionRefreshTimer?.invalidate()
            permissionRefreshTimer = nil
            return
        }

        guard permissionRefreshTimer == nil else {
            return
        }

        permissionRefreshTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            guard let self else {
                return
            }

            guard self.permissionController.isTrusted() else {
                return
            }

            self.permissionRefreshTimer?.invalidate()
            self.permissionRefreshTimer = nil
            self.refreshPermissionStatus()
            self.startMonitoring()
        }
    }

    private func startMonitoring() {
        forceClickPressureMonitor.start()
        startFrontmostAppObservation()
        updateFrontmostAppStatus()
    }
    
    private func startFrontmostAppObservation() {
        guard !isFrontmostAppObservationStarted else {
            return
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(frontmostAppDidChange),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        isFrontmostAppObservationStarted = true
    }
    
    @objc
    private func frontmostAppDidChange(_ notification: Notification) {
        updateFrontmostAppStatus()
    }
    
    private func updateFrontmostAppStatus() {
        guard permissionController.isTrusted() else {
            menuBarController?.updateStatus("Permission required")
            return
        }

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
        permissionRefreshTimer?.invalidate()
        syntheticClickSender.releaseCommandShiftIfNeeded()
        forceClickPressureMonitor.stop()
        trackpadSettingsController.restoreSynchronouslyOnTerminate()
    }
    
    deinit {
        permissionRefreshTimer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        syntheticClickSender.releaseCommandShiftIfNeeded()
        forceClickPressureMonitor.stop()
        trackpadSettingsController.restoreSynchronouslyOnTerminate()
    }
}
