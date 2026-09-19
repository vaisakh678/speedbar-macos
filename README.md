# Wirespeed

Live network speed monitor for the macOS menu bar — a native SwiftUI app that
shows throughput at a glance, copies your IP, and runs an on-demand speed test.

## Requirements

- macOS 14.0 or later
- Xcode 16 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Building

```sh
xcodegen generate          # regenerates Wirespeed.xcodeproj from project.yml
open Wirespeed.xcodeproj
```

Or from the command line:

```sh
xcodebuild -project Wirespeed.xcodeproj -scheme Wirespeed -configuration Debug build
```

`.xcodeproj` is gitignored — `project.yml` is the source of truth, so edit that
and regenerate rather than changing build settings in Xcode's UI.

## How it works

**Live throughput** comes from the kernel's own per-interface byte counters,
read with `sysctl(NET_RT_IFLIST2)` (`Sources/Model/InterfaceCounters.swift`).

Note that although `if_data64` declares `ifi_ibytes`/`ifi_obytes` as
`u_int64_t`, the kernel populates them from a 32-bit counter. Measured on
macOS 27: the field read `3_279_017_984` while `netstat -ib` reported
`29_048_821_735` for the same interface — exactly six 2^32 wraps apart. A
byte-by-byte scan of the whole 180-byte record found no untruncated copy of
the value, so there is nothing better to read and `SpeedMonitor.delta(from:to:)`
unfolds the wrap itself. A separate scan confirmed the field is otherwise
accurate: across a measured 50 MB download its delta was `52_636_672`,
matching netstat.

`SpeedMonitor` samples those counters on a timer and converts consecutive
deltas into a bytes-per-second rate. `NWPathMonitor` (`NetworkPathObserver`)
reports which interface the system is actually routing over, so the meter
measures that one rather than summing every adapter — which would double-count
whenever a VPN is up.

**The menu bar label** is rendered to an `NSImage` with `ImageRenderer` and
handed to `MenuBarExtra` as a single template `Image`, rather than passed as a
SwiftUI view. `MenuBarExtra` does not render a composed label faithfully — a
two-row `VStack` came out with the second row and some text silently dropped.
Rasterising sidesteps that, and a template image tracks light/dark for free.
The label is also deliberately narrow and uses compact units (`3.9M`, not
`3.9 MB/s`): at full width macOS pushed the whole item into the `«` overflow
on a notched display.

**IP addresses.** The panel always shows the LAN address of the active
interface, read locally with `getifaddrs` (`LocalAddressReader`) — no network
traffic, and it follows the interface the route is actually using. Clicking the
row copies it.

The public address is a separate, explicitly-triggered lookup
(`PublicAddressLookup`): opening the menu must not quietly announce you to an
outside service, so nothing is requested until you click **Look Up Public IP**.
It reads the `cf-meta-ip` header that `speed.cloudflare.com` attaches to its
responses — the host the speed test already uses, so no new third party is
involved. A cached result is discarded whenever the active link changes.

**The speed test** (`SpeedTester`) is a single-stream measurement against
Cloudflare's public `speed.cloudflare.com` endpoints. It is intentionally a
rough figure — no server selection, no multi-connection ramp-up — enough to
answer "roughly how fast is this link right now".

## Layout

```
project.yml                    XcodeGen manifest — the project's source of truth
Resources/
  Info.plist                   LSUIElement = true (menu bar only, no Dock icon)
  Wirespeed.entitlements       App Sandbox + network client
Sources/
  App/WirespeedApp.swift       @main, MenuBarExtra + Settings scenes
  Model/
    InterfaceCounters.swift    sysctl NET_RT_IFLIST2 reader
    NetworkPathObserver.swift  NWPathMonitor wrapper — which link is active
    LocalAddressReader.swift   LAN IP of an interface, via getifaddrs
    PublicAddressLookup.swift  on-demand public IP via cf-meta-ip
    SpeedMonitor.swift         sampling loop, rolling history, session totals
    SpeedTester.swift          on-demand Cloudflare throughput test
    SpeedSample.swift          one tick of measured throughput
    AppSettings.swift          UserDefaults-backed prefs + SMAppService login item
  Support/RateFormatter.swift  bytes/bits formatting
  Views/
    MenuBarLabelView.swift     the status item + its ImageRenderer rasteriser
    MenuComponents.swift       NSMenu-style row/separator/copy primitives
    SpeedPanelView.swift       the dropdown panel
    TrafficGraphCard.swift     Canvas-drawn 60s history chart
    SettingsView.swift         preferences window
```

## Menu bar display modes

Set in Preferences:

- **Busier direction** (default) — one line showing whichever way traffic is
  currently heavier, with `arrowtriangle.up.fill` / `arrowtriangle.down.fill`.
  Switching is hysteretic: the other direction has to beat the current one by
  30% before the arrow flips, so it does not strobe on near-equal traffic.
- **Both, stacked** — two small rows, upload over download.
- **Download only** — a single line, always the download rate.

## Icon

`Design/icon-source.png` is the square artwork. The asset catalog is generated
from it:

```sh
swift Tools/make-appicon.swift Design/icon-source.png Resources/Assets.xcassets
```

The App Store screenshots are generated the same way, from the app's real
SwiftUI views rather than captured from a running app — a menu bar panel
cannot be screenshotted without also capturing whatever is behind it:

```sh
Tools/make-screenshots.sh            # writes Design/screenshots
```

Apple's grid places the artwork in an 824x824 rounded square centred on a
1024x1024 canvas, with the surrounding margin left transparent so the system
can draw its own shadow. The corner is a *continuous* curve rather than a
circular arc, which is why the generator renders through SwiftUI's
`RoundedRectangle(style: .continuous)` instead of compositing with `sips` — a
plain rounded rect reads as subtly wrong beside other Dock icons.

Because the app is an agent (`LSUIElement`), the icon never appears in the
Dock. It shows in Finder, Spotlight, the About panel, and System Settings ›
Login Items.

## Signing

The project ad-hoc signs (`CODE_SIGN_IDENTITY: "-"`) so it builds and runs
locally with no Apple account. For distribution, switch `project.yml` to:

```yaml
CODE_SIGN_STYLE: Automatic
DEVELOPMENT_TEAM: KTJUU8D53Q
```

Note that **Launch at login** uses `SMAppService`, which requires a properly
signed build — the toggle will refuse to stick on an ad-hoc build.
