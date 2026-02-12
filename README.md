# Brew Menu Bar

A macOS menu bar application for managing your [Homebrew](https://brew.sh/) packages. Built with SwiftUI and Swift.

> **Note:** This project was developed with the assistance of Gemini, an AI assistant from Google.

## Features

*   **Status Bar Icon:** Shows the current status of your Homebrew packages (up-to-date, updates available, checking/updating).
*   **Update Checking:** Automatically checks for updates in the background at configurable intervals.
*   **Package Management:**
    *   View a list of outdated packages.
    *   Update individual packages directly from the menu.
    *   Update all packages with a single click.
    *   Uninstall packages.
    *   Open package homepages.
*   **Preferences:**
    *   Configure the refresh interval (from 5 minutes to 24 hours).
    *   Option to launch the application at login.
*   **Modern & Robust:**
    *   Supports both Apple Silicon and Intel Macs.
    *   Uses modern macOS APIs (SMAppService) for login item management.
    *   Built with Swift Concurrency (async/await) for a responsive UI.

## Requirements

*   macOS 12.0 or later.
*   [Homebrew](https://brew.sh/) installed.

## Installation & Building

1.  **Clone the repository:**
    ```bash
    git clone <repository-url>
    cd BrewMenuBar
    ```

2.  **Build the application:**
    Run the included build script:
    ```bash
    ./build.sh
    ```

3.  **Run the application:**
    ```bash
    open ./BrewMenuBar.app
    ```

## Usage

*   **Status Icon:**
    *   Empty Mug: No updates available.
    *   Filled Mug: Updates are available.
    *   Rotating Arrows: Checking for updates or installing updates.
*   **Menu:** Click the status bar icon to see the menu.
    *   **Outdated Packages:** Lists packages that have updates.
        *   **Submenu:** Hover over a package to see "Update", "Uninstall", and "Home Page" options.
    *   **Update All:** Updates all outdated packages.
    *   **Refresh:** Manually check for updates.
    *   **Preferences:** Open the settings window.
    *   **Quit:** Exit the application.

## Troubleshooting

If you encounter issues, you can check the following:

*   Ensure Homebrew is correctly installed and `brew` is in your path (the app checks `/opt/homebrew/bin/brew` and `/usr/local/bin/brew`).
*   The application relies on local notifications to alert you of updates. Ensure notifications are allowed for "BrewMenuBar" in System Settings.

## License

[MIT License](LICENSE)
