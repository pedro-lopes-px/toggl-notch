# Toggl Notch — Implementation Plan (v1, native SwiftUI, mock data only)

A premium macOS notch utility for time tracking. Collapsed: a pill fused with the notch showing the running timer. Expanded: a compact command-center panel that unfolds downward with a spring animation. Dark mode only. No backend, no Toggl API — all data is mocked.

This document is the single source of truth. The coding model must follow it exactly and must not invent features, colors, libraries, or APIs beyond what is specified.

---

## 1. Tech stack (decided — do not substitute)

| Concern | Choice |
|---|---|
| Language | Swift 6 (strict concurrency; `@MainActor` annotated explicitly where required) |
| UI | **SwiftUI** for 100% of the interface |
| Shell | **AppKit only for the window**: one `NSPanel` subclass + one `NSHostingView`. No other AppKit views. |
| State | `@Observable` (Observation framework) — **not** `ObservableObject`/`@Published` |
| Animation | Native SwiftUI springs + transitions — no third-party animation libs |
| Project generation | **XcodeGen** (`project.yml` committed; run `xcodegen generate`) |
| Deployment target | **macOS 15.0** (notch Macs are 2021+; this unlocks `onGeometryChange`, `pointerStyle`) |
| Dependencies | **None.** No SPM packages, no Sparkle, no Lottie, nothing. |

### Why native SwiftUI (vs Electron/Tauri)

A notch utility's hard requirements — a borderless transparent panel floating *above the menu bar*, per-region click-through, behind-window blur, all-Spaces presence, near-zero idle footprint — are all first-class AppKit/SwiftUI capabilities (`NSPanel`, `NSWindow.Level.statusBar`, `NSVisualEffectView`, `collectionBehavior`). Web shells fight every one of these and ship a ~100 MB runtime to render a 220px pill. Native also gives correct dark-mode materials, SF Pro, and S-tier energy behavior for free. The only AppKit code needed is ~150 lines of window plumbing; everything visible is SwiftUI.

### Build & run loop (for the coding model)

```bash
xcodegen generate
xcodebuild -project TogglNotch.xcodeproj -scheme TogglNotch -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/TogglNotch-*/Build/Products/Debug/TogglNotch.app
# quit a running instance first: pkill -x TogglNotch || true
```

`project.yml` essentials: bundle id `com.pixelmatters.togglnotch`, `CODE_SIGN_IDENTITY: "-"` (ad-hoc), `GENERATE_INFOPLIST_FILE: false` with a committed `Info.plist` containing **`LSUIElement = YES`** (agent app, no Dock icon, no main menu).

---

## 2. Architecture overview

```
TogglNotchApp (@main, SwiftUI App)
└─ @NSApplicationDelegateAdaptor AppDelegate
   └─ NotchPanelController          ← owns the NSPanel, screen placement, event monitors
      ├─ NotchPanel (NSPanel)       ← borderless, transparent, above the menu bar
      │   └─ NSHostingView(RootView.environment(appStore))
      └─ AppStore (@Observable)     ← all app state; created here, injected into SwiftUI
```

- `TogglNotchApp`'s only scene is `Settings { EmptyView() }` (required placeholder; the real window is the panel).
- **All business/UI state lives in `AppStore`.** The controller layer contains zero business logic — only window geometry and event-monitor plumbing.
- **The panel is a fixed 420 × 560 transparent stage and is never resized or moved during animation.** The pill→panel morph happens entirely in SwiftUI inside it. Animating `NSWindow` frames during a spring janks; a fixed stage sidesteps it.

### NotchPanel configuration (exact)

```swift
final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }   // borderless panels need this for Escape handling
}
// configured by NotchPanelController:
styleMask = [.borderless, .nonactivatingPanel]
isFloatingPanel = true
level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)  // above the menu bar
collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
isOpaque = false
backgroundColor = .clear
hasShadow = false          // shadow is drawn in SwiftUI
isMovable = false
hidesOnDeactivate = false
appearance = NSAppearance(named: .darkAqua)   // dark mode only, regardless of system setting
```

### Screen placement

- Target screen: the one with a physical notch — `NSScreen.screens.first { $0.safeAreaInsets.top > 0 }`, falling back to `NSScreen.main`.
- Frame (remember AppKit origin is bottom-left): `x = screen.frame.midX - 210`, `y = screen.frame.maxY - 560`, size `420 × 560`. The SwiftUI stage top-aligns content, so the pill sits flush under the screen's top edge.
- Re-run placement on `NSApplication.didChangeScreenParametersNotification` (display plugged/unplugged, resolution change).

### Click-through (critical — read carefully)

