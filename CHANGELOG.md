# Changelog

All notable changes to RememberMyWindows will be documented here.

## [v15.7] — 2026-10-27

### 🪟 "Per-App Layout Memory & Smarter Window Restores"

#### 🧩 Per-App, Per-Display Defaults
- **Remembered layouts** — Auto Layout now keeps a persistent default for each app on each display and applies it when the app opens while Auto Layout is active.
- **Seamless upgrade** — Existing captures seed these defaults automatically, carrying forward layouts already recorded.

#### 🎯 More Reliable Window Identity
- **Better restore matching** — Improved window identity matching and full-screen Space handling make restores more reliable and prevent returning windows from being misread as newly opened.

## [v15.6.1] — 2026-10-26

### 🎯 "More Accurate Auto Layout Change Indicators"

#### 🪟 Newly Added Windows
- **Reliable addition detection** — Auto Layout now recognizes a newly opened window even when another window closes during the same capture, so the green addition indicator identifies the affected app correctly.

## [v15.6] — 2026-10-26

### 🛡️ "Space-Aware Captures & Polished Details — The Stability Edition"

#### 🖥️ Fullscreen Spaces & Multi-Space Intelligence
- **Space-Aware Auto Layout** — Auto Layout now detects when you are focused on dedicated full-screen Spaces (such as Safari in macOS Full Screen mode) or non-desktop spaces, and gracefully pauses capturing to prevent broken, empty, or distorted window arrangements from entering your timeline.
- **Clean Desktop Return** — As soon as you swipe back to your main desktop space, RememberMyWindows automatically captures a clean, accurate snapshot of your restored desktop layout.
- **Queued Background Launches** — Applications launched while you are immersed in a full-screen app on another space are queued and captured with the green `+` indicator immediately upon returning to the desktop.
- **Auxiliary Strip Filtering** — Safari's auto-hiding top navigation/tab bar window is filtered out at capture time, ensuring hovering the top edge in full-screen never triggers spurious captures or blank thumbnail cards.
- **Reliable Full-Screen Thumbnails** — Full-screen app windows are guaranteed to render clearly with their authentic green accents in arrangement previews and hero cards.

#### ✨ Dynamic Notch Welcome Pill
- **Expansive Welcome Script** — The cursive "hello" drawing now fills the available height up to the top notch boundary during the initial stroke animation.
- **Fluid Subtitle Reveal** — When the subtitle reveals, the signature greeting smoothly transitions down to compact size with spring physics.

#### 🎨 Window Arrangement & UI Polish
- **Full Animated Return** — Tapping "Return to Latest" in the history view re-animates all layout windows rather than just the triggering ones.
- **Auto-Compacting Location Badge** — The location card gracefully hides its text label and keeps only the compact map pin when horizontal space is constrained.
- **Visual & Alignment Polish** — Refined spacing after the loading tracking indicator in the toolbar and enhanced status icon visibility.

## [v15.5] — 2026-10-18

### 🚀 "Smooth Springs & Polished Views — The Visual Edition"

#### 🧭 Menu Bar Recent Auto Captures
- **Live captures at your fingertips** — Access and browse your recent Auto Layout captures directly from the menu bar dropdown without opening the main window.
- **Color-coded change badges** — Every capture instantly tells its story with colored status badges: green `+N` for added windows, blue resize arrows for window rearrangements, and orange clock icons for history baselines.
- **Submenu preview cards** — Hover any capture in the menu to inspect a live arrangement preview card and restore it instantly with one click.

#### 🟢 Native Fullscreen Styling & Intelligence
- **Authentic full-screen thumbnails** — Full-screen applications now render with macOS-authentic green accents, featuring the centered native diagonal glyph across arrangement previews, menubar submenus, and session grids.
- **No more movie interruptions** — Auto Layout detects full-screen apps and quietly suppresses transient captures while you are watching movies, gaming, or presenting.

#### 🎯 Geometry-Smart Deduplication
- **Zero duplicate spam** — Merely clicking between windows or shuffling focus order (z-index) no longer floods your history with duplicate captures. Auto Layout now checks true window geometry with sub-pixel tolerance before recording.
- **Cleaner timeline** — Only actual changes (windows opened, closed, moved, or resized) earn a spot in your Auto Layout history.

