# Logic

## Summary

Force Click is detected through a `CGEventTap`, but the event type used by the tap is not the same as the AppKit event type used for the final judgment.

The current rule is:

```text
Subscribe to CGEvent raw type 29
  -> convert CGEvent to NSEvent
  -> process only NSEvent.EventType.pressure
  -> treat stage == 2 as Force Click active
```

## Why CGEvent Raw 29 Is Used

In the event tap, Force Click related pressure events arrive as `CGEventType(rawValue: 29)`.

After converting the event:

```swift
let nsEvent = NSEvent(cgEvent: cgEvent)
```

the same event can become:

```swift
nsEvent.type == .pressure
nsEvent.type.rawValue == 34
```

This means there are two different raw values involved:

```text
CGEvent raw 29
  Event tap input type. This is what must be subscribed to.

NSEvent raw 34
  AppKit pressure event type after NSEvent(cgEvent:) conversion.
```

Subscribing to `CGEvent raw 34` does not work because that is not the event tap input type observed for pressure events.

## Current Stage Logic

The app only handles converted `NSEvent.EventType.pressure` events.

```swift
guard let event = NSEvent(cgEvent: cgEvent), event.type == .pressure else {
    return
}

let isForceClickStage = event.stage == 2
```

The state transition is:

```text
stage != 2 -> stage == 2
  Force Click began.
  Press Cmd+Shift.

stage == 2 -> stage != 2
  Force Click pressure was released back toward normal click pressure.
  Send Cmd+Shift+leftMouseUp.
  Release Cmd+Shift.
```

`leftMouseUp` from the system is not used as the Force Click release trigger. It happens later, when the finger is actually lifted, and is too late for the intended behavior.

## Observed Log Pattern

Representative sequence from the working analysis:

```text
NSEvent pressure stage: 1
NSEvent pressure stage: 2
  -> Force Click began

NSEvent pressure stage: 2
NSEvent pressure stage: 1
  -> Force Click ended / pressure weakened

leftMouseUp
  -> finger lifted, later than the desired release point
```

## Important Caveat

The stable judgment should be based on `NSEvent.EventType.pressure` and `event.stage`, not on interpreting all raw `CGEvent` values directly.

`CGEvent raw 29` is only the subscription entry point needed to receive the events. The actual semantic check remains:

```swift
event.type == .pressure
event.stage == 2
```
