# Toggl Notch — UI Design Reference

Use this document as context when designing, implementing, or modifying the Toggl Notch interface. It describes the **current implemented design** (SwiftUI, macOS 15+, dark mode only).

---

## Product concept

**Toggl Notch** is a premium macOS notch utility for time tracking. It lives in a borderless panel floating **above the menu bar**, fused visually with the physical MacBook notch.

| State | Purpose |
|---|---|
| **Collapsed** | Compact bar beside the notch: work title, status dot, live timer |
| **Expanded** | Command-center panel that unfolds downward: routed content + pinned bottom NavBar |

**Design ethos:** Quiet, native, premium. Not a SaaS dashboard. No cards everywhere, no badges, no scrollbars on the home route. One glass material. SF Pro only. Feels like it ships with macOS.

---

## Layout overview

### Window stage

The OS window is a **fixed transparent stage** (560 × 600 pt). The shell morphs inside it — the window never resizes during animation. `hasShadow = false` on the panel; depth comes from the glass material and border only.

```
┌─────────────────────────────────────────────────────────────┐
│                    transparent stage (560×600)               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              NotchShell (morphing surface)           │    │
│  │  ┌──────────┐ ┌─────────┐ ┌──────────┐            │    │
│  │  │ left     │ │ notch   │ │ right    │  collapsed   │    │
│  │  │ strip    │ │ gap     │ │ strip    │              │    │
│  │  └──────────┘ └─────────┘ └──────────┘            │    │
│  │         OR expanded panel (routes + NavBar) ↓        │    │
│  └─────────────────────────────────────────────────────┘    │
│                         (click-through below)                │
└─────────────────────────────────────────────────────────────┘
```

### Collapsed layout (notch-aware)

The collapsed bar is **wider than the physical notch**. Info sits in strips on each side; the center is left clear for the camera housing.

```
┌──────────────────────────────────────────────────────────────┐
│ ● Design review notes   │  [notch gap]  │         47:23   │
│   104pt strip           │  dynamic width │   104pt strip   │
└──────────────────────────────────────────────────────────────┘
```

- **Total width:** `notchWidth + 2 × 104pt` (side strips)
- **Height:** matches physical notch height (typically ~36pt; fallback 36pt on notch-less displays)
- **Open trigger:** click (default) or hover — configurable in Settings → App
- **Pointer:** `.link` when open trigger is click

**Collapsed labels:**
- **Running:** entry description (falls back to project name), project dot or green active dot
- **Idle:** gray dot + "No timer"
- **Onboarding:** gray dot + "Set up"

### Expanded shell structure

Expanded content is a **ZStack** inside `PanelContent`:

```
┌──────────────────────────────────────────────────────────────┐
│  Route content (fills area above NavBar)                     │
│  — Home / Calendar / Settings / Composer / Onboarding      │
│                                                              │
├──────────────────────────────────────────────────────────────┤
│  [optional ErrorToast]                                       │
├──────────────────────────────────────────────────────────────┤
│  NavBar:  Home  ·  Calendar  ·  Settings                     │
└──────────────────────────────────────────────────────────────┘
```

- Route content has **41pt bottom padding** (NavBar height + divider)
- **NavBar** is pinned to the bottom on every authenticated route
- **Onboarding** replaces route content (no NavBar) until the API token is validated
- **Error toast** floats above the NavBar; auto-dismisses after 4s

### Home route layout

```
┌──────────────────────────────────────────────────────────────┐
│ [workspace chip]                                             │
│ What are you working on? _________________________  [▶]      │  ← idle header
│   OR  ● Entry title                          1:23:45  [■]    │  ← running header
│       Project name                                           │
├──────────────────────────────────────────────────────────────┤
│   6.4h        7           72%                                │  ← TodaySummary
│   Tracked     Entries     Deep work                          │
├──────────────────────────────────────────────────────────────┤
│ RECENT                                                       │
│ ● Design review notes                    38m    [✎] [▶]       │
│   Pixelmatters Website                                       │
│ ● Component API cleanup                  1h 12m [✎] [▶]       │
│   ...                                                        │
├──────────────────────────────────────────────────────────────┤
│  🏠 Home    📅 Calendar    ⚙ Settings                        │  ← NavBar
└──────────────────────────────────────────────────────────────┘
```

