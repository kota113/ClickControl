import Foundation
import CoreFoundation

final class TrackpadSettingsController {
    private let applicationID = kCFPreferencesAnyApplication
    private let userName = kCFPreferencesCurrentUser
    private let hostName = kCFPreferencesAnyHost

    private let forceClickKey = "com.apple.trackpad.forceClick" as CFString

    private let queue = DispatchQueue(label: "TrackpadSettingsController.queue")

    private var originalValue: Bool?
    private var isCurrentlyDisabledByApp = false
    private var lastRequestedDisabledState: Bool?

    func setForceClickDisabledForTargetApp(_ shouldDisable: Bool) {
        queue.async { [weak self] in
            guard let self else { return }

            guard self.lastRequestedDisabledState != shouldDisable else {
                return
            }

            self.lastRequestedDisabledState = shouldDisable

            if shouldDisable {
                self.disableForceClickIfNeededOnQueue()
            } else {
                self.restoreForceClickIfNeededOnQueue()
            }
        }
    }

    func restoreSynchronouslyOnTerminate() {
        queue.sync {
            restoreForceClickIfNeededOnQueue()
        }
    }

    func restoreForceClickSetting() {
        queue.async { [weak self] in
            guard let self else { return }

            if self.isCurrentlyDisabledByApp {
                self.restoreForceClickIfNeededOnQueue()
                self.lastRequestedDisabledState = false
                return
            }

            self.writeForceClickValue(true)
            self.lastRequestedDisabledState = false
            print("[TrackpadSettingsController] manually restored forceClick to true")
        }
    }

    private func disableForceClickIfNeededOnQueue() {
        guard !isCurrentlyDisabledByApp else {
            return
        }

        if originalValue == nil {
            originalValue = readForceClickValue()
        }

        if readForceClickValue() != false {
            writeForceClickValue(false)
        }

        isCurrentlyDisabledByApp = true

        print(
            "[TrackpadSettingsController] disabled forceClick. original:",
            String(describing: originalValue)
        )
    }

    private func restoreForceClickIfNeededOnQueue() {
        guard isCurrentlyDisabledByApp else {
            return
        }

        if let originalValue {
            if readForceClickValue() != originalValue {
                writeForceClickValue(originalValue)
            }

            print("[TrackpadSettingsController] restored forceClick:", originalValue)
        } else {
            print("[TrackpadSettingsController] originalValue is nil. Nothing to restore.")
        }

        isCurrentlyDisabledByApp = false
        originalValue = nil
        lastRequestedDisabledState = false
    }

    private func readForceClickValue() -> Bool? {
        CFPreferencesAppSynchronize(applicationID)

        guard let value = CFPreferencesCopyValue(
            forceClickKey,
            applicationID,
            userName,
            hostName
        ) else {
            print("[TrackpadSettingsController] forceClick value not found")
            return nil
        }

        if CFGetTypeID(value) == CFBooleanGetTypeID() {
            return CFBooleanGetValue((value as! CFBoolean))
        }

        if CFGetTypeID(value) == CFNumberGetTypeID() {
            var intValue: Int32 = 0
            CFNumberGetValue((value as! CFNumber), .sInt32Type, &intValue)
            return intValue != 0
        }

        print("[TrackpadSettingsController] unexpected value type:", value)
        return nil
    }

    private func writeForceClickValue(_ value: Bool) {
        let cfValue = value ? kCFBooleanTrue : kCFBooleanFalse

        CFPreferencesSetValue(
            forceClickKey,
            cfValue,
            applicationID,
            userName,
            hostName
        )

        let synchronized = CFPreferencesSynchronize(
            applicationID,
            userName,
            hostName
        )

        if !synchronized {
            print("[TrackpadSettingsController] failed to synchronize preferences")
        }
    }
}
