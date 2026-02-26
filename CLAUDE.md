# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Watchdog is a native macOS menu bar application that displays Claude Code usage in real-time. Built with Swift/SwiftUI, it consists of:

- **Main App** (ClaudeWatchdog): Menu bar status item with popover UI
- **Widget Extension** (ClaudeWatchdogWidget): WidgetKit extension for desktop widgets

**Key Characteristics:**
- **XcodeGen-based**: `.xcodeproj` is generated from `project.yml` and is gitignored
- **Universal Binary**: Supports both ARM64 (Apple Silicon) and x86_64 (Intel)
- **Dual Sandbox Model**: Main app runs without sandbox (for Keychain subprocess access), widget runs in sandbox with App Groups

## Build Commands

### Generate Xcode Project

**Always regenerate after editing `project.yml`:**

```bash
xcodegen generate
```

### Build (Debug)

```bash
xcodebuild -project ClaudeWatchdog.xcodeproj \
  -scheme ClaudeWatchdog \
  -configuration Debug \
  -derivedDataPath build \
  build
```

### Build Universal Binary (Release)

```bash
xcodebuild -project ClaudeWatchdog.xcodeproj \
  -scheme ClaudeWatchdog \
  -configuration Release \
  -derivedDataPath build \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  build
```

### Run Built App

```bash
open build/Build/Products/Debug/Claude\ Watchdog.app
# or
open build/Build/Products/Release/Claude\ Watchdog.app
```

### Install to /Applications

```bash
# Kill existing instance first
pkill -f "Claude Watchdog"

# Remove old version
rm -rf "/Applications/Claude Watchdog.app"

# Copy new version
cp -R "build/Build/Products/Release/Claude Watchdog.app" "/Applications/Claude Watchdog.app"

# Launch
open "/Applications/Claude Watchdog.app"
```

## Architecture

### Data Flow

```
┌──────────────────┐
│  MenuBarManager  │ ← Central orchestrator, manages refresh timer
└────────┬─────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌──────────────────┐     ┌──────────────────┐
│ CredentialService│────▶│  ClaudeAPIService│
└──────────────────┘     └────────┬─────────┘
    │                             │
    │ /usr/bin/security           │ HTTPS GET
    │ subprocess                  │ https://api.anthropic.com/api/oauth/usage
    ▼                             ▼
┌──────────────────┐     ┌──────────────────┐
│  macOS Keychain  │     │   Claude API     │
│ (Claude Code)    │     │                  │
└──────────────────┘     └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │   ClaudeUsage    │ ← Data model
                         └────────┬─────────┘
                                  │
                    ┌─────────────┴──────────────┐
                    ▼                            ▼
            ┌──────────────────┐     ┌──────────────────┐
            │ MenuBarIconRenderer│   │SharedUsageStore  │
            │ (NSImage)         │     │ (App Groups)    │
            └──────────────────┘     └────────┬─────────┘
                                              │
                                              ▼
                                    ┌──────────────────┐
                                    │ Widget Extension │
                                    │ (WidgetKit)      │
                                    └──────────────────┘
```

### Key Components

**MenuBarManager** (`ClaudeWatchdog/MenuBar/MenuBarManager.swift`)
- Central coordinator that manages all app state
- Owns `NSStatusItem` (menu bar) and `NSPopover` (UI)
- Manages refresh timer (default: 30 seconds)
- Publishes `@Published var usage: ClaudeUsage` for UI updates
- Handles credential validation, API refresh, icon updates
- Reloads widget timelines via `WidgetCenter.shared.reloadAllTimelines()`

**CredentialService** (`ClaudeWatchdog/Services/CredentialService.swift`)
- Reads Claude Code OAuth token from macOS Keychain
- Uses subprocess `/usr/bin/security find-generic-password` (requires sandbox OFF)
- Service name: `"Claude Code-credentials"`, Account: current user
- Validates token expiry via `expiresAt` timestamp
- Extracts `claudeAiOauth.accessToken` from JSON credential

**ClaudeAPIService** (`ClaudeWatchdog/Services/ClaudeAPIService.swift`)
- Fetches usage from `https://api.anthropic.com/api/oauth/usage`
- Required headers:
  - `Authorization: Bearer <token>`
  - `User-Agent: claude-code/2.1.5`
  - `anthropic-beta: oauth-2025-04-20`
- Parses `five_hour`, `seven_day`, `seven_day_opus`, `seven_day_sonnet` utilization

**SharedUsageStore** (`ClaudeWatchdog/Services/SharedUsageStore.swift`)
- Shares `ClaudeUsage` data between main app and widget
- Uses App Groups container: `YXPA46F4SJ.com.dante-labs.ClaudeWatchdog`
- File path: `~/Library/Group Containers/<group-id>/Library/Application Support/shared-usage.json`
- Fallback to `~/Library/Application Support/ClaudeWatchdog/` if App Groups unavailable