- **Width:** fills stage (560pt max) or `notchWidth + 208pt` when wider
- **Max height:** 520pt
- **Padding:** 16pt on home content
- **Section gap:** 12pt
- **Dividers:** 1pt `borderSubtle` horizontal rules
- **No ScrollView on home** — fixed content only; skeleton rows shown while loading

### Calendar route layout

```
┌──────────────────────────────────────────────────────────────┐
│  ← Calendar                              1:23:45 (if running)│  ← RouteHeader
├──────────────────────────────────────────────────────────────┤
│  ◀  MON TUE WED THU FRI SAT SUN  ▶                          │  ← DayStrip
├──────────────────────────────────────────────────────────────┤
│  WEDNESDAY · MMM D · 6.4H                                    │  ← SectionLabel
├──────────────────────────────────────────────────────────────┤
│  00:00 │ ┌─────────────┐                                     │
│  01:00 │ │ entry block │  ← ScrollView (hidden indicators)   │
│  ...   │ └─────────────┘                                     │
│        │                                    [+] [-] zoom      │
├──────────────────────────────────────────────────────────────┤
│  NavBar                                                      │
└──────────────────────────────────────────────────────────────┘
```

### Settings route layout

```
┌──────────────────────────────────────────────────────────────┐
│  ← Settings                                                  │  ← RouteHeader
├──────────────────────────────────────────────────────────────┤
│  [General] [Projects] [Tags] [Clients]  ← horizontal tabs    │
├──────────────────────────────────────────────────────────────┤
│  Pane content (ScrollView / List per section)                │
├──────────────────────────────────────────────────────────────┤
│  NavBar                                                      │
└──────────────────────────────────────────────────────────────┘
```

### Composer route (push)

Full-page entry composer pushed onto the route stack (modes: new, edit, continue). Uses `RouteHeader` + description field, project/tag pickers, optional time fields (edit), and a footer primary action. Not currently the primary edit path — recent entries and calendar blocks use inline popovers instead.

---

## Routing

| Route | Nav slot | Header | Scroll |
|---|---|---|---|
| `.home` | 1 (Home) | `PanelHeader` | No |
| `.calendar` | 2 | `RouteHeader` | Yes (`DayTimeline`) |
| `.settings(section)` | 3 | `RouteHeader` | Yes (pane-dependent) |
| `.composer(mode)` | — (stack push) | `RouteHeader` | No |
| Onboarding | — | — | No |

**Navigation:**
- **NavBar tap:** `popToHome()` then `push(target)` if not home
- **Back chevron** (`RouteHeader`): `pop()` one level
- **Escape:** collapse if on home; otherwise `pop()`
- **Route transitions:** asymmetric opacity + 8pt horizontal offset (push right, pop left); Reduce Motion → opacity only

---

## Color tokens (`NotchColors`)

Dark mode only. All surfaces use white overlays on dark glass — never pure white backgrounds.

### Surfaces

| Token | Value | Usage |
|---|---|---|
| `physicalNotch` | `#000000` | Solid black fused with notch housing; fusion gradient |
| `surfaceNotch` | `rgb(16,16,18) @ 62%` | Tint over blur material |
| `surfaceRaised` | white @ 4% | Circular icon buttons, NavBar active pill, timeline blocks |
| `surfaceHover` | white @ 7% | Hover states on rows, buttons, shell |
| `surfaceActive` | white @ 10% | (reserved) pressed/active surfaces |

### Borders