#### 🎨 Visual Timeline & Badges
- **Change indicators at a glance** — Capture cards in the hero timeline now feature color-coded indicators: Green badge for added windows (+N), Blue badge for moved or resized windows, and Orange badge for baseline history.
- **App icons tell the story** — Each capture card displays mini icons of the exact applications involved in that change.

#### 🪄 Fluid Accordion History Banner
- **Smooth spring reveal** — Selecting an earlier capture expands an elegant "Viewing Earlier Capture" banner with fluid spring physics, gracefully sliding down and pushing content down.
- **Symmetric return** — Tapping "Return to Latest" collapses the banner vertically back into zero height with smooth opacity fade.
- **Visual symphony highlight** — Hovering window lists activates a calm, synchronized highlight sweep across previews.

#### ✨ A Warmer Welcome in the Notch
- **Polished typography & proportions** — Refined script proportions and subtitle spacing ensure the Welcome Notch Pill looks crisp and balanced under every Mac notch and dynamic display.
- **Theme-aware ambient glow** — The pill's subtle glow now dynamically matches your selected theme accent color.

#### 🛠️ Architecture & Under-the-Hood
- **Standalone What's New for existing users** — Upgrades now greet returning users with a standalone changelog window, completely removed from first-run onboarding and permissions screens.
- **Cleaned first-run onboarding** — New users get a distraction-free 2-step setup (Setup → Guide) without release-note clutter.
- **Xcode 27 & Swift 6 compatibility** — Build fixes, explicit strong-capture closures, and strict type-checks keep the engine humming smoothly.

## [v15.0] — 2026-10-07

### 🛋️ "Make Yourself at Home — Your Windows Already Did"

#### 🛠️ Restoration & Spaces
- **Minimized windows wait their turn** — Minimized and hidden windows keep their own saved match until they are shown again, with retries when they are unminimized. - By Jonathan M. Hollin
- **More reliable window matching** — Captured window IDs are matched first, preventing similar or untitled windows from being swapped. Thanks @PerpetualBeta
- **Spaces stay in sync** — Restores no longer activate apps parked on another Space, and live layouts capture active-Space changes.

#### 🎯 Auto Layout & App Controls
- **Choose the app that comes forward** — Pin a preferred foreground app for saved layouts and individual Auto Layout display setups.
- **Fixed Command+Shift+R controls** — Configure the trigger per app; Auto Layout restores window geometry without sending a shortcut to whichever app happens to be active.

#### ✨ A Warmer Welcome in the Notch
- **Welcome Notch Pill** — An optional animated greeting appears on eligible full restores: the first eligible restore after launch, for a layout outside the two most recent restores, or after eight hours. Its sound is controlled independently.
- **Sound conflicts are actionable** — “Go to…” jumps to the conflicting notification setting, scrolls it into view, and briefly highlights and flips the card

#### 🎨 Main Window, Settings & Tour
- **List or grid** — Switch the app cards between list and grid views, with quick per-window actions and clearer foreground-app controls.
- **Personalized controls** — Choose menu bar icon styles, tune notification sounds, and refine restore behavior.
- **Settings window follows the app** — Closing the main window also closes the separate Settings window.
- **A more useful tour** — The guide adds back/forward arrows, an editable desktop shortcut, and refreshed Quick Key and Settings previews.

## [v14.8] — 2026-09-27

### 🪄 "Snap, Sleek, Settled"

#### 🖥️ Onboarding Glow-Up
- **MacBook Pro 14″ M4 Mockup** — Completely redrawn as a native SwiftUI front-elevation vector: accurate `118×78 pt` Liquid Retina XDR lid, razor-thin Space Black bezels, edge-to-edge black glass, and a precise aluminium unibody base. No more generic grey rectangles.
- **Lid Open & Close Animation** — A physics-spring open (rotates from closed → upright in 3D) and a smooth forward-fold close mirror how a real MacBook wakes and sleeps. Opacity fades sync with the lid angle for a natural sleep/wake glow.
- **Wider Splash-Screen Menu Bars** — All three onboarding illustration menu bars (`Save`, `Live`, `MenuBar`) now span the full card width at `356 pt`, eliminating the stubby clipped look.

