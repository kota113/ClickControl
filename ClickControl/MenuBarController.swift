import AppKit

final class MenuBarController: NSObject {
    private let appState: AppState
    
    private var statusBarItem: NSStatusItem?
    private var enabledMenuItem: NSMenuItem?
    private var statusMenuItem: NSMenuItem?
    
    var onEnabledChanged: (() -> Void)?
    var onRestoreForceClickSetting: (() -> Void)?
    
    init(appState: AppState) {
        self.appState = appState
        super.init()
        setupStatusItem()
    }
    
    private func setupStatusItem() {
        let statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem.button {
            let image = NSImage(named: NSImage.Name("pointer-filled"))
            image?.size = NSSize(width: 16, height: 16)
            button.image = image
            button.image?.accessibilityDescription = "ClickControl Opener"
            button.image?.isTemplate = true
        }
        
        let menu = NSMenu()
        
        let enabledItem = NSMenuItem(
            title: "Enabled",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enabledItem.target = self
        enabledItem.state = appState.isEnabled ? .on : .off
        menu.addItem(enabledItem)
        self.enabledMenuItem = enabledItem
        
        let statusItem = NSMenuItem(
            title: "Status: Idle",
            action: nil,
            keyEquivalent: ""
        )
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        self.statusMenuItem = statusItem
        
        menu.addItem(.separator())

        let restoreItem = NSMenuItem(
            title: "Restore Force Click Setting",
            action: #selector(restoreForceClickSetting),
            keyEquivalent: ""
        )
        restoreItem.target = self
        menu.addItem(restoreItem)

        menu.addItem(.separator())
        
        let quitItem = NSMenuItem(
            title: "Quit", 
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusBarItem.menu = menu
        self.statusBarItem = statusBarItem
    }
    
    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc
    private func restoreForceClickSetting() {
        onRestoreForceClickSetting?()
    }
    
    @objc
    private func toggleEnabled() {
        appState.isEnabled.toggle()
        enabledMenuItem?.state = appState.isEnabled ? .on : .off
        updateStatus(appState.isEnabled ? "Enabled": "Disabled")
        
        onEnabledChanged?()
    }
    
    func updateStatus(_ status: String) {
        statusMenuItem?.title = "Status: \(status)"
    }
}