| Token | Value | Usage |
|---|---|---|
| `borderSubtle` | white @ 7% | Shell stroke (expanded), dividers |
| `borderEdge` | white @ 12% | Inner top hairline (1pt glass edge) |

### Text

| Token | Value | Usage |
|---|---|---|
| `textPrimary` | white @ 92% | Headings, primary content, active labels |
| `textSecondary` | white @ 55% | Timers (collapsed), descriptions, secondary text |
| `textTertiary` | white @ 32% | Section labels, meta, idle dot |

### Accents (muted — use sparingly)

| Token | Value | Usage |
|---|---|---|
| `accentGreen` | `rgb(48,209,88) @ 85%` | Active status dot, play button hover, today indicator |
| `accentRedDim` | `rgb(255,105,97) @ 90%` | Stop button hover, onboarding token error |

### Project colors

Project dots use colors from the Toggl API (`Project.color`). Mock data seeds dusty hues; production colors are workspace-defined.

Project dots are solid circles in project colors (6pt in rows, 8pt in headers/pickers).

---

## Typography

System font (SF Pro) only. Use `.foregroundStyle()` — never `foregroundColor`.

| Size | Weight | Usage |
|---|---|---|
| 20pt | `.light` | Expanded header live timer |
| 17pt | `.semibold` | Stat values (Tracked, Entries, Deep work) |
| 15pt | `.semibold` | Expanded header project/entry title, route titles |
| 15pt | regular | Idle description field, onboarding title |
| 13pt | regular | Entry descriptions, picker labels, action button labels |
| 12pt | `.medium` | Collapsed pill title & timer, route header mini-timer |
| 12pt | regular | Entry row durations, running header project line |
| 11pt | `.medium` + kerning 0.7 | Section labels (uppercase), workspace chip |
| 11pt | regular | Stat labels, entry project names, calendar day labels |

**Rules:**
- Every timer and duration uses `.monospacedDigit()` — no digit jitter
- Section labels: uppercase, 11pt medium, kerning 0.7, `textTertiary`
- All single-line text: `lineLimit(1)` + tail truncation where appropriate

### Time formatting

| Function | Example output | Context |
|---|---|---|
| `formatTimer(seconds)` | `"47:23"` or `"1:23:45"` | Live running timers |
| `formatDuration(seconds)` | `"38m"`, `"1h 12m"` | Completed entry rows |
| `formatHours(seconds)` | `"6.4h"` | Today summary stat, calendar day totals |

---

## Spacing & sizing (`NotchMetrics`)

### Shell dimensions

| Token | Value |
|---|---|
| Stage | 560 × 600 pt |
| Collapsed fallback width | 220 pt (notch-less displays) |
| Collapsed height | 36 pt |
| Collapsed side strip width | 104 pt each |
| Expanded max width | 400 pt (shell widens to stage when expanded) |
| Max expanded height | 520 pt |
| Collapsed corner radius | 14 pt (bottom corners only) |
| Expanded corner radius | 24 pt (bottom corners only) |
| Notch fusion solid band | 74 pt |
| Notch fusion fade span | 96 pt |

### Collapsed strip spacing

| Token | Value |
|---|---|
| Leading padding (left strip) | 16 pt |
| Trailing padding (left strip) | 8 pt |
| Item spacing (dot → name) | 6 pt |
| Status dot size | 8 pt |
| Right strip trailing padding | 16 pt |

### Expanded header

| Token | Value |
|---|---|
| Leading item spacing (dot → title) | 8 pt |
| Notch title clearance | 4 pt |
| Leading block max width | computed from shell width − notch column |

### Layout rhythm

| Token | Value |
|---|---|
| Panel padding | 16 pt |
| Section gap | 12 pt |
| Row height | 40 pt |
| Entry row horizontal padding | 8 pt |
| Action button height | 36 pt |
| Action button corner radius | 10 pt |
| Entry row hover corner radius | 8 pt |
| Circular icon button diameter | 28 pt |
| NavBar row height | 28 pt |
| NavBar total reserved height | 41 pt (incl. divider) |
| Error toast height | 32 pt |

