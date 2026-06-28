#!/usr/bin/env bash
set -euo pipefail

# Determine target git reference (tag or branch)
TARGET_VERSION=""
if [ "${1:-}" != "" ]; then
    TARGET_VERSION="$1"
else
    # Detect installed version
    PLASMA_VER=$(plasmashell --version 2>/dev/null | awk '{print $2}')
    if [ -n "$PLASMA_VER" ]; then
        TARGET_VERSION="$PLASMA_VER"
    else
        echo "Could not detect installed KDE Plasma version."
        echo "Usage: $0 [version | branch]"
        exit 1
    fi
fi

# Remove leading 'v' if present to normalize
TARGET_VERSION=$(echo "$TARGET_VERSION" | sed 's/^v*//')

# Construct git ref (prefix with 'v' if it looks like a version number, e.g. 6.7.1)
if [[ "$TARGET_VERSION" =~ ^[0-9] ]]; then
    GIT_REF="v$TARGET_VERSION"
else
    GIT_REF="$TARGET_VERSION"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || pwd)"
TEMP_DIR="$SCRIPT_DIR/tmp_update_git"

echo "Updating taskbar files from KDE plasma-desktop repo (ref: $GIT_REF)..."

# Ensure clean temp directory
rm -rf "$TEMP_DIR"

# Clone the specified ref
if ! git clone -b "$GIT_REF" --depth 1 https://github.com/KDE/plasma-desktop.git "$TEMP_DIR"; then
    echo "Error: Failed to clone plasma-desktop reference: $GIT_REF"
    exit 1
fi

echo "Copying taskmanager source files..."
# Recreate directories
mkdir -p "$SCRIPT_DIR/src/qml/kde-taskbar/code"

# Copy files in the project's new clean directory layout
cp "$TEMP_DIR/applets/taskmanager/main.xml" "$SCRIPT_DIR/src/main.xml"
cp "$TEMP_DIR/applets/taskmanager/qml/main.qml" "$SCRIPT_DIR/src/qml/main.qml"

# Copy all other QML/JS files to kde-taskbar/ subfolder
find "$TEMP_DIR/applets/taskmanager/qml/" -maxdepth 1 -type f ! -name "main.qml" -exec cp {} "$SCRIPT_DIR/src/qml/kde-taskbar/" \;
# Copy code helper files
cp -r "$TEMP_DIR/applets/taskmanager/qml/code/"* "$SCRIPT_DIR/src/qml/kde-taskbar/code/"

# Apply local patches
echo "Applying custom force-quit patches..."
if patch -p1 -d "$SCRIPT_DIR" < "$SCRIPT_DIR/patches/force-quit.patch"; then
    echo "Patches applied successfully!"
else
    echo "--------------------------------------------------------"
    echo "Error: Patch failed to apply."
    echo "This usually happens when upstream KDE QML files changed significantly."
    echo "You will need to manually resolve conflicts."
    echo "--------------------------------------------------------"
    # Clean up temp folder before exiting
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Clean up temp folder
echo "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

echo "--------------------------------------------------------"
echo "Project update complete!"
echo "Please run './install.sh' to build and deploy the updated widgets."
echo "--------------------------------------------------------"
