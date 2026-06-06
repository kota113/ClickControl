import Foundation
import Darwin

typealias MTDeviceRef = UnsafeMutableRawPointer

typealias MTDeviceCreateListFunction =
    @convention(c) () -> Unmanaged<CFArray>?

typealias MTRegisterContactFrameCallbackFunction =
    @convention(c) (MTDeviceRef, MTContactFrameCallback?) -> Void

typealias MTDeviceStartFunction =
    @convention(c) (MTDeviceRef) -> Int32

typealias MTDeviceStopFunction =
    @convention(c) (MTDeviceRef) -> Int32

typealias MTContactFrameCallback =
    @convention(c) (
        MTDeviceRef?,
        UnsafeRawPointer?,
        Int32,
        Double,
        Int32
    ) -> Void

struct MTPoint {
    var x: Float
    var y: Float
}

struct MTVector {
    var position: MTPoint
    var velocity: MTPoint
}

struct MTTouch {
    var frame: Int32
    var timestamp: Double

    var identifier: Int32
    var state: Int32
    var fingerId: Int32
    var handId: Int32

    var normalized: MTVector
    var size: Float
    var zero1: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var raw: MTVector

    var zero2: Int32
    var zero3: Int32
    var pathIndex: Int32
    var zero4: Int32
}
