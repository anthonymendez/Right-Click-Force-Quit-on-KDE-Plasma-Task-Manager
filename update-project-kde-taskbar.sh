#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || pwd)"
TEMP_DIR="$SCRIPT_DIR/tmp_update_git"
CLONE_ERR_LOG="$SCRIPT_DIR/tmp_git_clone_err.log"

# Cleanup handler to remove temporary folders/files on exit
cleanup() {
    if [ -d "$TEMP_DIR" ] || [ -f "$CLONE_ERR_LOG" ]; then
        echo "Cleaning up temporary files..."
        rm -rf "$TEMP_DIR"
        rm -f "$CLONE_ERR_LOG"
    fi
}
trap cleanup EXIT

# Determine target version/branch
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
NORM_VERSION=$(echo "$TARGET_VERSION" | sed 's/^v*//')

# Construct list of candidate references to try
REFS_TO_TRY=()
if [[ "$NORM_VERSION" =~ ^[0-9] ]]; then
    REFS_TO_TRY+=("v$NORM_VERSION")
    REFS_TO_TRY+=("$NORM_VERSION")
    
    # Add major.minor Plasma release branch as a fallback (e.g. Plasma/6.7)
    if [[ "$NORM_VERSION" =~ ^([0-9]+)\.([0-9]+) ]]; then
        MAJOR="${BASH_REMATCH[1]}"
        MINOR="${BASH_REMATCH[2]}"
        REFS_TO_TRY+=("Plasma/$MAJOR.$MINOR")
    fi
else
    REFS_TO_TRY+=("$TARGET_VERSION")
fi

echo "Updating taskbar files from KDE plasma-desktop repo..."

# Ensure clean temp directory and log files at start
rm -rf "$TEMP_DIR"
rm -f "$CLONE_ERR_LOG"

CLONED=false
GIT_REF=""
for REF in "${REFS_TO_TRY[@]}"; do
    echo "Attempting to clone ref: $REF..."
    if git clone -b "$REF" --depth 1 https://github.com/KDE/plasma-desktop.git "$TEMP_DIR" 2>"$CLONE_ERR_LOG"; then
        echo "Successfully cloned ref: $REF"
        CLONED=true
        GIT_REF="$REF"
        break
    else
        echo "Ref '$REF' not found or failed to clone."
    fi
done

if [ "$CLONED" = false ]; then
    echo "Error: Failed to clone any of the references: ${REFS_TO_TRY[*]}"
    if [ -f "$CLONE_ERR_LOG" ]; then
        echo "------------------- Git Error -------------------"
        cat "$CLONE_ERR_LOG"
        echo "-------------------------------------------------"
    fi
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
    exit 1
fi

echo "--------------------------------------------------------"
echo "Project update complete!"
echo "Please run './install.sh' to build and deploy the updated widgets."
echo "--------------------------------------------------------"
