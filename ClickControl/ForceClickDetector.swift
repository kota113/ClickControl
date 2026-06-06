import Foundation
import Darwin

final class ForceClickDetector {
    var onForceClick: (() -> Void)?
    var onForceClickEnded: (() -> Void)?

    private static weak var activeDetector: ForceClickDetector?

    private let appState: AppState
    private let callbackQueue = DispatchQueue(label: "ForceClickDetector.callback")

    private var multitouchHandle: UnsafeMutableRawPointer?
    private var devices: [MTDeviceRef] = []
    private var stopDevice: MTDeviceStopFunction?

    private var isInForceClickState = false
    private var pendingForceClickEnd: DispatchWorkItem?

    private let forceClickEndDelay: TimeInterval = 0.15

    init(appState: AppState) {
        self.appState = appState
    }

    func start() {
        guard multitouchHandle == nil else {
            return
        }

        let frameworkPath = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"

        guard let handle = dlopen(frameworkPath, RTLD_NOW) else {
            if let error = dlerror() {
                print("[ForceClickDetector] dlopen failed:", String(cString: error))
            } else {
                print("[ForceClickDetector] dlopen failed")
            }
            return
        }

        guard
            let createListSymbol = dlsym(handle, "MTDeviceCreateList"),
            let registerCallbackSymbol = dlsym(handle, "MTRegisterContactFrameCallback"),
            let startSymbol = dlsym(handle, "MTDeviceStart")
        else {
            print("[ForceClickDetector] failed to resolve required symbols")
            dlclose(handle)
            return
        }

        let createDeviceList = unsafeBitCast(
            createListSymbol,
            to: MTDeviceCreateListFunction.self
        )
        let registerCallback = unsafeBitCast(
            registerCallbackSymbol,
            to: MTRegisterContactFrameCallbackFunction.self
        )
        let startDevice = unsafeBitCast(
            startSymbol,
            to: MTDeviceStartFunction.self
        )

        if let stopSymbol = dlsym(handle, "MTDeviceStop") {
            stopDevice = unsafeBitCast(stopSymbol, to: MTDeviceStopFunction.self)
        }

        guard let unmanagedDeviceList = createDeviceList() else {
            print("[ForceClickDetector] MTDeviceCreateList returned nil")
            dlclose(handle)
            return
        }

        let deviceList = unmanagedDeviceList.takeUnretainedValue() as NSArray

        Self.activeDetector = self
        multitouchHandle = handle

        for item in deviceList {
            let device = Unmanaged.passUnretained(item as AnyObject).toOpaque()
            devices.append(device)

            registerCallback(device, Self.multitouchCallback)
            startDevice(device)

            print("[ForceClickDetector] started device:", device)
        }

        if devices.isEmpty {
            print("[ForceClickDetector] no multitouch devices found")
        } else {
            print("[ForceClickDetector] started")
        }
    }

    func stop() {
        for device in devices {
            stopDevice?(device)
        }

        devices.removeAll()
        stopDevice = nil
        pendingForceClickEnd?.cancel()
        pendingForceClickEnd = nil
        isInForceClickState = false

        if let multitouchHandle {
            dlclose(multitouchHandle)
        }

        multitouchHandle = nil

        if Self.activeDetector === self {
            Self.activeDetector = nil
        }

        print("[ForceClickDetector] stopped")
    }

    private func handleTouches(
        rawTouches: UnsafeRawPointer?,
        touchCount: Int32
    ) {
        guard let rawTouches, touchCount > 0 else {
            return
        }

        let touches = rawTouches.bindMemory(
            to: MTTouch.self,
            capacity: Int(touchCount)
        )
        let touchArray = UnsafeBufferPointer(
            start: touches,
            count: Int(touchCount)
        )

        guard let primaryTouch = touchArray.first, isValidPrimaryTouch(primaryTouch) else {
            return
        }

        switch primaryTouch.state {
        case 5:
            guard appState.isEnabled, appState.isTargetBrowserActive else {
                return
            }
            cancelPendingForceClickEnd()
            guard !isInForceClickState else {
                return
            }

            isInForceClickState = true
            appState.forceClickTriggered = true

            DispatchQueue.main.async { [weak self] in
                self?.onForceClick?()
            }

        case 6:
            return

        case 7:
            scheduleForceClickEnd()

        default:
            return
        }
    }

    private func cancelPendingForceClickEnd() {
        pendingForceClickEnd?.cancel()
        pendingForceClickEnd = nil
    }

    private func scheduleForceClickEnd() {
        guard isInForceClickState else {
            return
        }

        cancelPendingForceClickEnd()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.isInForceClickState else {
                return
            }

            self.isInForceClickState = false
            self.appState.forceClickTriggered = false
            self.pendingForceClickEnd = nil

            DispatchQueue.main.async { [weak self] in
                self?.onForceClickEnded?()
            }
        }

        pendingForceClickEnd = workItem
        callbackQueue.asyncAfter(
            deadline: .now() + forceClickEndDelay,
            execute: workItem
        )
    }

    private func isValidPrimaryTouch(_ touch: MTTouch) -> Bool {
        guard touch.timestamp.isFinite else {
            return false
        }

        guard touch.frame >= 0 else {
            return false
        }

        guard (1...7).contains(touch.state) else {
            return false
        }

        return true
    }

    private static let multitouchCallback: MTContactFrameCallback = { _, rawTouches, touchCount, _, _ in
        guard let detector = ForceClickDetector.activeDetector else {
            return
        }

        detector.callbackQueue.async {
            detector.handleTouches(
                rawTouches: rawTouches,
                touchCount: touchCount
            )
        }
    }
}