#### 🎨 Interface & Theme Polish
- **Smarter Badge Colors** — "Active", "Full", "Foreground", and session-type badges in the layouts list now use `.primary` foreground, adapting cleanly to any accent color and Dark/Light mode instead of hard-coded greens and indigos.
- **App Name Never Truncated** — Window rows now give the app name `layoutPriority(1)` with `.lineLimit(1)` so long titles no longer crowd the action buttons.
- **Row Controls on Demand** — The ⌘⇧R, Bring-to-Front, and Delete buttons in window rows are removed from layout entirely when inactive (not just hidden), giving the app name full width. They fade back with `.snappy` animation on hover.
- **Theme-Aware Bring-to-Front** — The Bring-to-Front circle uses the current `ThemeColor` accent and picks a correct foreground via `onAccentColor(for:)` — Galaxy always uses white text; bright accents like yellow always use black.

#### 🏗️ Architecture
- **`minimalVisualAnimations` Preference** — New per-app motion preference (separate from system Reduce Motion) that strips non-essential animations globally. Onboarding and the Feature Tour opt back in via `.fullVisualAnimations()`.
- **`MainWindowSymbolAnimation` Respects Motion Pref** — SF Symbol effects (wiggle, flip, breathe) are skipped when the minimal-animation preference is active.
- **`LayoutPreviewView` Sequential Window Reveal** — Opt-in `animateWindowReveal` mode staggers windows into their saved positions one-by-one on appear; falls back to a static layout when minimal animations are on.
- **`onAccentColor(for:)` on `ThemeColor`** — New helper that returns a legible foreground (`.black` or `.white`) for content rendered directly on the accent swatch for each theme.
- **`AppThemeColorSchemeModifier`** — Forces `.dark` color scheme for Galaxy theme surfaces only, keeping other themes faithful to the system appearance.

#### 🐛 Bug Fixes (from remote)
- **Notch Panel Memory Leak** — `NotchNotificationWindow` now releases its `contentView` on close, preventing the `dotPulse` animation from keeping a strong reference cycle alive.
- **Post-Unlock Restore (Once, Per-Display)** — Window restore after screen unlock now fires exactly once and only for displays whose frames have actually settled, using `displayChangeGeneration` to abandon stale restore attempts.

#### ⚙️ Build & App Lifecycle
- **Arrow Cursor Override on Launch** — App delegate suppresses the beach-ball cursor during the startup window-server scan with a balanced `NSCursor.arrow.push/pop`.
- **Smarter "X ago" Formatting** — The relative-time formatter now uses `AutoLayoutHeroCard.dayDisplayThreshold` as the hour/day crossover boundary instead of a magic `86_400` constant.
- **Settings Window Taller** — Settings sheet height bumped `620 → 650 pt` to accommodate the expanded Feature Tour section.

---

## [v14.6] — 2026-09-14

### 🛠️ "Polish & Reliability"

#### 🐛 Bug Fixes
- **No More Duplicate Apps**: Saved Sessions and the menu-bar app list now remove duplicate app entries without altering the underlying saved window records.
- **Safer Automatic Restores**: Auto Layout and Saved Sessions no longer send an unintended frontmost-app command while restoring windows.
- **Smoother 3D Peeling**: Corrected the center peel animation timing and final-window sequencing so the preview transitions feel continuous and predictable.
- **Clearer Disabled Settings**: Disabled notification event cards and settings sections now use consistent rounded overlays and styling, making their inactive state easier to understand.

#### ✨ Interface Polish
- Added interactive hover, selection, and empty-state animations to SF Symbols throughout the main window.
- Refined preview cards with larger app icons, clearer title-bar details, inline app labels, and larger auto-save previews.

## [v14.5] — 2026-09-08

### 🔮 "No Pane, All Gain: Polish Pass Deluxe"

#### 🎛️ 3D Preview Overhaul
- **Wider Center Zone**: Expanded the center interaction zone from [0.30, 0.70] to [0.25, 0.75] for more generous cursor tracking.
- **Dynamic Pitch Flattening**: 3D preview pitch now smoothly flattens to 0° when the cursor enters the center zone, making the layout lie flush against the board.
- **Center-Zone Layer Collapse**: Window layer spacing collapses to zero in the center zone so peeled cards sit flat, then fans back out in the outer zones.
- **Single-Screen Zoom-Out**: Layouts on a single display now get extra breathing room with an automatic scale reduction so peeled windows don't clip.
- **Clip Shape Fix**: Added `clipShape(RoundedRectangle)` before and after the liquid glass modifier to prevent content from bleeding past card corners.