### Shape

Shell uses `UnevenRoundedRectangle` — **square top corners, rounded bottom corners** so the surface fuses with the physical notch:

```
topLeading: 0    topTrailing: 0
bottomLeading: r  bottomTrailing: r   (r = 14 collapsed, 24 expanded)
```

---

## Surface & depth

### Layer stack (back → front)

1. **Glass material** — `.hudWindow` blur via `NSVisualEffectView` (`.behindWindow`, `.active`), or native `.glassEffect(.regular)` on macOS 26+
2. **`surfaceNotch` tint** — semi-transparent dark overlay on the blur (pre-macOS 26 path)
3. **Notch fusion gradient** — black band through top 74pt, then multi-stop ease-out fade over 96pt revealing glass below
4. **Content** — clipped to shell shape

### Border

- **Stroke:** 1pt `borderSubtle` (visible when expanded)
- **No window or SwiftUI drop shadow** — panel is shadowless

### Hover

- Rows / action buttons / icon buttons / NavBar slots: background → `surfaceHover` or `surfaceRaised`, foreground brightens
- **No scale on hover** — only color changes

### Press

`PressableButtonStyle`: `scaleEffect(0.97)` when pressed, 0.2s spring.

---

## Motion & animation

### Shell morph

One shared spring drives width, height, and corner radius:

```
Animation.spring(duration: 0.28, bounce: 0.04)
```

Bound to `store.isExpanded` — never use valueless `.animation()`.

**Reduce Motion:** `.easeOut(duration: 0.14)` instead of spring; opacity-only content transitions; no dot pulse.

### Matched geometry morph

Two elements morph between collapsed and expanded via `MorphID`:

| ID | Element | Collapsed | Expanded |
|---|---|---|---|
| `title` | `TruncatingLine` | Left strip, 12pt medium | Header leading, 15pt semibold |
| `timer` | TimelineView Text | Right strip, 12pt secondary | Header trailing, 20pt light |

The resting state owns `isSource: true` so morph works symmetrically open and close. Status dot does **not** morph — separate `ProjectDot` / `ActiveDot` instances in each layout.

### Content opacity (no cross-fade fighting the spring)

- **Collapsed strip:** fades out in 0.08s on expand; fades in after 0.05s delay on collapse
- **Expanded panel:** appears instantly on expand; fades out in 0.08s on collapse
- **Home body sections:** stagger on expand only — opacity + 6pt rise, delay `0.1 + index × 0.025`, duration 0.16s

### Route transitions

- Push: opacity + 8pt offset from trailing; pop: opacity + 8pt offset from leading
- Duration 0.18s ease-out (0.12s under Reduce Motion)

### Active dot pulse (running only)

- Halo circle behind dot: scale 1 → 1.35, opacity 0.5 → 0
- 2s repeating ease-out, no autoreverse
- **Paused when idle**, offline, or under Reduce Motion
- **Offline:** hollow ring (`strokeBorder`) instead of pulse

### NavBar selection

Active slot expands a capsule with icon + label (spring 0.32s, bounce 0.12). Inactive slots show icon only.

---

## Component catalog

### `ActiveDot`

- 8pt circle
- **Running:** `accentGreen` + pulsing halo
- **Idle:** static `textTertiary`, no animation
- **Offline:** hollow ring, no pulse

### `CollapsedPill`

| Zone | Content |
|---|---|
| Left strip | ActiveDot/ProjectDot + work title (or "Set up" during onboarding) |
| Center | Clear gap = physical notch width |
| Right strip | Live timer via TimelineView (hidden when idle) |

### `PanelHeader`

