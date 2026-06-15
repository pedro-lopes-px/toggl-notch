# Toggl Notch — UI Design Reference

Use this document as context when designing, implementing, or modifying the Toggl Notch interface. It describes the **current implemented design** (SwiftUI, macOS 15+, dark mode only).

---

## Product concept

**Toggl Notch** is a premium macOS notch utility for time tracking. It lives in a borderless panel floating **above the menu bar**, fused visually with the physical MacBook notch.

| State | Purpose |
|---|---|
| **Collapsed** | Compact bar beside the notch: running project name, status dot, live timer |
| **Expanded** | Command-center panel that unfolds downward: header, today stats, recent entries, quick actions |

**Design ethos:** Quiet, native, premium. Not a SaaS dashboard. No cards everywhere, no badges, no scrollbars, no bright saturated colors. One glass material. SF Pro only. Feels like it ships with macOS.

---

## Layout overview

### Window stage

The OS window is a **fixed transparent stage** (560 × 600 pt). The shell morphs inside it — the window never resizes during animation.

```
┌─────────────────────────────────────────────────────────────┐
│                    transparent stage (560×600)               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              NotchShell (morphing surface)           │    │
│  │  ┌──────────┐ ┌─────────┐ ┌──────────┐            │    │
│  │  │ left     │ │ notch   │ │ right    │  collapsed   │    │
│  │  │ strip    │ │ gap     │ │ strip    │              │    │
│  │  └──────────┘ └─────────┘ └──────────┘            │    │
│  │         OR full-width expanded panel ↓               │    │
│  └─────────────────────────────────────────────────────┘    │
│                         (click-through below)                │
└─────────────────────────────────────────────────────────────┘
```

### Collapsed layout (notch-aware)

The collapsed bar is **wider than the physical notch**. Info sits in strips on each side; the center is left clear for the camera housing.

```
┌──────────────────────────────────────────────────────────────┐
│ ● Project name          │  [notch gap]  │         47:23   │
│   104pt strip           │  dynamic width │   104pt strip   │
└──────────────────────────────────────────────────────────────┘
```

- **Total width:** `notchWidth + 2 × 104pt` (side strips)
- **Height:** matches physical notch height (typically ~36pt; fallback 36pt on notch-less displays)
- **Tap anywhere** on the bar → expand
- **Pointer:** `.link` on collapsed bar

### Expanded layout

```
┌──────────────────────────────────────────────────────────────┐
│ ● Project Name                              1:23:45  [■]     │  ← PanelHeader
│   Entry description                                          │
├──────────────────────────────────────────────────────────────┤
│   6.4h        7           72%                                │  ← TodaySummary
│   Tracked     Entries     Deep work                          │
├──────────────────────────────────────────────────────────────┤
│ RECENT                                                       │
│ ● Design review notes                              38m       │
│   Pixelmatters Website                                       │
│ ● Component API cleanup                            1h 12m    │
│   ...                                                        │
├──────────────────────────────────────────────────────────────┤
│ ▶ Start New Entry                                            │  ← QuickActions
│ ⇄ Switch Project                                             │
│ ✦ Generate Daily Summary                                     │
└──────────────────────────────────────────────────────────────┘
```

- **Width:** fills stage (560pt max) or `notchWidth + 208pt` when wider
- **Max height:** 520pt
- **Padding:** 16pt all sides
- **Section gap:** 12pt
- **Dividers:** 1pt `borderSubtle` horizontal rules
- **No ScrollView, no List** — fixed content only

---

## Color tokens (`NotchColors`)

Dark mode only. All surfaces use white overlays on dark glass — never pure white backgrounds.

### Surfaces

| Token | Value | Usage |
|---|---|---|
| `physicalNotch` | `#000000` | Solid black fused with notch housing; fusion gradient |
| `surfaceNotch` | `rgb(16,16,18) @ 62%` | Tint over blur material |
| `surfaceRaised` | white @ 4% | Circular icon buttons (default) |
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
| `accentGreen` | `rgb(48,209,88) @ 85%` | Active status dot, play button hover |
| `accentRedDim` | `rgb(255,105,97) @ 90%` | Stop button hover only |

### Project colors (muted / dusty — no pure hues)

