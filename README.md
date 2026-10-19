# Weather Live Wallpaper
<img width="1292" height="857" alt="Captura de Tela 2026-10-18 às 19 33 09" src="https://github.com/user-attachments/assets/c366d8bc-5e86-424d-9cf3-e06ecc281f72" />


An animated macOS wallpaper that follows the weather in your city, using the built-in Weather app’s renderer. Weather data comes from [Open-Meteo](https://open-meteo.com/).

## Download

[Download the latest release](https://github.com/mateusfrmacedo/weather-live-wallpaper/releases/latest).

Open the `.dmg`, drag **Weather Wallpaper.app** to **Applications**, then launch it and choose a city or a weather effect. In **Animação**, choose **Sempre animado** or **Ao bloquear**. For the native lock-screen mode, open **Ajustes de Papel de Parede…** and select **Weather Wallpaper** as the wallpaper and screen saver. Keep the app running for weather updates. Press **⌘⇧P** to bring back the controls.

The app is not notarized. If macOS blocks it, go to **System Settings → Privacy & Security → Open Anyway** after trying to open it.

## Requirements

Apple Silicon and macOS 27, with the Weather app installed. Tested on macOS 27.0.1 (26A434). Uses private system APIs, so compatibility may break with macOS updates.

## Build from source

Requires Xcode 27.1.

```sh
git clone https://github.com/mateusfrmacedo/weather-live-wallpaper.git
cd weather-live-wallpaper
./Scripts/install.sh
```

Installs to `~/Applications/Weather Wallpaper.app`.

## Native lock-screen wallpaper prototype

An optional companion app can animate the lock screen and screen saver while keeping the desktop static. Its compact native settings also let you switch back to continuous desktop animation, with Liquid Glass action buttons on supported systems.

```sh
./Scripts/build-native-prototype.sh
open "Build/Weather Wallpaper Native.app"
```

See [native wallpaper setup, tests and limitations](Sources/NativeWallpaper/README.md). The downloadable release includes both playback modes in **Weather Wallpaper.app**. The command above builds a separate development app; `Scripts/package.sh` builds the distributable DMG and ZIP.
