# Toggl Notch

A native macOS app that turns your MacBook notch into a compact Toggl Track companion. A small pill sits flush under the menu bar showing your running timer; click or hover to expand a command-center panel for today's summary, recent entries, and quick actions.

Built with SwiftUI and AppKit. No third-party dependencies.

## Requirements

- macOS **26.4** or later (see `MACOSX_DEPLOYMENT_TARGET` in the Xcode project)
- A Mac with a physical notch (the UI is designed around it; the app falls back to the main display on other Macs)
- A [Toggl Track](https://track.toggl.com/) account
- Xcode 26+ to build from source

## Features

- **Collapsed pill** — running project, status dot, and live timer beside the notch
- **Expanded panel** — today's stats, recent entries, start/stop, composer, and calendar
- **Settings** — workspace switcher, projects, tags, clients, launch at login, menu bar icon
- **Offline-friendly** — caches data locally; syncs when you're back online

The app runs as a menu-bar agent (`LSUIElement`): no Dock icon. Use the notch panel or the optional menu bar item to interact with it.

## Build and run

1. Clone the repository.
2. Open `toggl-notch.xcodeproj` in Xcode.
3. Select the **toggl-notch** scheme and your Mac as the run destination.
4. Press **⌘R** to build and run.

From the command line:

```bash
xcodebuild -project toggl-notch.xcodeproj -scheme toggl-notch -configuration Debug build
```

## Connect your Toggl API token

Toggl Notch talks to the [Toggl Track API v9](https://engineering.toggl.com/docs/) using a **personal API token**. The token is stored in the macOS Keychain on your machine — it is never written to the repo or any config file.

### 1. Get your token from Toggl

1. Sign in to [Toggl Track](https://track.toggl.com/).
2. Open your profile page: [track.toggl.com/profile](https://track.toggl.com/profile).
3. Scroll to **API Token**.
4. Copy the token (or generate a new one if needed).

Keep this token private. Anyone with it can access your Toggl account via the API.

### 2. Enter the token in the app

**First launch (onboarding)**

1. Run Toggl Notch.
2. When the panel opens, you'll see **Paste your Toggl API token**.
3. Paste the token into the field and click **Connect**.
4. The app validates the token against Toggl, saves it to Keychain, and loads your workspaces.

If the token is wrong, you'll see *"That token didn't work"*. Double-check you copied the full token with no extra spaces.

**Later (replace token)**

1. Expand the panel and open **Settings** (gear icon in the bottom nav, or **Settings…** from the menu bar).
2. Go to the **General** tab.
3. Under **API → Token**, click **Replace…**.
4. Paste the new token and press **Return**.

### 3. What happens under the hood

- On connect, the app calls Toggl's `/me` endpoint to verify the token.
- The token is saved with `KeychainStore` (macOS Keychain, generic password).
- Every API request sends `Authorization: Basic <base64(token:api_token)>`, which is Toggl's standard auth format.
- On launch, if a token is already in Keychain, the app bootstraps automatically — no need to enter it again.

To sign out or clear the token, remove it from Keychain (e.g. Keychain Access → search for `com.yourcompany.togglnotch.apitoken`) or replace it with a new one in Settings.

## Usage tips

| Action | How |
|--------|-----|
| Open / close panel | Click or hover the pill (configurable in **Settings → General → Open panel**) |
| Collapse expanded panel | **Esc** |
| Quit | **⌘Q**, menu bar **Quit**, or **Settings → General → Quit Toggl Notch** |
| Stop timer | Menu bar **Stop Timer** (**⌘S** when the menu is open) |
| Switch workspace | **Settings → General → Active workspace** |

## Project layout

```
toggl-notch/
├── App/              # App entry, NSPanel shell, delegates
├── Store/            # NotchStore — app state and routing
├── Services/         # Toggl API client, Keychain, repos
├── Views/            # SwiftUI UI (collapsed, expanded, settings, routes)
├── Models/           # Domain types
└── DesignSystem/     # Colors, metrics, morph animations
```

For UI and design details, see [DESIGN_UI.md](DESIGN_UI.md).

## Security

- **Do not** commit your API token or add it to `.env` files.
- The token lives only in your local Keychain.
- The app is sandboxed with network client access to reach `api.track.toggl.com`.

## License

No license file is included yet. All rights reserved by the author unless stated otherwise.
