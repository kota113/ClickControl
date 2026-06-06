import AppKit

final class FrontmostAppGate {
    private let targetBundleIds: Set<String> = [
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "com.apple.Safari",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "company.thebrowser.Browser",
        "org.mozilla.firefox"
    ]
    
    func currentBundleIdentifier() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
    
    func isTargetBrowserActive() -> Bool {
        guard let bundleId = currentBundleIdentifier() else { return false }
        return targetBundleIds.contains(bundleId)
    }
}
