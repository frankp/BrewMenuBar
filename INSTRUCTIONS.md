# BrewMenuBar Instructions

This document provides instructions on how the BrewMenuBar application works, how to build it, and how to run it.

## Project Structure

The main files for this project are located in the `BrewMenuBar` directory.

- `BrewMenuBarApp.swift`: The main entry point for the SwiftUI application.
- `AppDelegate.swift`: This is the core of the application. It manages the application lifecycle, status bar item, menu, and handles all the application logic.
- `BrewService.swift`: This service is responsible for interacting with the `brew` command-line tool to check for and install updates.
- `PreferencesView.swift`: This SwiftUI view provides the user interface for the application's preferences.
- `Info.plist`: The application's information property list file.
- `Assets.xcassets`: Contains the application's icons.

## Building the Application

A shell script `build.sh` is provided to build the application. To build the app, run the following command in your terminal:

```bash
./build.sh
```

This script will compile the Swift source files and create an application bundle named `BrewMenuBar.app`.

## Running the Application

Once the application has been built, you can run it with the following command:

```bash
open ./BrewMenuBar.app
```

The application will run in the menu bar.

## How it Works

The application uses an `AppDelegate` to manage its functionality.

### Status Bar Icon

The status bar icon is created in the `applicationDidFinishLaunching` method of the `AppDelegate`. The icon is a system symbol from SF Symbols.

The icon changes based on the application's state:

- `mug`: The default state, indicating no updates are available.
- `mug.fill`: Indicates that there are updates available.
- `arrow.2.circlepath`: Indicates that the application is currently checking for or installing updates.

### Updating

The `updateMenu` method in `AppDelegate` is called periodically by a `Timer`. This method does the following:

1.  Changes the status bar icon to the updating indicator (`arrow.2.circlepath`).
2.  Calls the `brewService.checkForUpdates` method to get a list of outdated packages.
3.  In the completion handler, it builds a new menu with the list of outdated packages.
4.  It updates the status bar icon to `mug.fill` if there are updates, or `mug` if there are no updates.

The `updateAll` and `updatePackage` methods handle updating all packages or a single package, respectively. They also set the updating indicator icon while the update is in progress.

### Preferences

The preferences window is opened by the `openPreferences` method in `AppDelegate`. The UI for the preferences is defined in `PreferencesView.swift`. The "Preferences" menu item has a `gearshape` icon.
