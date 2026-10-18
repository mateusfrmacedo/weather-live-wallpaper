# Weather Live Wallpaper
<img width="1292" height="857" alt="Captura de Tela 2026-10-18 às 19 33 09" src="https://github.com/user-attachments/assets/c366d8bc-5e86-424d-9cf3-e06ecc281f72" />


An animated macOS wallpaper that follows the weather in your city, using the built-in Weather app’s renderer. Weather data comes from [Open-Meteo](https://open-meteo.com/).

## Download

[Download the latest release](https://github.com/mateusfrmacedo/weather-live-wallpaper/releases/latest).

Open the `.dmg`, drag **Weather Wallpaper.app** to **Applications**, then launch it and choose a city. Press **⌘⇧P** to bring back the controls.

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