The stage is mostly empty transparent space that must not eat clicks. Deterministic pattern:

- The panel toggles `ignoresMouseEvents` based on whether the cursor is inside the **interactive rect** (the shell's current frame in screen coordinates).
- SwiftUI reports that rect: the shell view applies `.onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) })` and forwards it to the controller (convert to screen coords via `panel.convertToScreen` — the hosting view is the panel's content view, and remember to flip y between SwiftUI's top-left and AppKit's bottom-left coordinate spaces).
- `NotchPanelController` installs **two** mouse-moved monitors and keeps them for the app's lifetime:
  - `NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved)` — fires while events go to *other* apps (i.e. while `ignoresMouseEvents == true`). When `NSEvent.mouseLocation` enters the interactive rect → `ignoresMouseEvents = false`.
  - `NSEvent.addLocalMonitorForEvents(matching: .mouseMoved)` — fires while our panel receives events. When the cursor leaves the rect → `ignoresMouseEvents = true`.
- Initial state: `ignoresMouseEvents = true`.
- On every collapse, explicitly recompute (cursor may already be outside) so the flag never desyncs.

### Key/blur handling

- **Expand:** SwiftUI calls `store.expand()`; the controller observes `store.isExpanded` (via `withObservationTracking` or a closure callback on the store) and calls `panel.makeKey()` so we receive keyboard events without activating the app (`.nonactivatingPanel`).
- **Escape:** local `NSEvent.addLocalMonitorForEvents(matching: .keyDown)`; `keyCode == 53` while expanded → `store.collapse()`, return `nil` (swallow). Same monitor handles **⌘Q** (`"q"` + command) → `NSApp.terminate(nil)`, since an `LSUIElement` app has no menu bar to supply the key equivalent.
- **Click outside / app switch:** the controller is the panel's delegate; `windowDidResignKey` → `store.collapse()`. Clicking the transparent stage area passes through to whatever is behind (other app activates → we resign key → collapse). This covers "click anywhere else closes it" with no extra code.

### Data flow

`MockData` (static seed) → `AppStore` (single source of truth) → views read via `@Environment(AppStore.self)` → actions are store methods. The running timer is **derived, never stored**: the store keeps `startedAt: Date`, and `TimelineView(.periodic(from: .now, by: 1))` recomputes elapsed from `context.date`. No `Timer`, no Combine, nothing to invalidate, correct across sleep.

---

## 3. File / folder structure (one type per file — strict)

```
toggl-notch/
├─ project.yml
├─ PLAN.md
└─ TogglNotch/
   ├─ App/
   │  ├─ TogglNotchApp.swift          # @main, adaptor, Settings placeholder scene
   │  ├─ AppDelegate.swift            # creates AppStore + NotchPanelController
   │  ├─ NotchPanel.swift             # NSPanel subclass (canBecomeKey)
   │  └─ NotchPanelController.swift   # window config, placement, monitors, delegate
   ├─ Store/
   │  └─ AppStore.swift               # @MainActor @Observable
   ├─ Models/
   │  ├─ Project.swift
   │  ├─ TimeEntry.swift
   │  └─ RunningEntry.swift
   ├─ Data/
   │  └─ MockData.swift
   ├─ DesignSystem/
   │  ├─ NotchColors.swift            # Color constants (exact values, Section 4)
   │  ├─ NotchMetrics.swift           # sizes, radii, spacing, the shared spring
   │  └─ VisualEffectView.swift       # NSViewRepresentable behind-window blur
   ├─ Utilities/
   │  └─ TimeFormatting.swift         # formatTimer / formatDuration / formatHours
   ├─ Views/
   │  ├─ RootView.swift               # top-aligned stage, hosts NotchShell
   │  ├─ NotchShell.swift             # the animating pill↔panel container
   │  ├─ Collapsed/
   │  │  ├─ CollapsedPill.swift
   │  │  └─ ActiveDot.swift
   │  ├─ Expanded/
   │  │  ├─ ExpandedPanel.swift
   │  │  ├─ PanelHeader.swift
   │  │  ├─ TodaySummary.swift
   │  │  ├─ StatBlock.swift
   │  │  ├─ RecentEntries.swift
   │  │  ├─ EntryRow.swift
   │  │  ├─ QuickActions.swift
   │  │  ├─ ActionButton.swift
   │  │  └─ SectionLabel.swift
   │  └─ Components/
   │     ├─ ProjectDot.swift
   │     └─ PressableButtonStyle.swift # scale 0.97 on press
   └─ Resources/
      └─ Info.plist                    # LSUIElement = YES
```

---

## 4. Design system (exact values — no improvisation)

### Colors (`NotchColors.swift` — `enum NotchColors` with static `Color` constants)

```swift
surfaceNotch   = Color(red: 16/255, green: 16/255, blue: 18/255).opacity(0.62)  // over the blur material
surfaceRaised  = Color.white.opacity(0.04)
surfaceHover   = Color.white.opacity(0.07)
surfaceActive  = Color.white.opacity(0.10)
borderSubtle   = Color.white.opacity(0.07)
borderEdge     = Color.white.opacity(0.12)     // 1px inner top hairline
textPrimary    = Color.white.opacity(0.92)
textSecondary  = Color.white.opacity(0.55)
textTertiary   = Color.white.opacity(0.32)
accentGreen    = Color(red: 48/255, green: 209/255, blue: 88/255).opacity(0.85) // muted Apple green
accentRedDim   = Color(red: 255/255, green: 105/255, blue: 97/255).opacity(0.90) // stop hover only
```

### Typography
- System font only (SF Pro comes free). Sizes: 11 (section labels, meta), 12 (rows secondary, pill), 13 (primary content, buttons), 15 semibold (header project name), 22 `.light` (header timer).
- **Every timer/duration Text gets `.monospacedDigit()`** so digits never jitter.
- Section labels: 11pt, `.medium`, `.kerning(0.7)`, uppercase string, `textTertiary`.
- `.foregroundStyle(...)` everywhere — never `foregroundColor`.

### Shape & depth
- Collapsed pill: **220 × 36**. Expanded panel: **380 wide**, content-driven height capped at **480**.
- Corners via `UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: r, bottomTrailingRadius: r, topTrailingRadius: 0)` — top corners square so the surface fuses with the physical notch. `r = 18` collapsed, `24` expanded.
- Surface stack (back→front), all clipped to that shape: `VisualEffectView` (`.hudWindow` material, `.behindWindow`, state `.active`) → `NotchColors.surfaceNotch` fill → content. This is the ONLY glassmorphism in the app.
- Border: the shape `.stroke(NotchColors.borderSubtle, lineWidth: 1)` (top edge is off-screen-flush, acceptable for it to be stroked). Inner top hairline: a 1pt `borderEdge` rectangle overlaid at the top inside the shape.
- Shadow (SwiftUI, since panel shadow is off): `.shadow(color: .black.opacity(0.55), radius: 24, y: 16)` + `.shadow(color: .black.opacity(0.35), radius: 6, y: 4)` on the shell.
- Spacing rhythm: 16 panel padding, 12 between sections, 8 inside rows. Row height 40.

### Motion (`NotchMetrics.swift`)
- One shared shell spring: `Animation.spring(duration: 0.45, bounce: 0.15)` — used ONLY with a value: `.animation(NotchMetrics.shellSpring, value: store.isExpanded)`. **Never a valueless `.animation()`.**
- Content transitions: `.opacity` combined with `.offset(y: 6)`, 0.18s ease-out, staggered by index: `.transition(.opacity.combined(with: .offset(y: 6)).animation(.easeOut(duration: 0.18).delay(0.08 + Double(index) * 0.03)))`. Collapsed content exits with a fast plain `.opacity` (0.1s).
- Hover: color changes animate with `.easeOut(duration: 0.15)`, value-bound to the hover state. No scale on hover.
- Press: `PressableButtonStyle` — `scaleEffect(configuration.isPressed ? 0.97 : 1)` with `.spring(duration: 0.2)`.
- ActiveDot pulse: a halo circle behind the dot animating scale 1→1.35 / opacity 0.5→0 on a 2s repeating ease-out, driven by `.animation(.easeOut(duration: 2).repeatForever(autoreverses: false), value: pulse)` toggled in `onAppear`. Paused when idle.
- **Reduce Motion:** read `@Environment(\.accessibilityReduceMotion)`; when true, shell uses `.easeOut(duration: 0.2)` instead of the spring, content transitions are opacity-only, and the dot does not pulse.

---

## 5. Mock data — exact shapes (`Models/` + `Data/MockData.swift`)

```swift
struct Project: Identifiable, Hashable {
    let id: String
    let name: String
    let color: Color          // muted, from the palette below
}

struct TimeEntry: Identifiable, Hashable {
    let id: String
    let projectID: String
    let description: String
    let startedAt: Date
    let durationSeconds: Int  // completed entries only
    let isDeepWork: Bool
}

struct RunningEntry: Hashable {
    var projectID: String
    var description: String
    let startedAt: Date       // elapsed is ALWAYS derived from this
}
```

Seed data (`enum MockData`):
- **Projects (5):** `Pixelmatters Website` (#7A8CF0), `Client — Atlas App` (#C9A06A), `Design System` (#9B8CE0), `Internal Tools` (#6FB8A8), `Research` (#B0788C). Muted/dusty only — no pure hues.
- **Running entry:** project `Client — Atlas App`, description `"Onboarding flow refinements"`, `startedAt = Date.now.addingTimeInterval(-(47 * 60 + 23))`.
- **Completed entries today (6, newest first):** "Design review notes", "Component API cleanup", "Sprint planning", "Bug triage", "Landing page copy pass", "Figma handoff" — durations 18 min–1 h 52 m, mixed projects, exactly 4 of 6 `isDeepWork: true`.

`TimeFormatting.swift` (free functions or a `TimeFormatting` enum, with exact outputs):
- `formatTimer(_ seconds: Int) -> String` → `"1:23:45"`, or `"23:45"` under an hour (running timers).
- `formatDuration(_ seconds: Int) -> String` → `"1h 24m"` / `"38m"` (entry rows).
- `formatHours(_ seconds: Int) -> String` → `"6.4h"` (summary stat).

---

## 6. State management (`Store/AppStore.swift`)

```swift
@MainActor
@Observable
final class AppStore {
    var isExpanded = false
    var runningEntry: RunningEntry?
    var entries: [TimeEntry]          // completed, newest first
    let projects: [Project]

    // derived (computed properties, not stored):
    var runningProject: Project?      // lookup via runningEntry?.projectID
    var recentEntries: [TimeEntry]    // Array(entries.prefix(5))
    var trackedSecondsToday: Int      // completed sum + live running elapsed
    var entryCountToday: Int          // entries.count + (runningEntry != nil ? 1 : 0)
    var deepWorkPercent: Int          // deep-work seconds / total, 0 when total == 0

    func expand() / collapse() / toggleExpanded()
    func stopTimer()                  // running → TimeEntry(isDeepWork: true), prepend, set nil
    func startEntry()                 // v1: projects[0], description "New entry", startedAt .now
    func switchProject()              // cycles runningEntry.projectID to next project, keeps startedAt
    var onExpansionChange: ((Bool) -> Void)?   // controller hook: makeKey / ignoresMouseEvents resync
}
```

Rules:
- Per-second ticking comes from `TimelineView(.periodic(from: .now, by: 1))` wrapped around **only the two timer `Text`s** (pill + header) — never around the whole panel. Elapsed = `Int(context.date.timeIntervalSince(startedAt))`, clamped to ≥ 0.
- Summary stats are computed once when the panel appears (plain computed property read) — they do not tick.
- `runningEntry == nil` (idle) must be handled everywhere — see Section 10.
- View logic (formatting, lookups) lives in the store or `TimeFormatting`, not inline in `body`.

---

## 7. Component breakdown & behavior contract

General rules: each view in its own file; long bodies broken into extracted child `View` structs (not `some View` computed properties); button actions extracted to methods; `Button("Label", action: method)` form preferred; `#Preview` (dark) on every leaf view.

### `RootView.swift`
- `VStack { NotchShell(); Spacer() }` top-center in the 420×560 stage; everything outside the shell is `Color.clear` and non-interactive.

### `NotchShell.swift` (the heart)
- Reads `store.isExpanded`. One container that morphs: `.frame(width: isExpanded ? 380 : 220)`, height: fixed 36 collapsed / content-driven with `.frame(maxHeight: 480)` expanded.
- Surface stack + clip shape + stroke + hairline + shadows per Section 4; the shape's bottom radii animate 18 → 24.
- `.animation(NotchMetrics.shellSpring, value: store.isExpanded)` (Reduce Motion variant per Section 4).
- Content swap: `if isExpanded { ExpandedPanel() } else { CollapsedPill() }` with the transitions from Section 4. Content must never spill during the morph (the clip shape guarantees it).
- `.onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) })` → forwards the rect to the controller for click-through (Section 2).
- Collapsed shell: `.onTapGesture { store.expand() }` + `.pointerStyle(.link)`; expanded: default pointer on non-interactive areas.

### `CollapsedPill.swift`
- Layout: `ActiveDot(active:)` (8pt) — 8 gap — project name (12pt `.medium`, `textPrimary`, `lineLimit(1)`, `frame(maxWidth: 110, alignment: .leading)`) — `Spacer` — timer (12pt, `textSecondary`, `.monospacedDigit()`, inside `TimelineView`). Horizontal padding 14.
- Idle (`runningEntry == nil`): static `textTertiary` dot (no pulse), text `"No timer"`, no timer text.
- Hover: shell surface tint lifts to `surfaceHover` overlay, 0.15s ease.

### `ExpandedPanel.swift`
- `VStack(spacing: 12)`: `PanelHeader` / divider / `TodaySummary` / divider / `SectionLabel("Recent")` + `RecentEntries` / `QuickActions`. Padding 16. Dividers: 1pt `borderSubtle` rectangles.
- Applies the staggered entrance transitions (Section 4) — children indexed 0…4.

### `PanelHeader.swift`
- Running: `ProjectDot` + project name (15pt semibold) with description below (12pt `textSecondary`, `lineLimit(1)`); right side: timer 22pt `.light` `.monospacedDigit()` in `TimelineView`, plus a **Stop button** — 28pt circle, `surfaceRaised` fill, 10pt rounded-square stop glyph (`RoundedRectangle(cornerRadius: 2)`, not an SF Symbol square — or `Image(systemName: "stop.fill")` sized 10, acceptable). Hover: `surfaceHover` + glyph `accentRedDim`. `PressableButtonStyle`. Action → `stopTimer()`. Accessibility label `"Stop timer"`.
- Idle: `"Not tracking"` (15pt, `textSecondary`) + Play button (same circle, `play.fill`, hover tint `accentGreen`, label `"Start timer"`) → `startEntry()`.

### `TodaySummary.swift` + `StatBlock.swift`
- Three equal-width stats in an `HStack`: `6.4h / Tracked`, `7 / Entries`, `72% / Deep work`. Value 17pt semibold `textPrimary` `.monospacedDigit()`; label 11pt `textTertiary`.

### `RecentEntries.swift` + `EntryRow.swift`
- Exactly `store.recentEntries` (5 rows), plain `VStack` — **no `List`, no `ScrollView`**.
- Row (height 40): `ProjectDot` (6pt) + two-line block (description 13pt `textPrimary`; project name 11pt `textTertiary`) + `Spacer` + duration 12pt `textSecondary` `.monospacedDigit()`.
- Hover: `surfaceHover` background, `.rect(cornerRadius: 8)`, applied via background so text never shifts (use horizontal padding 8 inside a row that's inset −8, i.e. highlight extends past text). Not clickable in v1 — default pointer, but hover must still show.

### `QuickActions.swift` + `ActionButton.swift`
- Three stacked `ActionButton`s, 6 gap: SF Symbol 16pt `textSecondary` + label 13pt, height 36, `.rect(cornerRadius: 10)`, transparent → hover `surfaceHover`, icon/label brighten to `textPrimary`. `.pointerStyle(.link)`, `PressableButtonStyle`.
  - **Start New Entry** (`play.fill`) → `startEntry()`, then collapse after 0.25s (`Task { try? await Task.sleep(for: .milliseconds(250)); store.collapse() }`).
  - **Switch Project** (`arrow.left.arrow.right`) → `switchProject()` — stays open so the header visibly updates.
  - **Generate Daily Summary** (`sparkles`) → no-op acknowledgment: label crossfades to `"Coming soon"` for 1.2s, then back (local `@State` + `Task.sleep` — no `DispatchQueue.asyncAfter`).

---

## 8. Step-by-step build plan (stages)

Each stage ends with an app that builds and runs via the Section 1 loop. Do not start a stage until the previous one runs.

- **Stage 1 — Shell & panel:** XcodeGen project, agent app, `NotchPanel` configured and placed over the notch, static placeholder pill, click-through monitors with a hardcoded interactive rect.
- **Stage 2 — Design system & collapsed pill:** colors/metrics/blur representable, fully styled `CollapsedPill` with hardcoded text, dot pulse, hover.
- **Stage 3 — Expand/collapse morph:** `AppStore` (expansion only), `NotchShell` spring morph with skeleton panel body, Escape/⌘Q/resign-key handling, live interactive rect via `onGeometryChange`.
- **Stage 4 — Data & store:** models, mock data, formatters, full `AppStore`, `TimelineView` ticking pill, idle state.
- **Stage 5 — Expanded sections:** PanelHeader, TodaySummary, RecentEntries, QuickActions, staggered entrance, all actions working.
- **Stage 6 — Polish & QA:** edge cases (Section 10), polish details (Section 11), Reduce Motion, QA checklist.

---

## 9. Stage prompts (copy-paste, one at a time)

> Before each prompt, tell the model: *"Read PLAN.md in the repo root first. Follow it exactly — exact point values, exact colors, exact APIs. One type per Swift file. No dependencies. Build with the loop in PLAN.md Section 1 and confirm it runs before finishing."*

### Stage 1 prompt

```
Read PLAN.md. Build Stage 1 only.

1. Create project.yml for XcodeGen: app target "TogglNotch", macOS deployment target
   15.0, Swift 6, sources TogglNotch/, ad-hoc signing (CODE_SIGN_IDENTITY "-"),
   committed Info.plist at TogglNotch/Resources/Info.plist with LSUIElement = YES.
2. App/TogglNotchApp.swift: @main SwiftUI App, @NSApplicationDelegateAdaptor, body is
   Settings { EmptyView() }.
3. App/NotchPanel.swift + App/NotchPanelController.swift + App/AppDelegate.swift:
   implement the panel EXACTLY per PLAN.md Section 2 — styleMask, level statusBar+1,
   collectionBehavior, transparent/clear/no-shadow, darkAqua appearance, canBecomeKey
   override; placement on the notch screen (safeAreaInsets.top > 0, fallback main),
   420x560 frame flush to the top, repositioning on didChangeScreenParametersNotification.
4. Content: NSHostingView with a temporary RootView showing a static placeholder pill
   (220x36, Color(red:16/255,green:16/255,blue:18/255).opacity(0.92), bottom-only 18pt
   corners via UnevenRoundedRectangle, gray "notch" text), top-center in the stage.
5. Click-through per PLAN.md Section 2: ignoresMouseEvents starts true; global + local
   .mouseMoved NSEvent monitors toggle it against a HARDCODED interactive rect for now
   (the pill's screen rect, computed from the panel frame: 220x36 centered at top).
   Also add the local keyDown monitor now: Cmd+Q terminates the app.
6. Build and launch using the loop in Section 1. Fix until it runs.

Acceptance: the pill renders flush under the menu bar/notch on the notch screen, above
the menu bar, on every Space; no Dock icon; clicks anywhere outside the pill go to the
app behind; the cursor over the pill makes the window interactive (verify by logging);
Cmd+Q quits.
```

### Stage 2 prompt

```
Read PLAN.md. Build Stage 2 only (design system + collapsed pill).

1. DesignSystem/NotchColors.swift and DesignSystem/NotchMetrics.swift with the EXACT
   values from Section 4 (colors, sizes, radii, spacing, shellSpring).
2. DesignSystem/VisualEffectView.swift: NSViewRepresentable wrapping NSVisualEffectView,
   material .hudWindow, blendingMode .behindWindow, state .active.
3. Views/Collapsed/ActiveDot.swift: 8pt circle, accentGreen; active=true adds the halo
   pulse from Section 4 (scale 1→1.35, opacity 0.5→0, 2s repeatForever, value-bound
   animation toggled in onAppear); active=false renders a static textTertiary dot, no
   animation running.
4. Views/Collapsed/CollapsedPill.swift per Section 7, with hardcoded
   "Client — Atlas App" and "47:23" for now. The pill content is background-less.
5. Views/NotchShell.swift (first version, collapsed-only): owns the surface — blur +
   surfaceNotch fill, UnevenRoundedRectangle clip (bottom 18pt), borderSubtle stroke,
   inner top hairline, the two shadows from Section 4, hover lift to surfaceHover
   (0.15s ease, value-bound). Hosts CollapsedPill. pointerStyle(.link) on hover.
6. Views/RootView.swift: top-center stage hosting NotchShell. Keep Stage 1 click-through
   working. Use foregroundStyle (never foregroundColor), monospacedDigit() on the timer
   text, lineLimit(1) on the project name. Add a dark #Preview to each new view.
7. Build and run.

Acceptance: the pill looks fused to the notch — square top corners, rounded bottom,
subtle glass blur, hairline edge, pulsing green dot, hover lift, zero layout jitter.
```

### Stage 3 prompt

```
Read PLAN.md. Build Stage 3 only (expand/collapse morph). Sections 2 (key/blur,
click-through), 4 (motion) and 7 (NotchShell) are the spec.

1. Store/AppStore.swift (minimal for now): @MainActor @Observable with isExpanded,
   expand(), collapse(), toggleExpanded(), and onExpansionChange callback. Create it in
   AppDelegate, inject via .environment() into RootView.
2. Evolve NotchShell per Section 7: width 220↔380, height 36↔content (maxHeight 480),
   bottom radii 18↔24, animated with NotchMetrics.shellSpring bound to isExpanded.
   Content swap with the Section 4 transitions: CollapsedPill exits with 0.1s opacity;
   a temporary ExpandedPanel skeleton (three gray rounded blocks, ~380x420 with 16
   padding) enters opacity+6pt-rise with 0.08s delay.
3. Tap on collapsed shell → store.expand().
4. NotchPanelController: replace the hardcoded interactive rect — NotchShell reports its
   live frame via .onGeometryChange(for: CGRect.self) and the controller converts it to
   screen coordinates (mind the flipped y axis) for the mouse monitors.
5. Key handling per Section 2: on expand makeKey(); windowDidResignKey → collapse;
   local keyDown monitor: Escape (keyCode 53) while expanded → collapse and swallow.
   On every collapse, recompute ignoresMouseEvents against the current cursor position.
6. Respect accessibilityReduceMotion per Section 4 (easeOut 0.2 + opacity-only).
7. Build and run.

Acceptance: clicking the pill unfolds one continuous surface downward with a smooth
spring — no flash, no content spill, no double surface. Escape collapses. Clicking any
other app or the desktop collapses. Rapid toggling (10x fast) never sticks mid-state,
and click-through still works correctly after every collapse.
```

### Stage 4 prompt

```
Read PLAN.md. Build Stage 4 only (models, mock data, real state). Sections 5 and 6 are
the spec.

1. Models/Project.swift, Models/TimeEntry.swift, Models/RunningEntry.swift — exact
   shapes from Section 5, Identifiable/Hashable as specified, one type per file.
2. Data/MockData.swift — the exact seed data from Section 5 (5 projects with exact
   names/colors, running entry started 47m23s ago, 6 completed entries, 4 deep work).
3. Utilities/TimeFormatting.swift — formatTimer/formatDuration/formatHours with the
   exact output formats from Section 5. Verify edge values 0, 59, 3599, 3600, 6840 in
   a short comment table.
4. Expand AppStore to the full Section 6 shape: runningEntry, entries, projects, the
   derived computed properties, stopTimer()/startEntry()/switchProject() with the exact
   semantics. deepWorkPercent returns 0 when total is 0.
5. Wire CollapsedPill to the store: real project name (store.runningProject), live
   timer — a TimelineView(.periodic(from: .now, by: 1)) wrapping ONLY the timer Text,
   elapsed derived from runningEntry.startedAt, clamped ≥ 0, monospacedDigit.
6. Idle state: runningEntry = nil shows static gray dot + "No timer", no TimelineView
   running, no crash. Test by temporarily seeding nil, then restore.
7. Build and run.

Acceptance: the pill ticks once per second with zero digit jitter; quitting and
relaunching shows a sensibly larger elapsed (derived from startedAt, not counted).
```

### Stage 5 prompt

```
Read PLAN.md. Build Stage 5 only (expanded panel content). Section 7 is the spec —
follow every point size, color token, and behavior. Replace the Stage 3 skeleton.

Build in Views/Expanded/ and Views/Components/ (one type per file, #Preview on each):
1. Components/ProjectDot.swift (6pt circle in project.color) and
   Components/PressableButtonStyle.swift (scale 0.97 pressed, 0.2s spring).
2. PanelHeader.swift — running and idle variants exactly per Section 7, including the
   28pt circular Stop/Play button hover tints, accessibility labels, TimelineView timer
   (22pt light, monospacedDigit). Stop → store.stopTimer(); Play → store.startEntry().
3. TodaySummary.swift + StatBlock.swift — three equal-width stats from the store's
   derived properties.
4. SectionLabel.swift ("RECENT": 11pt medium, kerning 0.7, textTertiary) and
   RecentEntries.swift + EntryRow.swift — exactly 5 rows, 40pt, hover highlight that
   does not shift text, NO List/ScrollView.
5. QuickActions.swift + ActionButton.swift — the three actions with the exact behaviors
   in Section 7 (collapse-after-250ms via Task.sleep; Switch stays open; Summary shows
   "Coming soon" for 1.2s).
6. ExpandedPanel.swift — header / divider / summary / divider / RECENT + entries /
   QuickActions, 16 padding, 12 gaps, 1pt borderSubtle dividers, staggered entrance
   per Section 4 (indices 0…4).
7. Extract button actions into methods; no business logic inline in body. Build and run.

Acceptance: expanding shows all sections staggering in under ~350ms total; Stop moves
the running entry to the top of Recent and flips header+pill to idle; Switch Project
visibly updates header and pill; every interactive element has a hover state; the
panel never exceeds 480pt tall and shows no scrollbars.
```

### Stage 6 prompt

```
Read PLAN.md. Build Stage 6 only — polish and edge cases. No new features.

Work through PLAN.md Sections 10 and 11 as a checklist, then manually verify and fix:
1. Rapid expand/collapse (10x) never sticks, double-renders, or desyncs click-through.
2. Stop while expanded → idle header without layout jump; collapse → idle pill; Play
   restarts cleanly; deep-work % shows 0% when there are no entries (test by
   temporarily seeding empty data, then restore).
3. Temporarily rename a mock project to 60 characters: pill AND header truncate with
   ellipsis, nothing wraps or pushes the timer. Restore afterwards.
4. monospacedDigit audit: no width jitter on any ticking text.
5. Escape, click-on-other-app, and Cmd+Q all behave; after each collapse path the
   transparent stage still passes clicks through (verify against the rect resync rule
   in Section 2).
6. Unplug/replug an external display (or simulate by changing resolution): panel
   repositions onto the notch screen.
7. Reduce Motion ON (System Settings → Accessibility → Display): no spring bounce, no
   dot pulse, opacity-only content transitions.
8. Sleep the Mac 1+ minute, wake: timer shows the correct larger elapsed instantly.
9. Idle + collapsed: no TimelineView ticking (check with a render print), near-zero CPU.
10. Run a final pass for deprecated/legacy API: no foregroundColor, no cornerRadius(),
    no GeometryReader, no ObservableObject/@Published, no Timer, no valueless
    .animation(), no DispatchQueue.asyncAfter, one type per file.
```

---

## 10. Edge cases (must handle)

1. **Idle state** (`runningEntry == nil`) everywhere: pill, header, summary math — deep-work % is `0` when total seconds is 0 (no division by zero).
2. **Sleep/wake & clock correctness:** elapsed always derived from `startedAt` via `TimelineView`'s `context.date`; clamp negatives to 0.
3. **Click-through desync:** every collapse path (Escape, resign-key, action-triggered) recomputes `ignoresMouseEvents` from the current cursor position; the interactive rect updates continuously during the morph via `onGeometryChange`.
4. **Coordinate flip:** SwiftUI global frames are top-left origin; `NSEvent.mouseLocation` and window frames are bottom-left. Convert once, in the controller, with a tested helper.
5. **No-notch displays / external monitors:** fall back to `NSScreen.main`; it's a top-center pill there — fine for v1. Always reposition on screen-parameter changes.
6. **Fullscreen apps:** `.fullScreenAuxiliary` keeps the panel available over fullscreen Spaces; don't promise more in v1.
7. **Animation interruption:** SwiftUI springs retarget gracefully — never gate toggling behind an `isAnimating` flag.
8. **Text overflow:** `lineLimit(1)` + truncation on every project name and description; pill name capped at 110pt width.
9. **Borderless key window quirks:** Escape only arrives while the panel is key — that's why expand calls `makeKey()`; `.nonactivatingPanel` ensures the frontmost app doesn't lose focus visually.

## 11. Polish details (the difference between "demo" and "premium")

- Inner top hairline (`borderEdge`, 1pt) — sells the glass edge.
- Pill timer in `textSecondary`, not primary — hierarchy.
- Stagger that *finishes fast*: full entrance under ~350 ms; nothing should feel slow.
- Entry-row hover highlight extends 8pt past the text via negative-inset background — text never shifts.
- Dot pulse halo caps at 0.5 opacity; pulse stops entirely when idle (and under Reduce Motion).
- `accessibilityLabel` on the icon-only Stop/Play buttons; rows expose "description, project, duration" as a combined element.
- Pointer: `.pointerStyle(.link)` only on truly clickable things (collapsed pill, buttons); default elsewhere.
- `#Preview` with forced dark appearance on every view — the coding model should iterate in previews, not rebuild the app for every tweak.
- App icon and menu-bar presence: none — it's an `LSUIElement` notch app; ⌘Q via the key monitor is the only chrome.

## 12. Things to avoid

- **Never animate or resize the `NSPanel`.** All motion is SwiftUI inside the fixed stage.
- No `NSStatusItem`/`MenuBarExtra`, no Dock icon, no settings window, no tray menus — out of scope.
- No deprecated/legacy API: no `foregroundColor()`, `cornerRadius()`, `overlay(_:alignment:)`, `PreviewProvider`, or 1-parameter `onChange`.
- No `ObservableObject`/`@Published`/`@StateObject` — Observation only.
- No `Timer`, `Timer.publish`, or Combine for ticking — `TimelineView` only. No `DispatchQueue.asyncAfter` — `Task.sleep`.
- No `GeometryReader` — `onGeometryChange` covers the one measurement need.
- No valueless `.animation()`; no chained `withAnimation` via delays (use `completion:` if ever needed).
- No `List`/`ScrollView`/scrollbars anywhere; the panel is fixed-content.
- No bright/saturated colors, gradients on surfaces, colored shadows, or extra blur layers — one material, period.
- No third-party packages, no `AnyView`, no multiple types per file, no business logic inline in `body`.
- No "SaaS dashboard" styling: no visible card borders everywhere, no badges/chips, no table headers, no avatars.
