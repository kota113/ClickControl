import Foundation
import CoreGraphics

final class SyntheticClickSender {
    private var areCommandShiftPressed = false

    func pressCommandShiftIfNeeded() {
        guard !areCommandShiftPressed else {
            return
        }

        guard
            let commandDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x37, keyDown: true),
            let shiftDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x38, keyDown: true)
        else {
            print("[SyntheticClickSender] failed to create modifier down events")
            return
        }

        commandDown.flags = .maskCommand
        shiftDown.flags = [.maskCommand, .maskShift]

        commandDown.post(tap: .cghidEventTap)
        shiftDown.post(tap: .cghidEventTap)

        areCommandShiftPressed = true
        print("[SyntheticClickSender] pressed Cmd+Shift")
    }

    func sendCommandShiftMouseUpAtCurrentLocationIfNeeded() {
        guard areCommandShiftPressed else {
            return
        }

        guard let mouseUp = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseUp,
            mouseCursorPosition: CGEvent(source: nil)?.location ?? .zero,
            mouseButton: .left
        ) else {
            print("[SyntheticClickSender] failed to create Cmd+Shift mouseUp")
            return
        }

        mouseUp.flags = [.maskCommand, .maskShift]
        mouseUp.post(tap: .cghidEventTap)

        let location = mouseUp.location
        print(
            String(
                format: "[SyntheticClickSender] sent Cmd+Shift+MouseUp at (%.1f, %.1f)",
                location.x,
                location.y
            )
        )
    }

    func releaseCommandShiftIfNeeded() {
        guard areCommandShiftPressed else {
            return
        }

        guard
            let shiftUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x38, keyDown: false),
            let commandUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x37, keyDown: false)
        else {
            print("[SyntheticClickSender] failed to create modifier up events")
            return
        }

        shiftUp.flags = .maskCommand
        shiftUp.post(tap: .cghidEventTap)
        commandUp.post(tap: .cghidEventTap)

        areCommandShiftPressed = false
        print("[SyntheticClickSender] released Cmd+Shift")
    }
}