#### 🧩 Smarter Session & Context Awareness
- **Menu → Window Intelligence**: Opening the main window from the menu bar now preserves the correct saved session and highlights the app that was frontmost before the menu took focus.
- **Scroll-to-App Fix**: Added `onChange(of: selectedSnapshotKey)` so the detail view reliably scrolls to the current app card even when the session changes.
- **Auto Layout Context**: When Auto Layout is active, opening the main window clears the saved-session context cleanly instead of showing a stale session.

#### ⚠️ Display Warnings Refactor
- **Unified Warning Card**: Extracted a new `SavedSessionDisplayWarnings` view that combines physical display mismatch and missing screens into a single compact, divider-separated card.

#### 🎨 Settings & UI Polish
- **Inline Disabled State**: Replaced the custom `.autoLayoutDisabled()` modifier with standard `.disabled()`, `.opacity()`, and `.grayscale()` for clearer, more composable toggle-card behavior.
- **Hebrew Localization**: Added translations for "Auto Layout Mode", its description tooltip, and "Enable Desktop Toggle first".

#### 🧹 Housekeeping
- **Removed `auto-layout-transition.gif`**: Cleaned up an unused GIF asset from README-assets.

---

## [v14.0] — 2026-09-05

### 💾 "Always In Place: Auto-Save Meets Multi-Space"

#### 🔄 Persistent Live Layout & Auto-Save Ring
- **Persistent Auto-Save (`autosave.json`)**: Live arrangements are now saved continuously and reliably across sessions without expiration, giving you an automated safety net for every monitor setup.
- **Auto Layout Hero Card**: A sleek hero card in LayoutsView gives you instant visibility and quick control over your live auto-saved layout.
- **Closed & Minimized App Awareness**: Intelligently ignores closed windows while tracking minimized apps and windows across all workspaces, so quit apps return right where you left them.
- **Diagnostic Log Mirroring**: Optional mirroring of real-time activity events to a persistent disk log for easier troubleshooting.

#### 🌌 WindowServer Spaces Intelligence
- **Deep Space Detection**: Dynamically queries macOS WindowServer private APIs via `dlsym` (`CGSCopySpacesForWindows`) to accurately distinguish live windows on other Spaces from stale/closed leftover windows.
- **Space-Deferred Restoration**: Windows located on inactive Spaces are gracefully held in queue and restored smoothly the moment you navigate to that Space.

#### 🔌 Unshakable Display Reconnects & Contested Window Recovery
- **Cable Settle Buffer**: Automatically debounces rapid multi-event display reconfigurations on monitor plug/unplug, waiting for the screen list to stabilize before applying restorations.
- **Contested Window Recovery**: Wins back stubborn windows from apps that try to fight the restore layout, using exponential retry backoff and gentle multi-display nudging.
- **Edge Overhang Preservation**: Preserves intentional window positioning that hangs slightly off screen edges on matching displays instead of clamping them prematurely.

#### 🔮 Dynamic Notch Fit & Physical Bezel Clearance
- **Physical Bezel Clearance**: Added a verified 6pt side clearance (`notchClearance` default) so notch notification borders clear the physical camera housing on MacBook Pro displays.
- **Dynamic Text Measurement**: Notch pill geometry now measures actual rendered title typography width rather than character counts for balanced margins.

#### ⚡ Concurrency Hardening & Modern Swift
- **Swift 6 Concurrency**: Resolved compiler warnings and concurrency boundary hops across timer blocks, notification observers, and off-actor calls for rock-solid stability.

#### 🔉 Polite Notification Acoustics (Auto: 20% Below System)
- **Auto Sound Level**: New per-channel "Auto: 20% below system" toggle for Notch and System notification sounds, locking notification gain to a calibrated 80% (-2 dB) of macOS master output.
- **Media-Friendly**: Ensures notifications never blare or startle you during music, videos, or calls while staying crisp and audible.
- **Smart Settings UI**: Automatically hides the manual slider when Auto is active while keeping the quick Test button readily available.

---

## [v13.4] — 2026-09-03

### 🚀 "Rise and Shine, Windows In Line"

#### 🔄 Convenient GitHub Updates
- **Automatic Update Checks**: Checks the latest public GitHub release a few seconds after the app starts, at most once per day, with a manual menu-bar action and a Settings toggle.
- **One-Click ZIP Updates**: Shows release notes, downloads `RememberMyWindows.zip`, validates the app bundle and version, then replaces and reopens the app.
- **Release Packaging**: GitHub releases now include the ZIP update package alongside the DMG. Ad-hoc builds may require macOS approval after updating.