**Running state:**
- Optional: "Timer running in {workspace}" when browsing a different workspace than the running timer
- Optional: workspace chip (multi-workspace accounts)
- Leading: 8pt ProjectDot or ActiveDot + entry title (15pt semibold) + project name below (12pt secondary)
- Trailing: 20pt light timer + 28pt stop button (`stop.fill`, 10pt icon)
- Stop hover: `surfaceHover` + `accentRedDim` glyph
- Leading block width capped to stay left of the physical notch column

**Idle state (inline composer):**
- Optional: workspace chip
- Description `TextField` ("What are you working on?") + 28pt play button
- Row of compact `ProjectPickerRow` + `TagPickerRow`
- Return in description field starts timer; blocked while a recent-entry edit popover is open

### `RouteHeader`

- 40pt row: back chevron + title (15pt semibold) + optional trailing action + mini running timer (tappable → `popToHome()`)
- 1pt divider below

### `NavBar`

- Three equal slots: Home, Calendar, Settings
- Active slot: capsule `surfaceRaised`, icon + 11pt label
- Inactive: icon only (`textTertiary`), hover → `surfaceHover` + `textSecondary` glyph
- 1pt top divider

### `TodaySummary` / `StatBlock`

Three equal-width columns:

```
[value 17pt semibold, monospacedDigit, textPrimary]
[label 11pt, textTertiary]
```

Labels: "Tracked", "Entries", "Deep work". Replaced by three `SkeletonRow`s while `isLoadingHome`.

### `SectionLabel`

Uppercase text, 11pt medium, kerning 0.7, `textTertiary`. Example: `RECENT`

### `EntryRow`

- Height: 40pt
- 6pt ProjectDot + two-line block (description 13pt primary, project 11pt tertiary) + duration 12pt secondary
- Hover reveals edit (pencil) and continue (play) icon buttons at 24×24
- Tap row or edit → `RecentEntryEditPopover`; continue → `store.continueEntry` then collapse
- Hover: `surfaceHover` background, 8pt corner radius; `.pointerStyle(.link)`

### `RecentEntryEditPopover`

- 280pt-wide popover: description, project/tag pickers, time fields, Save / Delete
- Sets `store.isEditingRecentEntry` while open

### `SkeletonRow`

- Pulsing placeholder matching entry row proportions during home load

### `ActionButton`

- Height 36pt, corner radius 10pt — reusable row button style
- Not used on the home route currently; retained for future actions

### `CircularIconButton`

28pt circle, `surfaceRaised` default, `surfaceHover` on hover. Used for Stop/Play in header, RouteHeader back/action. Accessibility label required.

### `ProjectPickerRow` / `TagPickerRow`

- 40pt tappable row opening a search popover
- Compact mode: single-line for header; full mode: shows client subtitle

### `GhostCreateRow`

- Inline create row for settings panes: "+" label → TextField on tap

### `ErrorToastView`

- 32pt bar above NavBar: warning icon + message + optional Retry
- `surfaceRaised` background, 10pt corner radius
- Slides up from bottom (or opacity-only under Reduce Motion)

### `DayTimeline` / `TimelineEventBlock`

- 24h vertical timeline with hour labels, grid lines, overlapping entry columns
- Entry blocks: 4pt color bar + description + duration; tap → edit popover; context menu: Edit, Continue, Delete
- Zoom controls (+/−) adjust hour height (32–72pt, default 48pt)
- Green now-indicator line on today
- Scroll indicators hidden

### `OnboardingView`

- Centered: title, token field, Connect button, link to Toggl profile
- Shown when no Keychain token or token validation pending

### Settings panes

| Pane | Content style |
|---|---|
| `GeneralSettingsPane` | `Form` in `ScrollView` — workspace, API token, app prefs |
| `ProjectsSettingsPane` | `List` of projects + inline create |
| `TagsSettingsPane` | `List` of tags + inline create |
| `ClientsSettingsPane` | `List` of clients + inline create |

Settings tabs use horizontal `ScrollView` with capsule buttons (`surfaceRaised` selected).

### `TruncatingLine`