**AppSettings** (`ClaudeWatchdog/Models/AppSettings.swift`)
- Singleton with `@Published` properties persisted via `UserDefaults`
- `iconStyle`: percentage | progressBar | battery
- `refreshInterval`: 15s, 30s, 60s, 300s
- `alertAt75/90/95`: notification thresholds
- `launchAtLogin`: uses `SMAppService.mainApp.register()` (macOS 13+)

### Entitlements & Sandbox

**Main App** (`ClaudeWatchdog/App/ClaudeWatchdog.entitlements`):
```xml
<key>com.apple.security.app-sandbox</key>
<false/>  <!-- OFF: Required for subprocess Keychain access -->
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.application-groups</key>
<array>
  <string>YXPA46F4SJ.com.dante-labs.ClaudeWatchdog</string>
</array>
```

**Widget Extension** (`ClaudeWatchdogWidget/ClaudeWatchdogWidget.entitlements`):
```xml
<key>com.apple.security.app-sandbox</key>
<true/>  <!-- ON: WidgetKit requirement -->
<key>com.apple.security.application-groups</key>
<array>
  <string>YXPA46F4SJ.com.dante-labs.ClaudeWatchdog</string>
</array>
```

**Why this matters:**
- Main app MUST have sandbox OFF to execute `/usr/bin/security` subprocess
- Widget MUST have sandbox ON or `chronod` won't load it
- Both share data via App Groups container (file-based, not UserDefaults)

## Code Style & Patterns

### ObservableObject Pattern
- `MenuBarManager`, `AppSettings` are `ObservableObject` singletons
- Use `@Published` properties for reactive UI updates
- SwiftUI views subscribe via `@ObservedObject`

### Error Handling
- Services define custom error enums conforming to `LocalizedError`
- Example: `CredentialService.CredentialError`, `ClaudeAPIService.APIError`
- Propagate errors with `throws`, catch at UI boundary (MenuBarManager)

### Async/Await for API Calls
```swift
// Inside MenuBarManager.refresh()
Task { @MainActor in
    let newUsage = try await ClaudeAPIService.shared.fetchUsage()
    usage = newUsage
}
```

### Combine for Reactive Bindings
```swift
AppSettings.shared.$iconStyle
    .sink { [weak self] _ in self?.updateIcon() }
    .store(in: &cancellables)
```

## Distribution & Signing

### Code Signing Requirements

**For distribution outside App Store:**
1. Sign with **Developer ID Application** certificate (not Apple Development)
2. Submit for **Apple Notarization** via `notarytool`
3. Staple notarization ticket to app bundle

### Notarization Workflow

```bash
# 1. Sign with Developer ID
codesign --force --options runtime \
  --sign "Developer ID Application: <Name> (<Team ID>)" \
  --entitlements ClaudeWatchdog/App/ClaudeWatchdog.entitlements \
  "build/Build/Products/Release/Claude Watchdog.app"

# 2. Create zip for notarization
ditto -c -k --keepParent "build/Build/Products/Release/Claude Watchdog.app" \
  "Claude-Watchdog.zip"

# 3. Submit to Apple (requires App-specific password)
xcrun notarytool submit "Claude-Watchdog.zip" \
  --keychain-profile "notarize" \
  --wait

# 4. Staple notarization ticket
xcrun stapler staple "build/Build/Products/Release/Claude Watchdog.app"
```

### DMG Creation

```bash
# Requires: brew install create-dmg
create-dmg \
  --volname "Claude Watchdog" \
  --window-size 600 400 \
  --icon-size 128 \
  --icon "Claude Watchdog.app" 150 185 \
  --app-drop-link 450 185 \
  Claude-Watchdog-1.0.0-Universal.dmg \
  "build/Build/Products/Release/Claude Watchdog.app"

# DMG also needs notarization
xcrun notarytool submit Claude-Watchdog-1.0.0-Universal.dmg \
  --keychain-profile "notarize" --wait
xcrun stapler staple Claude-Watchdog-1.0.0-Universal.dmg
```

## Widget Development

### Widget Structure

Widget reads from `SharedUsageStore.shared.load()` in `TimelineProvider.placeholder()` and `getTimeline()`. No network calls — widget is purely a view layer.

**Timeline Policy:**
```swift
let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
return Timeline(entries: [entry], policy: .after(nextUpdate))
```

Widget refreshes every 5 minutes, or when main app calls `WidgetCenter.shared.reloadAllTimelines()`.