#### 🔄 Automatic Full Layout Restore at Launch
- **First Scan, Full Restore**: Whenever RememberMyWindows launches—whether started manually by you or triggered at system login—it now automatically initiates a full layout restore as soon as the live layout tracking server finishes its initial window capture.
- **Login Settle Buffer**: Built-in 1.75-second settling delay ensures other login applications finishing their startup sequences have their windows captured and aligned precisely without racing.
- **Zero-Friction Reliability**: Works seamlessly with your active screen fingerprint, preserving the saved foreground app focus and firing the standard Notch overlay notification with window counts.

---

## [v13.3] — 2026-09-02

### 🪟 "The Multiverse of Multitasking"

#### 📺 The Multi-Window Miracle (Full & Single Restore)
- **Leave No Window Behind (Not Even Your 14th YouTube Tab)**: It turns out people open more than one browser window! Fixed a bug where opening 5 YouTube windows or multiple browser/app windows would only restore *one* lonely window while leaving the others wandering the desktop abyss.
- **Broadcast Stacking**: *Sorry Window #2, we swear we didn't mean to ghost you.* When you have more open windows than saved in your snapshot, we now broadcast the layout coordinates to all extra windows and stack them neatly at the saved position so you can slide them apart like a fresh deck of cards.
- **Lightning Verification**: Rewrote the WindowServer verification loop to check and correct each window directly via nonisolated Accessibility handles. Gone is the awkward 3.6-second stall where the app stared at Window 1 trying to fix Window 2.

#### 🎛️ Menu Bar Icon Cha-Cha Elimination
- **1-Pixel Shift Evicted**: Centered all SF Symbols and custom icons inside a fixed 18×18 point canvas. Clicking the status bar icon no longer causes a microscopic 1-pixel jump to the right when transitioning into the action state.

---

## [v13.2] — 2026-09-01

### 🔕 "When I Turn Off Notifications, I Mean Disappear"

#### 🔔 Master Notification Disappearing Act
- **Total Eclipse of the Settings**: When you switch off the master **Notifications** toggle, the app takes the hint and vaporizes the **Notification Sounds** toggle, **Sound Library**, and all channel navigation rows into thin air. No ghost toggles left behind!
- **Sound Library Jukebox**: Replaced the redundant "Default Sound" row with a new **Sound Library** browser right in the notification panel. Now you can spam-click *Vine Boom*, *Anime Wow*, and *Wilhelm Scream* to your heart's content without messing up individual event sounds.
- **Bilingual Euphoria**: English & Hebrew translations (`ספריית צלילים`) for all fresh sound library copy.

#### ⌨️ Configurable Desktop Hotkey & Stability
- **Carbon-Powered Shortcut**: Swapped the fickle event-tap for a rock-solid Carbon `RegisterEventHotKey`. Customize your Desktop Toggle hotkey to any key combination you like (defaulting to `⌃⌥D`).
- **No More Safari Drama**: Kept shortcuts from interfering with Safari or hanging silently when macOS gets grumpy.

#### 🔮 Notch Glow & Privacy Honesty
- **Persistent Notch Pulse**: Rebalanced the notch indicator halo and ripple geometry so the fallback glow stays silky-smooth and visible through the entire pulse cycle.
- **Transparent Privacy**: Clarified reverse-geocoding privacy disclosures.

---

## [v13.1] — 2026-09-01

### 🛠️ Fixes for Previous Release

#### 🎵 Audio & Meme Sounds
- **Acoustic Reverb & Echo Tail**: Re-rendered all 21 meme sound files with Apple Medium Hall reverb (35% wet mix) and spatial echo delay (20% feedback, 1.4s decay tail) baked into 192kbps AAC `.m4a` files.
- **Mario Power-Up Resampling Fix**: Fixed dynamic buffer allocation for 22,050 Hz source audio so the complete ascending power-up melody plays without being truncated.

#### 🪟 Smart Single App Restore
- **Silent "Already In Place" Banner**: Single app restore checks whether target windows are already in place before executing. If unmoved, it displays a quiet compact Notch banner saying `"Already In Place"` (`"כבר במקום"`) with **zero sound played**.
- **Quiet Mode Setting**: Added *"Quiet when already in place"* toggle in Settings under Notification Events, enabled by default with an option to restore standard notifications.