Single-line text with ellipsis. Matched geometry attaches via `morphMatched` helper, not directly on `Text`.

---

## Interaction model

| Action | Behavior |
|---|---|
| Tap/hover collapsed bar | Expand (per `panelOpenTrigger` setting) |
| Escape | Collapse on home; `pop()` on sub-routes |
| Click outside / switch app | Collapse (window resigns key) |
| ⌘Q | Quit app |
| NavBar slot | Switch route (resets stack to home, then pushes) |
| RouteHeader back | Pop one route |
| RouteHeader mini timer | Pop to home |
| Collapsed bar pointer | `.link` when open trigger is click |
| Buttons / entry rows / NavBar | `.link` |
| Menu bar → Settings | `summonPanel(route: .settings(.general))` |

Live timer ticks via `TimelineView(.periodic(from: .now, by: 1))` wrapped around **timer Text only** — not the whole panel.

---

## Accessibility

- `@Environment(\.accessibilityReduceMotion)` respected throughout
- Reduce Motion: no spring bounce, no dot pulse, opacity-only transitions
- Icon-only buttons: `accessibilityLabel` ("Stop timer", "Start timer", nav slots, zoom controls)
- Entry rows and timeline blocks: button traits + descriptive labels
- Dark mode forced via `NSAppearance(.darkAqua)` regardless of system setting

---

## Visual anti-patterns (do not add)

- Bright/saturated colors, gradients on surfaces, colored shadows
- Extra blur layers beyond the single glass material
- Card borders everywhere, badges, chips, table headers, avatars
- ScrollView or List on the **home route** (calendar and settings are exceptions)
- Visible scroll indicators (always `.hidden` where scrolling is required)
- SaaS dashboard styling
- Scale on hover (press scale only)
- `foregroundColor`, deprecated corner APIs, valueless `.animation()`
- Multiple fonts or custom typefaces

---

## File map (design-related)

```
DesignSystem/
  NotchColors.swift      — color tokens
  NotchMetrics.swift     — sizes, spacing, motion curves, shell shape
  MorphNamespace.swift   — matched geometry IDs + environment helper
  VisualEffectView.swift — behind-window blur (pre-macOS 26)

State/
  PanelRoute.swift       — home, composer, calendar, settings
  SettingsRoute.swift    — general, projects, tags, clients
  PanelOpenTrigger.swift — click vs hover expand

Views/
  RootView.swift         — top-aligned stage
  NotchShell.swift       — morphing surface container
  PanelContent.swift     — route switching, NavBar, error toast
  Collapsed/             — CollapsedPill, ActiveDot
  Expanded/              — ExpandedPanel, PanelHeader, TodaySummary, StatBlock,
                           RecentEntries, EntryRow, SectionLabel, ActionButton,
                           RecentEntryEditPopover
  Routes/                — HomeRouteView, ComposerView, CalendarView, DayTimeline,
                           SettingsView, OnboardingView, RouteHeader,
                           ProjectPickerPopover, TagPickerPopover, TimeFieldRow
  Settings/              — GeneralSettingsPane, ProjectsSettingsPane,
                           TagsSettingsPane, ClientsSettingsPane,
                           WorkspaceSwitcherPopover
  Components/            — NavBar, ProjectDot, CircularIconButton,
                           PressableButtonStyle, TruncatingLine, SkeletonRow,
                           GhostCreateRow, ErrorToastView, WheelTimePicker
```

---

## Quick reference — collapsed vs expanded

| Property | Collapsed | Expanded |
|---|---|---|
| Width | notch + 208pt | stage width (560pt) |
| Height | notch height (~36pt) | up to 520pt |
| Bottom radius | 14pt | 24pt |
| Top corners | Square (fused to notch) | Square |
| Primary action | Tap/hover to expand | Stop/Play, route navigation |
| Timer size | 12pt secondary | 20pt light primary |
| Content | Pill strips only | Routed panel + NavBar |
