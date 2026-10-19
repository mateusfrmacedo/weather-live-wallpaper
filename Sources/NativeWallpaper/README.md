# Native wallpaper prototype

This is a separate, opt-in app: `Build/Weather Wallpaper Native.app`, with bundle identifier `local.mateus.WeatherWallpaper.NativePrototype`. The original app identity and preferences are preserved. Both apps share the compact native settings layout, with system Liquid Glass action buttons on supported macOS versions.

Build with `Scripts/build-native-prototype.sh`. Run the app, wait for scene preparation, then choose **Weather Wallpaper · Protótipo** in System Settings → Wallpaper. Choose the same entry as the screen saver. Keep the companion app running to receive weather updates; the extension retains its last published scene if the companion quits or the network is unavailable.

## Playback settings

In the companion app's **Animação** settings, choose **Sempre animado** for the original real-time desktop renderer or **Ao bloquear** for a static desktop with native lock-screen/screen-saver playback. The selection persists across launches. Continuous mode exposes quality and pause controls; the native extension still receives updated weather recordings. In **Ao bloquear** mode, select the native wallpaper in System Settings using **Ajustes de Papel de Parede…**.

Run `Scripts/test-native-modes.sh` after building to verify switching during preparation, persisted selection, pause/resume and stopping the desktop renderer. The test uses an independent application identity and does not publish a replacement weather recording.

## Behaviour (Ao bloquear)

- Lock screen / screen saver: loop an 8-second recording of Apple's WeatherUI scene.
- Unlock: reduce playback speed over 2.5 seconds, then keep the last displayed frame. No recurring frame decoding on the static desktop.
- Listen to session lock/unlock and screen saver notifications as well as WallpaperAgent requests. A session query recovers missed lock notifications. Partial/wrapped agent updates preserve omitted playback and geometry fields instead of resetting them to desktop defaults.
- New weather: prepare a complete replacement movie and poster before atomically publishing `current.json`. The extension checks for updates every five seconds and dissolves to the new scene over two seconds without restarting desktop playback.
- Weather requests retain the app's ten-minute cadence. Temperature alone does not trigger a new scene. A change of condition, city or manual time does. Changes in solar elevation, cloud coverage or wind are coalesced for at least five minutes. Twilight uses a smaller solar threshold; otherwise refresh at least every thirty minutes for celestial positions. Failed requests keep the last scene.

## Implementation and limits

WeatherUI is Catalyst-only, so the native extension cannot load it directly. `PrototypeHost.m` reuses the existing controller and render configuration. `SceneExporter.m` copies only the app's own Metal texture through its rendering command queue and composites the gradient/mask. It needs no screen-recording permission. Recording is bounded to 1920 pixels wide, at 24 fps. A per-user folder, `/Users/Shared/WeatherWallpaper/<uid>/`, stores scene generations; the extension has read-only access to this folder. The folder is mode 0700 and the extension has no network entitlement. Do not put other files there.

The recording is a prototype: its eight-second loop can have a visible seam, the preview's aspect ratio is used for all displays with aspect-fill cropping, and it is not a 4K export. Hidden-window export is covered by the automated test; energy use during scene preparation still needs profiling. This uses undocumented WallpaperExtensionKit / WeatherUI / VFX APIs tied to macOS 27. The extension has read-only access to the stable shared parent; each user’s scenes remain in a private UID folder. `Scripts/build-native-prototype.sh --release` builds the combined app with the original application identity for upgrades; `Scripts/package.sh` packages it with ad hoc signing.

Run `Scripts/test-native-prototype.sh` for scene publication, weather update policy, real framework ABI checks, actual video decoding, unlock deceleration, static weather replacement and sleep/resume. The macOS wallpaper and screen saver pickers have also been checked, including selecting the native wallpaper and verifying its rendered system preview. These tests exercise the renderer and native session without locking the user's computer. Physical lock/unlock transitions and multi-display behaviour require a manual system test.

## Attribution

`CodableShims.swift`, `SettingsProvider.swift`, `WallpaperConfiguration.swift`, `WallpaperHandler+Stubs.swift` and `WallpaperPrivate.h` are adapted from [Aerial](https://github.com/AerialScreensaver/Aerial), revision `03fe7bc01009607b8a8e1af68389413e096d802d`. Snapshot encoding is also based on that implementation. The MIT license is preserved in `Aerial-LICENSE`. The remaining prototype code connects this application's weather renderer to that protocol.
