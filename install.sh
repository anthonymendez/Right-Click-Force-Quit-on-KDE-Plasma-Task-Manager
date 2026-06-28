#!/usr/bin/env bash
set -euo pipefail

# Determine script and source directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || pwd)"
TEMP_DIR=""

if [ -d "$SCRIPT_DIR/src" ]; then
    SRC_DIR="$SCRIPT_DIR/src"
else
    echo "Not running from within the repository. Cloning from GitHub..."
    TEMP_DIR=$(mktemp -d)
    git clone --depth 1 https://github.com/anthonymendez/Right-Click-Force-Quit-on-KDE-Plasma-Task-Manager.git "$TEMP_DIR"
    SRC_DIR="$TEMP_DIR/src"
fi

# Target directories
BASE_TARGET_DIR="$HOME/.local/share/plasma/plasmoids"
SHARED_TARGET_DIR="$BASE_TARGET_DIR/org.kde.plasma.taskmanager"
ICON_TARGET_DIR="$BASE_TARGET_DIR/org.kde.plasma.icontasks.custom"
TASK_TARGET_DIR="$BASE_TARGET_DIR/org.kde.plasma.taskmanager.custom"

# Function to deploy a custom plasmoid
deploy_widgets() {
    # 1. Clean up and deploy the shared QML and config files to the root path directory.
    # Plasmashell requires this path to load the C++ backend plugin while overriding QML.
    echo "Deploying shared QML and configuration to $SHARED_TARGET_DIR..."
    rm -rf "$SHARED_TARGET_DIR"
    mkdir -p "$SHARED_TARGET_DIR/contents/ui"
    mkdir -p "$SHARED_TARGET_DIR/contents/config"
    cp -r "$SRC_DIR/qml/"* "$SHARED_TARGET_DIR/contents/ui/"
    cp "$SRC_DIR/main.xml" "$SHARED_TARGET_DIR/contents/config/main.xml"

    # 2. Deploy custom Icons-Only metadata
    echo "Deploying Icons-Only metadata to $ICON_TARGET_DIR..."
    rm -rf "$ICON_TARGET_DIR"
    mkdir -p "$ICON_TARGET_DIR"
    cp "$SRC_DIR/metadata-icontasks.json" "$ICON_TARGET_DIR/metadata.json"

    # 3. Deploy custom Task Manager metadata
    echo "Deploying Task Manager metadata to $TASK_TARGET_DIR..."
    rm -rf "$TASK_TARGET_DIR"
    mkdir -p "$TASK_TARGET_DIR"
    cp "$SRC_DIR/metadata-taskmanager.json" "$TASK_TARGET_DIR/metadata.json"
}

# Run deployment
deploy_widgets

# Clean up temp folder if it was created
if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
    echo "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
fi

echo "Restarting plasmashell to reload widget cache..."
if systemctl --user is-active --quiet plasma-plasmashell; then
    echo "Restarting plasmashell via systemd..."
    systemctl --user restart plasma-plasmashell
else
    echo "Restarting plasmashell manually..."
    kquitapp6 plasmashell || true
    kstart plasmashell &
fi

echo "--------------------------------------------------------"
echo "Installation complete!"
echo "To use the new widgets:"
echo "1. Right-click the taskbar -> Enter Edit Mode."
echo "2. Remove the existing Task Manager widget."
echo "3. Click 'Add Widgets...', search for 'Force Quit'."
echo "4. Drag 'Icons-Only Task Manager (Force Quit)' (or the standard version) to your panel."
echo "--------------------------------------------------------"
