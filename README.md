# Notch Buddy

Notch Buddy is a local-first macOS menu bar app that turns the display notch area into a lightweight “shelf” for quick actions: a drag-and-drop tray for files (including an AirDrop drop-zone) and a simple clipboard history.

## What’s in this repo

- A Swift Package Manager macOS app (no Xcode project required).
- Core managers for notch detection, file storage, clipboard monitoring, and battery status.
- A SwiftUI + AppKit overlay window that expands from the notch.

## Features

- **Notch overlay shelf**: A non-activating overlay that expands on hover.
- **File tray**: Drop files onto the notch to copy them into a local “Tray”.
- **AirDrop zone**: Drop files into the AirDrop side to send them via AirDrop.
- **Clipboard history**: Shows recent clipboard entries and lets you click to copy back.
- **Battery glance**: Shows current battery percentage/charging state in the shelf header.

## Requirements

- macOS 14+
- Works best on MacBook models with a notch; includes a simulated notch option for development/testing.

## How to run

### Option 1: Xcode

1. Open this folder in Xcode (or open `Package.swift`).
2. Select the `NotchBuddy` scheme.
3. Run (Cmd+R).

### Option 2: Terminal

```bash
cd mac-notch-buddy
swift run NotchBuddy
```

## Data & privacy

- Notch Buddy stores tray files in your user Application Support directory.
- There is no network/analytics code in this repository.
