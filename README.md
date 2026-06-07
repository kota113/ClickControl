# ClickControl

macOS での Force Click を、標準の辞書 Look Up から変更する常駐アプリです。現在は、ブラウザで「新規タブで開く」アクションを行う実装です。

ClickControl is a macOS menu bar app that changes Force Click behavior depending on the app. 

The current version replaces Force Click with a synthetic `Cmd+Shift` click (open in new tab) when a target browser is frontmost.

## Behavior

```text
Target browser becomes frontmost
  -> temporarily disable macOS Force Click

Force Click pressure reaches stage 2
  -> press Cmd+Shift

Force Click pressure drops back from stage 2
  -> send Cmd+Shift+leftMouseUp
  -> release Cmd+Shift

Target browser loses focus or app exits
  -> release modifiers if needed
  -> restore the original Force Click setting
```

The app does not use the system `leftMouseUp` event as the Force Click release trigger. That event happens when the finger is lifted, which is later than the desired "pressure weakened" moment.

## Target Browsers

Target browser detection is based on bundle identifiers in `FrontmostAppGate`.

Current targets include:

```text
Google Chrome
Safari
Arc
Microsoft Edge
Brave
Firefox
```

## Implementation Notes

Main components:

```text
AppDelegate
  App lifecycle and component wiring.

FrontmostAppGate
  Detects whether the frontmost app is a target browser.

TrackpadSettingsController
  Temporarily disables and restores macOS Force Click preference.

ForceClickPressureMonitor
  Watches pressure events from a CGEvent tap and detects Force Click stage transitions.

SyntheticClickSender
  Sends synthetic Cmd+Shift key and mouse events.
```

Force Click detection uses this rule:

```text
Subscribe to CGEvent raw type 29
  -> convert CGEvent to NSEvent
  -> process only NSEvent.EventType.pressure
  -> treat stage == 2 as Force Click active
```

See [logic.md](logic.md) for the event analysis and raw value notes.

## Build

Open the project in Xcode:

```text
ClickControl.xcodeproj
```

Or build from the command line:

```sh
xcodebuild -project ClickControl.xcodeproj -scheme ClickControl -configuration Debug -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO build
```

## Permissions

The app uses a global event tap and synthetic input events. macOS may require Accessibility/Input Monitoring permissions for the built app, depending on how it is launched and signed.

## Caveats

This app changes the user's Force Click preference while a target browser is frontmost and restores it afterward. If the app is force-killed, restoration may not run.

The current Force Click detection depends on the observed macOS event path where pressure events arrive through the event tap as `CGEvent` raw type `29` and become `NSEvent.EventType.pressure` after conversion.
