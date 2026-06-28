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
ICON_TARGET_DIR="$BASE_TARGET_DIR/org.kde.plasma.icontasks.custom"
TASK_TARGET_DIR="$BASE_TARGET_DIR/org.kde.plasma.taskmanager.custom"

# Clear old/broken system shadow directory if it exists
if [ -d "$BASE_TARGET_DIR/org.kde.plasma.taskmanager" ]; then
    echo "Cleaning up old/broken shadow directory..."
    rm -rf "$BASE_TARGET_DIR/org.kde.plasma.taskmanager"
fi

# Function to deploy a custom plasmoid
deploy_plasmoid() {
    local target="$1"
    local name="$2"
    local metadata_src="$3"

    echo "Deploying $name to $target..."
    mkdir -p "$target/contents/ui/code"
    mkdir -p "$target/contents/config"
    cp "$metadata_src" "$target/metadata.json"
    cp -r "$SRC_DIR/qml/"* "$target/contents/ui/"
    cp "$SRC_DIR/main.xml" "$target/contents/config/main.xml"
}

# Deploy Icons-Only version
deploy_plasmoid "$ICON_TARGET_DIR" "Icons-Only Task Manager (Force Quit)" "$SRC_DIR/metadata-icontasks.json"

# Deploy Task Manager (Icons & Text) version
deploy_plasmoid "$TASK_TARGET_DIR" "Task Manager (Force Quit)" "$SRC_DIR/metadata-taskmanager.json"

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
