import AppKit

final class ForceClickPressureMonitor {
    var onForceClickBegan: (() -> Void)?
    var onForceClickEnded: (() -> Void)?

    private static weak var activeMonitor: ForceClickPressureMonitor?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isInForceClickStage = false

    func start() {
        guard eventTap == nil else {
            return
        }

        // Pressure events arrive through the event tap as raw CGEvent type 29,
        // then become NSEvent.EventType.pressure after NSEvent(cgEvent:).
        let mask = CGEventMask(1 << CGEventType(rawValue: 29)!.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: Self.eventCallback,
            userInfo: nil
        ) else {
            print("[ForceClickPressureMonitor] failed to create event tap")
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            print("[ForceClickPressureMonitor] failed to create run loop source")
            CFMachPortInvalidate(tap)
            return
        }

        Self.activeMonitor = self
        eventTap = tap
        runLoopSource = source

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        print("[ForceClickPressureMonitor] started")
    }

    func stop() {
        if isInForceClickStage {
            isInForceClickStage = false
        }

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil

        if Self.activeMonitor === self {
            Self.activeMonitor = nil
        }

        print("[ForceClickPressureMonitor] stopped")
    }

    func reset() {
        guard isInForceClickStage else {
            return
        }

        isInForceClickStage = false
    }

    private func handleEvent(_ cgEvent: CGEvent) {
        guard let event = NSEvent(cgEvent: cgEvent), event.type == .pressure else {
            return
        }

        let isForceClickStage = event.stage == 2
        guard isForceClickStage != isInForceClickStage else {
            return
        }

        isInForceClickStage = isForceClickStage

        if isForceClickStage {
            print(
                String(
                    format: "[ForceClickPressureMonitor] began pressure: %.4f stageTransition: %.6f",
                    event.pressure,
                    event.stageTransition
                )
            )
            onForceClickBegan?()
        } else {
            print(
                String(
                    format: "[ForceClickPressureMonitor] ended pressure: %.4f stageTransition: %.6f stage: %d",
                    event.pressure,
                    event.stageTransition,
                    event.stage
                )
            )
            onForceClickEnded?()
        }
    }

    private static let eventCallback: CGEventTapCallBack = { _, type, event, _ in
        guard type != .tapDisabledByTimeout, type != .tapDisabledByUserInput else {
            if let eventTap = ForceClickPressureMonitor.activeMonitor?.eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        ForceClickPressureMonitor.activeMonitor?.handleEvent(event)
        return Unmanaged.passUnretained(event)
    }
}
