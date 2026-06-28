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
SHARED_SYSTEM_DIR="$BASE_TARGET_DIR/org.kde.plasma.taskmanager"
ICON_SYSTEM_DIR="$BASE_TARGET_DIR/org.kde.plasma.icontasks"
ICON_CUSTOM_DIR="$BASE_TARGET_DIR/org.kde.plasma.icontasks.custom"
TASK_CUSTOM_DIR="$BASE_TARGET_DIR/org.kde.plasma.taskmanager.custom"

# Function to deploy custom widgets
deploy_widgets() {
    # 1. Clean up system shadowing directories to fully restore original system widgets
    if [ -d "$SHARED_SYSTEM_DIR" ]; then
        echo "Removing local Task Manager system shadow folder: $SHARED_SYSTEM_DIR..."
        rm -rf "$SHARED_SYSTEM_DIR"
    fi
    if [ -d "$ICON_SYSTEM_DIR" ]; then
        echo "Removing local Icons-Only system shadow folder: $ICON_SYSTEM_DIR..."
        rm -rf "$ICON_SYSTEM_DIR"
    fi

    # 2. Deploy custom Icons-Only Task Manager (Force Quit)
    echo "Deploying custom Icons-Only Task Manager to $ICON_CUSTOM_DIR..."
    rm -rf "$ICON_CUSTOM_DIR"
    mkdir -p "$ICON_CUSTOM_DIR/contents/ui"
    mkdir -p "$ICON_CUSTOM_DIR/contents/config"
    cp -r "$SRC_DIR/qml/"* "$ICON_CUSTOM_DIR/contents/ui/"
    cp "$SRC_DIR/main.xml" "$ICON_CUSTOM_DIR/contents/config/main.xml"
    cp "$SRC_DIR/metadata-icontasks.json" "$ICON_CUSTOM_DIR/metadata.json"

    # 3. Deploy custom Task Manager (Force Quit)
    echo "Deploying custom Task Manager to $TASK_CUSTOM_DIR..."
    rm -rf "$TASK_CUSTOM_DIR"
    mkdir -p "$TASK_CUSTOM_DIR/contents/ui"
    mkdir -p "$TASK_CUSTOM_DIR/contents/config"
    cp -r "$SRC_DIR/qml/"* "$TASK_CUSTOM_DIR/contents/ui/"
    cp "$SRC_DIR/main.xml" "$TASK_CUSTOM_DIR/contents/config/main.xml"
    cp "$SRC_DIR/metadata-taskmanager.json" "$TASK_CUSTOM_DIR/metadata.json"
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
