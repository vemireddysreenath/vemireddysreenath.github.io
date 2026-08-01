# PulseBoard

A live workout metrics companion for iPhone + Apple Watch, built from the
PulseBoard PRD (Phase 1 / MVP scope). SwiftUI on both platforms, HealthKit as
the only data store, no third-party dependencies.

## Status: source-complete, built with real (partial) verification

Everything in this directory was written in a Linux container with no Xcode,
no macOS, and no iOS/watchOS SDKs available — so nothing that touches
`SwiftUI`, `HealthKit`, `WatchConnectivity`, `ActivityKit`, or `AppIntents`
could be *type-checked* here. That constraint was taken seriously rather than
worked around with a disclaimer: several things that normally can't be
verified without Xcode were verified anyway, for real, in this session.
Concretely, four different levels of confidence apply across this codebase:

1. **`PulseBoardShared` (models, HR zone math, packet encoding, formatting)
   — actually built and unit-tested.** This package only imports Foundation,
   so a Linux Swift 6.3.3 toolchain was installed specifically to run its
   test suite for real. All **46 tests pass** — see
   [`PulseBoardShared/Tests`](PulseBoardShared/Tests). This is the trickiest
   math in the app (HR zone boundaries, date/recency logic, zone-time
   bucketing, Codable round-trips for the watch↔phone wire format), and it's
   the one part you can trust the way you'd trust any tested code.
2. **Every `.swift` file in both app targets, the widget extension, and
   `Shared/` — parsed clean.** `swiftc -parse` (syntax only, no type
   checking, so it needs no SDK) was run over every file with zero errors.
   This doesn't catch a wrong HealthKit parameter label, but it does rule
   out the more mundane failure mode of a stray brace or malformed
   declaration.