#### 🎨 Notification UI Redesign
- **Clean 2-Row Card Layout**: Redesigned Notification Events list into modern individual cards. Titles and descriptions now have full horizontal width, eliminating awkward text wrapping. Sound selector controls and sub-options are neatly indented on row 2.
- **Hebrew Localization**: Full bilingual translations for all new strings and settings.

---

## [v13.0] — 2026-09-01

### 🎶 "Wilhelm Screamed When He Saw How Fast It Starts Now"

#### 🚀 Performance
- **Instant launch, no more frozen beach ball**: App now shows the menu bar icon and main window immediately at startup. AX observer registration for all running apps is deferred to a cooperative background task instead of blocking the main thread.
- **150ms AX IPC timeout everywhere**: All Accessibility API calls now have a hard 150ms timeout (`AXUIElementSetMessagingTimeout`). If any app is slow or unresponsive, we move on instead of hanging for macOS's default 6-second wait — eliminating the `(Not Responding)` state seen in Activity Monitor on cold launches.
- **Safe AX element factory**: Centralised `WindowManager.createAXElement(for:)` helper ensures every AX handle is timeout-guarded across `WindowManager`, `DesktopToggleManager`, `CommandOverlayManager`, and `WebAppDetector`.

#### 🎵 Meme & Fun Sounds
- **21 new notification sounds** in a brand-new "Meme & Fun" category: Vine Boom, Bruh, OOF (Roblox), Windows Error, Emotional Damage, Wilhelm Scream, What The Dog Doin, Mario 1-Up / Power-Up / Jump / Pipe, Illuminati (X-Files), Directed by (Curb Your Enthusiasm), Huh? (Cat), Taco Bell Bong, Quack, Sheesh, Yeet, Anime Wow, Ta-Da, and more.
- **Sound picker redesign**: Stepper chevrons (‹ ›) + searchable dropdown menu + shuffle button for every notification sound slot in Settings. No more scrolling an infinite flat list.
- **Full Hebrew translations** for all new sounds and picker UI strings.

#### 🎯 Menu Bar Polish
- **App icon on the single-app action item**: The "Update 'App' position" / "Add 'App' to session" item now shows the frontmost app's real 16×16 icon instead of a generic SF Symbol.
- **Smarter "Open RememberMyWindows" title**: The app name is only appended (e.g. `Open RememberMyWindows (Antigravity IDE)`) when that app is actually saved in the current session — no more misleading labels when the frontmost app isn't tracked.
- **Window activation fix**: `showMainWindow()` now brings an existing window to front directly (`makeKeyAndOrderFront`) instead of routing through the LaunchServices URL dispatch, shaving off extra IPC latency on every open.

---

## [v12.0] — 2026-09-01

### 🎨✨ The "Lookin' Sharp & SF-licious" Menu Glow-Up

- **Iconic Visuals**: Top-level status menu actions now sport native SF Symbols (`macwindow.on.rectangle`, `arrow.counterclockwise`, `arrow.triangle.2.circlepath`, `plus`, `arrow.clockwise`, `square.stack`, `folder`, `power`) with pixel-perfect template rendering so your menu looks like a million bucks.
- **Context-Aware App Targeting**: The main menu entry now dynamically tells you which app is in focus (e.g. `Open RememberMyWindows (Finder)`) so you always know what you're tweaking in one glance.
- **Bilingual Polish**: Seamless English & Hebrew translations for all dynamic menu actions.
- **Slick Single-App Actions**: Crisp `+` icon when adding new apps to your saved layout, and refresh `⟳` when updating existing window coordinates.

---

## [v11.0] — 2026-08-31

### 🚀 The Open Source & Automation Release

- **GPLv3 Licensing**: Project is now fully open-source under the GNU General Public License v3.
- **Automated Cloud Releases**: Added GitHub Actions workflow to build, package DMG, and release automatically.
- **Cleaned Compiler Warnings**: Replaced deprecated `activateIgnoringOtherApps` and updated SwiftUI `.onChange` handlers.
- **Improved Packaging**: DMG packaging script now includes all sound assets and localized strings automatically.
- **Repository Structure**: Cleaned up build files and established standard project hierarchy.

---

## [v10.0] — 2026-08-30

- Look Ma, No Hands! automation and window management updates.