| Project | Hex |
|---|---|
| Pixelmatters Website | `#7A8CF0` |
| Client — Atlas App | `#C9A06A` |
| Design System | `#9B8CE0` |
| Internal Tools | `#6FB8A8` |
| Research | `#B0788C` |

Project dots are solid circles in these colors (6pt in rows, 8pt in headers).

---

## Typography

System font (SF Pro) only. Use `.foregroundStyle()` — never `foregroundColor`.

| Size | Weight | Usage |
|---|---|---|
| 22pt | `.light` | Expanded header live timer |
| 17pt | `.semibold` | Stat values (Tracked, Entries, Deep work) |
| 15pt | `.semibold` | Expanded header project name |
| 15pt | regular | Idle header "Not tracking" |
| 13pt | regular | Entry descriptions, action button labels |
| 12pt | `.medium` | Collapsed pill project name & timer |
| 12pt | regular | Entry row durations, header description |
| 11pt | `.medium` + kerning 0.7 | Section labels (uppercase) |
| 11pt | regular | Stat labels, entry project names |

**Rules:**
- Every timer and duration uses `.monospacedDigit()` — no digit jitter
- Section labels: uppercase, 11pt medium, kerning 0.7, `textTertiary`
- All single-line text: `lineLimit(1)` + tail truncation

### Time formatting

| Function | Example output | Context |
|---|---|---|
| `formatTimer(seconds)` | `"47:23"` or `"1:23:45"` | Live running timers |
| `formatDuration(seconds)` | `"38m"`, `"1h 12m"` | Completed entry rows |
| `formatHours(seconds)` | `"6.4h"` | Today summary stat |

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

### Collapsed strip spacing

| Token | Value |
|---|---|
| Leading padding (left strip) | 16 pt |
| Trailing padding (left strip) | 8 pt |
| Item spacing (dot → name) | 6 pt |
| Status dot size | 8 pt |
| Right strip trailing padding | 16 pt |

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
2. **`surfaceNotch` tint** — semi-transparent dark overlay on the blur
3. **Notch fusion gradient** — black band through top 74pt, then top-heavy fade over 56pt revealing glass below
4. **Content** — clipped to shell shape

### Border & shadow

- **Stroke:** 1pt `borderSubtle` (visible when expanded)
- **Inner hairline:** 1pt `borderEdge` at top inside shape (subtle glass edge)
- **Shadow:** drawn in SwiftUI (panel has `hasShadow = false`):
  - `.shadow(black @ 55%, radius 24, y 16)`
  - `.shadow(black @ 35%, radius 6, y 4)`

### Hover

- Collapsed shell: surface lifts to `surfaceHover`, 0.15s ease
- Rows / action buttons / icon buttons: background → `surfaceHover`, foreground brightens
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

Three elements morph between collapsed and expanded via `matchedGeometryEffect`:

| ID | Element | Collapsed | Expanded |
|---|---|---|---|
| `statusDot` | ActiveDot / ProjectDot | Left strip | Header leading |
| `projectName` | TruncatingLine | 12pt medium | 15pt semibold |
| `timer` | TimelineView Text | 12pt secondary, right strip | 22pt light, header trailing |

The resting state owns `isSource: true` so morph works symmetrically open and close.

### Content opacity (no cross-fade fighting the spring)

- **Collapsed strip:** fades out in 0.08s on expand; fades in after 0.05s delay on collapse
- **Expanded panel:** appears instantly on expand; fades out in 0.08s on collapse
- **Body sections:** stagger on expand only — opacity + 6pt rise, delay `0.1 + index × 0.025`, duration 0.16s. Full reveal under ~350ms total.

### Active dot pulse (running only)

- Halo circle behind dot: scale 1 → 1.35, opacity 0.5 → 0
- 2s repeating ease-out, no autoreverse
- **Paused when idle** and under Reduce Motion

---

## Component catalog

### `ActiveDot`

- 8pt circle
- **Running:** `accentGreen` + pulsing halo
- **Idle:** static `textTertiary`, no animation

### `CollapsedPill`

| Zone | Content |
|---|---|
| Left strip | ActiveDot + project name (or "No timer" when idle) |
| Center | Clear gap = physical notch width |
| Right strip | Live timer via TimelineView (hidden when idle) |

Idle: gray dot, "No timer" in `textSecondary`, no timer text.

### `PanelHeader`