3. **`project.yml` — actually run through XcodeGen, not just written.**
   XcodeGen doesn't ship for Linux, so it was built from source
   (`swift build -c release`, ~2 minutes) and run against this exact
   manifest to generate a real `.xcodeproj`, which was then inspected
   directly. This caught and fixed two real bugs before they could reach
   Xcode:
   - The `Shared/` folder was originally one flat directory glob-included
     into every target. That would have compiled
     `PulseBoardActivityAttributes.swift` (`import ActivityKit`) into the
     watchOS target — **ActivityKit doesn't exist on watchOS**, so the watch
     target would have failed to build. Fixed by splitting `Shared/` into
     `Shared/PhoneWatch/` and `Shared/PhoneWidget/`, each wired to only the
     targets that actually need it (verified by re-inspecting the generated
     project's per-target Sources build phase).
   - `info: path:` and `entitlements: path:` don't mean "use this existing
     file verbatim" — XcodeGen *regenerates* the file at that path from
     scratch every run, merging in only what's under a sibling
     `properties:` key. A hand-authored standalone Info.plist would be
     silently discarded on the first `xcodegen generate`. Fixed by moving
     every custom key (`NSHealthShareUsageDescription`,
     `NSSupportsLiveActivities`, `WKBackgroundModes`, the widget's
     `NSExtension` dict, both entitlements) into inline `properties:` in
     `project.yml`, then confirming the regenerated plists actually contain
     them.
   - Also confirmed by direct inspection: the watch target needs
     `type: application.watchapp2` (not plain `application`) to get the
     correct `com.apple.product-type.application.watchapp2` product type;
     the "Embed Watch Content" and "Embed Foundation Extensions" build
     phases are present and reference the right products; all three targets
     correctly link the local `PulseBoardShared` package.
4. **HealthKit / WatchConnectivity / ActivityKit / AppIntents *semantics* —
   written carefully, genuinely not verified.** Every such call was written
   against documented API shapes from memory and cross-checked for internal
   consistency, but nothing here can type-check those frameworks without a
   real SDK. Treat the first build in Xcode as the real first type-check of
   this code, not a formality. See "Things worth double-checking" below for
   the specific spots with the most residual risk.

None of this is a reason to distrust the architecture — it's why the shared
logic got pulled out and tested for real, why the project generation got
run for real instead of hand-waved, and why what's *left* unverified is
called out explicitly instead of glossed over.

## Project layout

```
PulseBoard/
├── project.yml                 XcodeGen manifest — generates PulseBoard.xcodeproj
├── PulseBoardShared/            Swift package: models, HR zone math, formatting (Foundation only)
│   ├── Sources/PulseBoardShared/
│   └── Tests/PulseBoardSharedTests/    46 passing tests, runnable with `swift test`
├── PulseBoard/                  iOS app target
│   ├── App/                     App entry point
│   ├── Services/                HealthStore, connectivity, MetricsStore, Live Activity, settings
│   ├── Views/                   Dashboard, Summary, History, Onboarding, Settings
│   ├── AppIntents/              The 5 Siri intents + App Shortcuts
│   └── Resources/                Info.plist, Assets.xcassets
├── PulseBoardWatch/              watchOS app target
│   ├── App/, Services/, Views/   WorkoutManager (HKWorkoutSession/HKLiveWorkoutBuilder), minimal UI
│   └── Resources/
├── PulseBoardWidget/              Widget extension target (Live Activity / Dynamic Island)
└── Shared/                       Files added to *multiple* Xcode targets directly (not the
                                   SPM package) because they need HealthKit/ActivityKit/SwiftUI,
                                   which the portable package deliberately avoids. Split into
                                   two subfolders so each target only gets what it can compile:
                                     PhoneWatch/  (iOS + watch — no ActivityKit/WidgetKit)
                                       - WorkoutKindHealthKitMapping.swift
                                       - ApplicationContextKey.swift
                                     PhoneWidget/ (iOS + widget extension — no HealthKit)
                                       - HeartRateZoneColor.swift
                                       - ZoneIndicatorBar.swift
                                       - PulseBoardActivityAttributes.swift
```

Why a Swift package *and* a `Shared/` folder? `PulseBoardShared` has no
Apple-only imports, so it's what actually got tested on Linux in this
session. Anything that needs HealthKit/ActivityKit/SwiftUI but is still
reused across targets lives in `Shared/` instead, added to each target's
`sources:` in `project.yml` as plain file membership — split by which
frameworks each consuming target actually has available (see the "actually
run through XcodeGen" note above for why this split exists).

## Setup

1. **Install Xcode** (a recent version whose bundled SDKs support iOS 17 and
   watchOS 10 as a deployment target — Xcode 16.x or later).
2. **Install XcodeGen**: `brew install xcodegen` (validated against 2.44.1;
   see [xcodegen docs](https://github.com/yonaskolb/XcodeGen) for other
   install methods). The project is defined as a `project.yml` manifest
   rather than a hand-authored `.xcodeproj` — this is the standard way to
   keep a multi-target Xcode project in reviewable, mergeable plain text,
   and it's what let this manifest actually be generated and inspected
   during development instead of only hand-written.
3. From this directory, run:
   ```
   xcodegen generate
   ```
   This produces `PulseBoard.xcodeproj` with three targets: `PulseBoard`
   (iOS), `PulseBoardWatch` (watchOS), `PulseBoardWidgetExtension` (widget
   extension, embeds the Live Activity). `.gitignore` deliberately excludes
   the generated `.xcodeproj` — `project.yml` is the source of truth, so
   re-run `xcodegen generate` after pulling changes to it instead of
   expecting the project file itself in version control.
4. Open `PulseBoard.xcodeproj` in Xcode.
5. **Set your own Team** on all three targets (Signing & Capabilities) — the
   bundle IDs are prefixed `com.vemireddysreenath.pulseboard.*` in
   `project.yml`; change the `bundleIdPrefix` there (and re-run `xcodegen
   generate`) if you want your own.
6. **Verify capabilities** landed correctly (XcodeGen sets these from
   `project.yml`, but double check in Signing & Capabilities):
   - `PulseBoard` (iOS): HealthKit capability; entitlements file grants
     `com.apple.developer.healthkit`.
   - `PulseBoardWatch`: HealthKit capability; `WKBackgroundModes` =
     `workout-processing` and `WKRunsIndependentlyOfCompanionApp` = true are
     already in its `Info.plist`.
   - `PulseBoard` (iOS): `NSSupportsLiveActivities` = true is already in its
     `Info.plist` — Live Activities need no separate entitlement or
     capability toggle beyond that key.
7. **Add a real app icon.** Both `AppIcon.appiconset` folders have a valid
   `Contents.json` (single-size, modern format) but no actual PNG — Xcode
   will warn until you drop in a 1024×1024 image for each.
8. Build and run — see the device requirements below before expecting live
   data.

## What you can and can't test in Simulator

HealthKit live workout data fundamentally requires a **real Apple Watch**
paired to a **real iPhone** — the Simulator has no heart rate sensor and
`HKLiveWorkoutBuilder` has no meaningful simulated data source. Concretely:

**Needs physical devices (real Watch + real iPhone, paired, both signed into
the same Apple ID with Health access):**
- Anything in `WorkoutManager` — starting a session, live HR/calorie/distance
  collection, saving to HealthKit.
- The watch → phone `MetricPacket` stream and the "Reconnecting…" recovery
  path.
- The Live Activity / Dynamic Island actually appearing and updating.
- All 5 Siri intents when they depend on real HealthKit data or an active
  workout (they'll build and the *dialog wiring* is testable, but the
  answers are only meaningful with real data).
- `HKHealthStore.startWatchApp` actually launching the watch app.

**Testable in Simulator (iPhone only, no watch needed):**
- Onboarding flow and its permission-explanation screens.
- The HealthKit permission sheet itself, and the app's degraded-state UI
  when a permission is denied (deny one in Settings → the app should show
  the "Enable in Settings" CTA, not a fake value).
- `HistoryView` / `SummaryView` layout, once you have at least one workout
  in the Simulator's Health app (you can add a manual workout via the Health
  app itself to get *some* data flowing through `HKWorkout.statistics(for:)`,
  even without a live session).
- `SettingsView`, dashboard layout in portrait/landscape, dim mode, dark
  theme.
- Idle-timer behavior (`isIdleTimerDisabled`) — visible in Simulator, though
  its point (a physical screen not locking) only really matters on device.

**Also unverifiable without a device, mentioned explicitly per the PRD:**
respiratory rate is deliberately never shown as "live" — it's always the
most recent HealthKit sample with a recency label (e.g. "14 br/min · last
night"). You can exercise this path in Simulator by inserting a respiratory
rate sample via the Health app.

## Demo script (once you have a physical Watch + iPhone)

1. Fresh install → onboarding explains each HealthKit category → grant
   access.
2. On the Watch, start a Strength workout (or from the iPhone's dashboard
   empty state, if you wire up a shortcut to it).
3. Within ~3 seconds, the iPhone dashboard should show a live, updating
   heart rate with a zone color, elapsed time, and calories.
4. Background the iPhone (press the side button, or switch to Music/Spotify)
   — the Dynamic Island should pick up current HR + elapsed time within a
   few seconds.
5. Pause the workout from the Watch — dashboard and Live Activity should
   both reflect "Paused".
6. End the workout from the Watch — the iPhone should present the
   `SummaryView` sheet with duration, avg/min/max HR, the zone-time bar
   chart, and calories; the Live Activity should end.
7. Open Apple's Fitness app — the workout should appear there too (it's a
   real `HKWorkout`, saved by `HKLiveWorkoutBuilder.finishWorkout`).
8. Turn on Airplane Mode on the Watch mid-workout (next run) — the phone
   dashboard should show "Reconnecting…" rather than crashing or freezing on
   stale data, then resume once connectivity returns.
9. Ask Siri each of the 5 phrases (see `PulseBoardShortcuts.swift`) with and
   without a workout running.
10. In Settings, deny one HealthKit permission (e.g. respiratory rate) via
    the iOS Settings app, relaunch, and confirm the dashboard shows the
    denied-state CTA instead of a fake value.

## Things worth double-checking against the current SDK

Flagged proactively rather than discovered the hard way — these are the
spots with the most API-shape uncertainty given no compiler was available:

- **App Intents snippet views** (`some IntentResult & ProvidesDialog &
  ShowsSnippetView`, `.result(dialog:view:)`) — this exact protocol
  composition has shifted across App Intents' first few OS versions; if it
  doesn't compile as-is, dropping `& ShowsSnippetView` and the `view:`
  argument still gets you a fully working spoken-only intent while you
  check current syntax.
- **`HKHealthStore.startWatchApp(with:completion:)`** in
  `StartWorkoutIntent` — used via the older completion-handler form
  (bridged to `async` with `withCheckedContinuation`) deliberately, since
  that signature has been stable the longest; there may now be a more direct
  `async throws` overload worth switching to.
- **`AppDependencyManager.shared.add(dependency:)`** in `PulseBoardApp.init`
  — real API for letting App Intents read `HealthStore`/`MetricsStore` via
  `@Dependency`, but double-check the exact call against current docs if it
  doesn't compile.

(The equivalent XcodeGen concern — whether the watchOS target's `type:`
string was right — came up during development too, but it's *not* on this
list: it was resolved by actually generating the project and inspecting the
output, not left as a guess. See the Status section above.)

None of the above affects `PulseBoardShared`, which is why that's the part
with actual test coverage rather than a caveat.

## Explicit non-goals (per PRD)

No Android, no social features, no custom cloud backend, no diagnosis/medical
claims, no faked live respiratory data. Phase 2 (interval timer, zone target
alerts, Trends screen, home/lock screen widgets, voice announcements) is
intentionally not built — the architecture (especially `MetricPacket` and
the zone-time accumulator) was designed with it in mind, but building it now
would be scope creep against an already-large MVP.

## Known limitation: F2 "mirror a native Workout app session"

This was the PRD's own lowest-priority MVP item ("nice-to-have... if time
allows"), and it's implemented at exactly that level. There's no live
HealthKit stream for a workout this app didn't start, so
`MirroredWorkoutObserver` uses a heuristic (a heart-rate sample in the last
90 seconds implies the watch is actively recording) and, once mirroring,
polls every few seconds rather than streaming. Every view showing mirrored
data labels it "Mirrored · Higher Latency" — it should never be visually
confused with the real watch-sourced dashboard.
