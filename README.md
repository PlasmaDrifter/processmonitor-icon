# Process Monitor Widget

[![KDE Plasma 6](https://img.shields.io/badge/KDE_Plasma-6.0+-3152A0?style=for-the-badge&logo=kde&logoColor=white)](https://kde.org/plasma-desktop/)
[![QML](https://img.shields.io/badge/UI-QML%2FQt6-41CD52?style=for-the-badge&logo=qt&logoColor=white)](https://doc.qt.io/qt-6/qtqml-index.html)
[![Category](https://img.shields.io/badge/Process%20Monitor-AF52DE?style=for-the-badge&logo=linux&logoColor=white)](https://github.com/PlasmaDrifter)
[![License](https://img.shields.io/badge/License-GPLv2-blue.svg?style=for-the-badge)](LICENSE)

A lightweight system activity indicator and top process resource monitor for KDE Plasma 6.

---

## Previews

![Process Monitor Widget Preview](desktop-2.png)

![Process Monitor Widget Preview](processor.png)

---

## Features

- **Top**: CPU and Memory consuming process tracking
- **Quick**: status indicator with dynamic color thresholds
- **System**: monitor launch shortcut integration
- **Low**: resource overhead

## Requirements

- **Environment**: KDE Plasma 6.0 or higher
- **Framework**: Qt6 QML / Plasma Applet API

## Installation

### Option 1: Git Clone (Recommended)
```bash
mkdir -p ~/.local/share/plasma/plasmoids/
git clone https://github.com/PlasmaDrifter/processmonitor-icon.git ~/.local/share/plasma/plasmoids/local.widget.processmonitor-icon
```

### Option 2: Plasma Package Installer
```bash
kpackagetool6 -i ~/.local/share/plasma/plasmoids/local.widget.processmonitor-icon
```

Then right-click your desktop or panel $\rightarrow$ **Add Widgets...** and search for the widget name.

## Credits & License

- **Author / Maintainer**: PlasmaDrifter
- **License**: Licensed under the [GPLv2](LICENSE).