**Running state:**
- Leading: 8pt ProjectDot + project name (15pt semibold) + description (12pt secondary)
- Trailing: 22pt light timer + 28pt stop button (`stop.fill`, 10pt icon)
- Stop hover: `surfaceHover` + `accentRedDim` glyph

**Idle state:**
- Leading: "Not tracking" (15pt, `textSecondary`)
- Trailing: 28pt play button (`play.fill`, 11pt icon)
- Play hover: `surfaceHover` + `accentGreen` glyph

Description and stop button fade in with 0.12s ease + 0.06s delay when expanded.

### `TodaySummary` / `StatBlock`

Three equal-width columns:

```
[value 17pt semibold, monospacedDigit, textPrimary]
[label 11pt, textTertiary]
```

Labels: "Tracked", "Entries", "Deep work"

### `SectionLabel`

Uppercase text, 11pt medium, kerning 0.7, `textTertiary`. Example: `RECENT`

### `EntryRow`

- Height: 40pt
- 6pt ProjectDot + two-line block (description 13pt primary, project 11pt tertiary) + duration 12pt secondary
- Hover: `surfaceHover` background, 8pt corner radius
- Hover highlight extends 8pt past text via negative inset on parent — **text never shifts**
- Not clickable in v1; default pointer

### `ActionButton`

- Height 36pt, corner radius 10pt
- SF Symbol 16pt + label 13pt, 10pt horizontal padding
- Default: `textSecondary` on transparent
- Hover: `surfaceHover` background, `textPrimary` foreground
- `.pointerStyle(.link)` + `PressableButtonStyle`

**Quick actions:**
1. **Start New Entry** (`play.fill`) → start, collapse after 250ms
2. **Switch Project** (`arrow.left.arrow.right`) → cycle project, stay open
3. **Generate Daily Summary** (`sparkles`) → label crossfades to "Coming soon" for 1.2s (no-op)

### `CircularIconButton`

28pt circle, `surfaceRaised` default, `surfaceHover` on hover. Used for Stop/Play in header. Accessibility label required.

### `TruncatingLine`

Single-line text with ellipsis. Matched geometry attaches to layout slot, not Text, to avoid truncation/morph conflicts.

---

## Interaction model

| Action | Behavior |
|---|---|
| Tap collapsed bar | Expand |
| Escape | Collapse |
| Click outside / switch app | Collapse (window resigns key) |
| ⌘Q | Quit app |
| Collapsed bar pointer | `.link` |
| Buttons / action rows pointer | `.link` |
| Entry rows pointer | Default (hover only) |

Live timer ticks via `TimelineView(.periodic(from: .now, by: 1))` wrapped around **timer Text only** — not the whole panel.

---

## Accessibility

- `@Environment(\.accessibilityReduceMotion)` respected throughout
- Reduce Motion: no spring bounce, no dot pulse, opacity-only transitions
- Icon-only buttons: `accessibilityLabel` ("Stop timer", "Start timer")
- Dark mode forced via `NSAppearance(.darkAqua)` regardless of system setting

---

## Visual anti-patterns (do not add)

- Bright/saturated colors, gradients on surfaces, colored shadows
- Extra blur layers beyond the single glass material
- Card borders everywhere, badges, chips, table headers, avatars
- ScrollView, List, scrollbars
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
  MorphNamespace.swift   — matched geometry IDs
  VisualEffectView.swift — behind-window blur

Views/
  RootView.swift         — top-aligned stage
  NotchShell.swift       — morphing surface container
  Collapsed/             — CollapsedPill, ActiveDot
  Expanded/              — ExpandedPanel, PanelHeader, TodaySummary, StatBlock,
                           RecentEntries, EntryRow, QuickActions, ActionButton,
                           SectionLabel
  Components/            — ProjectDot, CircularIconButton, PressableButtonStyle,
                           TruncatingLine
```

---

## Quick reference — collapsed vs expanded

| Property | Collapsed | Expanded |
|---|---|---|
| Width | notch + 208pt | stage width (560pt) |
| Height | notch height (~36pt) | up to 520pt |
| Bottom radius | 14pt | 24pt |
| Top corners | Square (fused to notch) | Square |
| Primary action | Tap to expand | Stop/Play, quick actions |
| Timer size | 12pt secondary | 22pt light primary |
| Content | Pill strips only | Full panel sections |