### Testing Widget Changes

After modifying widget code:
1. Build with `xcodebuild`
2. Install to `/Applications` (see "Install to /Applications" above)
3. Add widget via macOS "Edit Widgets" UI
4. Widget won't hot-reload — must kill and relaunch app

Alternatively, run from Xcode and select "My Mac (Designed for iPad)" to debug widget extension.

## Modifying `project.yml`

After any change to `project.yml`:
```bash
xcodegen generate
```

**Common modifications:**
- Adding new source files/groups: Update `targets.ClaudeWatchdog.sources`
- Changing bundle identifier: Update `PRODUCT_BUNDLE_IDENTIFIER`
- Adding frameworks: Add to `targets.ClaudeWatchdog.dependencies`
- Modifying entitlements: Edit `entitlements.properties`

**Never commit `*.xcodeproj/`** — it's gitignored and regenerated from `project.yml`.

## Claude API Integration

**Endpoint:** `GET https://api.anthropic.com/api/oauth/usage`

**Response Format:**
```json
{
  "five_hour": {
    "utilization": 42.5,
    "resets_at": "2025-02-04T10:30:00.000Z"
  },
  "seven_day": {
    "utilization": 65.0,
    "resets_at": "2025-02-08T00:00:00.000Z"
  },
  "seven_day_opus": { "utilization": 20.0 },
  "seven_day_sonnet": { "utilization": 80.0 }
}
```

**Authentication:**
- OAuth token stored by Claude Code CLI in Keychain
- Service: `"Claude Code-credentials"`
- Account: current macOS username
- Format: JSON with `claudeAiOauth.accessToken` and `claudeAiOauth.expiresAt`

**Rate Limiting:**
- API returns HTTP 429 if rate limited
- App shows error in popover, retries on next refresh cycle

## Debugging

### Keychain Access Issues

If `CredentialService` throws `.notFound`:
1. Verify Claude Code is installed: `which claude`
2. Check Claude Code is logged in: `claude auth status`
3. Manually verify Keychain entry:
   ```bash
   security find-generic-password -s "Claude Code-credentials" -a "$USER" -w
   ```

### Widget Not Appearing

1. Check widget is embedded in app:
   ```bash
   ls "/Applications/Claude Watchdog.app/Contents/PlugIns/"
   # Should show: ClaudeWatchdogWidgetExtension.appex
   ```

2. Check widget registration:
   ```bash
   pluginkit -m -i com.dante-labs.ClaudeWatchdog.Widget
   # Should show version if registered
   ```

3. Check `chronod` logs:
   ```bash
   log show --predicate 'process == "chronod"' --last 1m | grep -i widget
   ```

4. If widget has wrong entitlements (sandbox OFF), `chronod` will reject it with "Ignoring restricted or unknown extension"

### Menu Bar Icon Not Updating

- Check `MenuBarManager.refresh()` is being called (set breakpoint or add print)
- Verify `AppSettings.shared.refreshInterval` timer is running
- Check network connectivity to `api.anthropic.com`
- Look for errors in `MenuBarManager.error` property

## Testing Requirements

### Manual Testing Checklist

Before release:
- [ ] Menu bar icon displays correct percentage (all 3 styles)
- [ ] Popover shows session/weekly/Opus/Sonnet usage
- [ ] Settings persist across app restarts (UserDefaults)
- [ ] Notifications fire at 75%, 90%, 95% thresholds
- [ ] "Launch at Login" toggle works (check System Settings > General > Login Items)
- [ ] Widget appears in Widget Gallery
- [ ] Widget updates when main app refreshes
- [ ] Widget shows "No Data" state when app not running
- [ ] Credential errors show helpful message in popover
- [ ] API errors (401, 429, 500) are handled gracefully
- [ ] Quit button terminates app

### Testing Universal Binary

```bash
# Check architectures
lipo -info "build/Build/Products/Release/Claude Watchdog.app/Contents/MacOS/Claude Watchdog"
# Should show: Architectures in the fat file: x86_64 arm64

# Test on Intel Mac (via Rosetta on Apple Silicon)
arch -x86_64 "/Applications/Claude Watchdog.app/Contents/MacOS/Claude Watchdog"
```

## Version Bumping

Update version in `project.yml`:
```yaml
targets:
  ClaudeWatchdog:
    settings:
      base:
        MARKETING_VERSION: "1.1.0"  # User-visible version
        CURRENT_PROJECT_VERSION: "2"  # Build number
```

Then regenerate:
```bash
xcodegen generate
```

Version appears in:
- `Info.plist` (auto-generated)
- Popover footer: "v1.1.0"
- DMG filename: `Claude-Watchdog-1.1.0-Universal.dmg`
