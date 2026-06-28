# AI Pairing Log: Vibe Coded with Google Gemini

This document records the engineering journey, architectural discoveries, and solutions implemented by **Google Gemini** during this pair programming session.

---

## 🛠️ The Mission
Implement a lightweight right-click **Force Quit** (or **Force Quit All** for grouped windows) option directly within the KDE Plasma 6 taskbar context menu.

---

## 💡 The Journey & Discoveries

### Phase 1: Local Shadows & Plasma 6 Constraints
Initially, we attempted to shadow the default system `org.kde.plasma.taskmanager` widget path by placing a patched local copy of `ContextMenu.qml` in `~/.local/share/plasma/plasmoids/org.kde.plasma.taskmanager`.
*   **The Discovery**: Plasma 6 compiles core widgets into binary plugins (`org.kde.plasma.taskmanager.so`). KPackage loads their QML assets directly from pre-compiled Qt Resources (`qrc:/qt/qml/plasma/applet/org/kde/plasma/taskmanager/...`), completely bypassing local filesystem shadowing directories. This resulted in the widget failing to load and throwing a **"Sorry! There was an error loading metadata."** screen.
*   **The Pivot**: Instead of overriding the core widget ID, we created two unique, user-space widgets:
    - **Icons-Only Task Manager (Force Quit)** (`org.kde.plasma.icontasks.custom`)
    - **Task Manager (Force Quit)** (`org.kde.plasma.taskmanager.custom`)

### Phase 2: Schema Configuration Issues (`main.xml`)
When we deployed the custom widgets, we noticed that running and pinned application icons were completely missing from the taskbar.
*   **The Discovery**: The system taskbar relies on KConfigXT to read user configurations (such as sorting strategy, grouping settings, and launcher lists). Because our custom directories lacked the default `main.xml` configuration schema under `contents/config/main.xml`, all values initialized to empty or null, breaking the widget rendering.
*   **The Fix**: We retrieved the default `main.xml` configuration schema from upstream KDE sources and deployed it within our custom packages.

### Phase 3: Layout & Spacing Engine Compatibility
Even after loading the icons, the custom taskbars had incorrect margins, offsets, and behavior configurations compared to the original Icons-Only taskbar.
*   **The Discovery**: The underlying QML and Javascript files contained several hardcoded strings checking for the exact plugin ID `org.kde.plasma.icontasks` (e.g. `Plasmoid.pluginName === "org.kde.plasma.icontasks"`). Because our widget name was `org.kde.plasma.icontasks.custom`, all styling, icon spacing, and behavior visibility rules were defaulting to standard taskbar modes.
*   **The Fix**: We dynamically updated all exact comparisons to check whether `pluginName` contains `"icontasks"` (using `indexOf` checks or `tasks.iconsOnly`).

### Phase 4: Folder Restructuring & Clean Up
To keep the repository clean and maintainable, we reorganized the directory tree:
*   Only the primary entry script ([main.qml](file:///run/media/anthony/Roommate/Projects/kde-plasma-right-click-force-quit/src/qml/main.qml)) stays directly under `src/qml/`.
*   All other auxiliary QML components, config panels, and Javascript helper modules reside inside a dedicated subdirectory ([kde-taskbar](file:///run/media/anthony/Roommate/Projects/kde-plasma-right-click-force-quit/src/qml/kde-taskbar)).
*   We resolved all import paths by importing `"kde-taskbar"` inside `main.qml` and redirecting `Qt.createComponent` declarations.

### Phase 5: Future-Proofing (Auto-Updater & Patcher)
To ensure the widgets stay up to date when the user upgrades KDE Plasma:
*   We created [update-project-kde-taskbar.sh](file:///run/media/anthony/Roommate/Projects/kde-plasma-right-click-force-quit/update-project-kde-taskbar.sh). It automatically detects the active `plasmashell` version, clones the exact release files from upstream KDE, structures them in our custom layout, and applies a unified patch file.
*   We generated the patch under [patches/force-quit.patch](file:///run/media/anthony/Roommate/Projects/kde-plasma-right-click-force-quit/patches/force-quit.patch) to carry over all Force Quit QML injections and name detections cleanly.

### Phase 6: Dynamic QML Module Dependency (`plasma.applet.org.kde.plasma.taskmanager`)
After refactoring, the widget crashed on startup with a QML load error: `module "plasma.applet.org.kde.plasma.taskmanager" is not installed`.
*   **The Discovery**: The C++ plugin `/usr/lib/qt6/plugins/plasma/applets/org.kde.plasma.taskmanager.so` is responsible for registering the `plasma.applet.org.kde.plasma.taskmanager` QML module. Because our custom applets had unique IDs, Plasmashell loaded them as QML-only widgets and did not load the C++ plugin library, leading to import failures if no default task manager was running on the panel.
*   **The Fix**: We added `"X-Plasma-RootPath": "org.kde.plasma.taskmanager"` to our metadata JSON files. This links the custom widgets to the system's C++ taskmanager plugin so that the QML module is registered, while KPackage still resolves and loads the modified QML files from our custom user directories.

---

## 📄 Key Technologies Used
*   **QML & JavaScript**: Used to extend the taskbar UI and trigger actions.
*   **Plasma5Support (executable engine)**: Invoked to run `kill -9` commands asynchronously directly from the UI thread without blocking the desktop environment.
*   **Bash & Diff/Patch Utility**: Leveraged to automate clean deployments, system restarts, and automated patching of upstream files.
