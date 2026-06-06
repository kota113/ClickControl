import Foundation
import CoreGraphics

final class AppState {
    var isEnabled: Bool = true

    var isTargetBrowserActive: Bool = false
    var frontmostBundleIdentifier: String?

    var forceClickTriggered: Bool = false
}
