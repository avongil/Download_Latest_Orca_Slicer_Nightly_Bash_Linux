#!/bin/bash
# Script to download the latest Orca Slicer nightly AppImage for Linux
# Uses GitHub API and jq for reliable parsing
# Saves to ~/AppImages, updates symlink.
set -e

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed."
    echo "Please install it: sudo apt install jq"
    exit 1
fi

APP_DIR="$HOME/AppImages"
mkdir -p "$APP_DIR"
cd "$APP_DIR"

echo "Fetching nightly-builds release assets from GitHub API..."

# Try both repositories (the project is transitioning)
REPOS=("SoftFever/OrcaSlicer" "OrcaSlicer/OrcaSlicer")
JSON=""
REPO_USED=""

for REPO in "${REPOS[@]}"; do
    echo "Trying repository: $REPO"
    JSON=$(curl -s "https://api.github.com/repos/$REPO/releases/tags/nightly-builds")
    
    # Check if we got valid JSON with assets
    if echo "$JSON" | jq -e '.assets' &> /dev/null; then
        REPO_USED="$REPO"
        echo "Successfully fetched data from $REPO"
        break
    fi
done

if [ -z "$REPO_USED" ]; then
    echo "Error: Could not fetch release data from any repository."
    echo "Please check your internet connection or try manually:"
    echo "  https://github.com/SoftFever/OrcaSlicer/releases/tag/nightly-builds"
    echo "  https://github.com/OrcaSlicer/OrcaSlicer/releases/tag/nightly-builds"
    exit 1
fi

# Extract browser_download_url for preferred Ubuntu2404 AppImage
DOWNLOAD_URL=$(echo "$JSON" | jq -r '.assets[]? | select(.browser_download_url != null) | .browser_download_url | select(contains("Ubuntu2404") and endswith(".AppImage"))' | head -n1)

# Fallback to Ubuntu2204 if no Ubuntu2404
if [ -z "$DOWNLOAD_URL" ]; then
    echo "No Ubuntu2404 version found, trying Ubuntu2204..."
    DOWNLOAD_URL=$(echo "$JSON" | jq -r '.assets[]? | select(.browser_download_url != null) | .browser_download_url | select(contains("Ubuntu2204") and endswith(".AppImage"))' | head -n1)
fi

# Fallback to any Linux AppImage
if [ -z "$DOWNLOAD_URL" ]; then
    echo "No Ubuntu-specific version found, trying generic Linux AppImage..."
    DOWNLOAD_URL=$(echo "$JSON" | jq -r '.assets[]? | select(.browser_download_url != null) | .browser_download_url | select(contains("Linux") and endswith(".AppImage"))' | head -n1)
fi

if [ -z "$DOWNLOAD_URL" ]; then
    echo "Error: No Linux AppImage found in nightly-builds assets."
    echo "This may occur if the latest build upload is delayed or still processing."
    echo ""
    echo "Available assets in the release:"
    echo "$JSON" | jq -r '.assets[]?.name // "No assets found"'
    echo ""
    echo "Please check manually and download from:"
    echo "  https://github.com/$REPO_USED/releases/tag/nightly-builds"
    exit 1
fi

echo "Found latest nightly AppImage: $DOWNLOAD_URL"
FILENAME=$(basename "$DOWNLOAD_URL")

# Backup old symlink target if it exists
if [ -L "OrcaSlicer-nightly.AppImage" ] && [ -e "OrcaSlicer-nightly.AppImage" ]; then
    OLD_TARGET=$(readlink "OrcaSlicer-nightly.AppImage")
    if [ -f "$OLD_TARGET" ] && [ "$OLD_TARGET" != "$FILENAME" ]; then
        echo "Backing up previous version: $OLD_TARGET"
        mv "$OLD_TARGET" "$OLD_TARGET.bak"
    fi
    rm "OrcaSlicer-nightly.AppImage"
fi

echo "Downloading $FILENAME ..."
curl -L -o "$FILENAME" "$DOWNLOAD_URL"

if [ ! -f "$FILENAME" ]; then
    echo "Error: Download failed - file not created"
    exit 1
fi

chmod +x "$FILENAME"
ln -sf "$FILENAME" "OrcaSlicer-nightly.AppImage"

echo ""
echo "✓ Done! Latest Orca Slicer nightly downloaded:"
echo "  $APP_DIR/$FILENAME"
echo "  Symlink: $APP_DIR/OrcaSlicer-nightly.AppImage"
echo ""

# Create .desktop file for menu entry
DESKTOP_FILE="$HOME/.local/share/applications/orcaslicer-nightly.desktop"
ICON_DIR="$HOME/.local/share/icons"
mkdir -p "$HOME/.local/share/applications"
mkdir -p "$ICON_DIR"

echo "Extracting icon from AppImage..."
# Try to extract icon from AppImage
ICON_PATH="$ICON_DIR/orcaslicer-nightly.png"
if command -v convert &> /dev/null && ./"$FILENAME" --appimage-extract "*.png" 2>/dev/null; then
    # Find the largest icon
    EXTRACTED_ICON=$(find squashfs-root -name "*.png" -type f | head -n1)
    if [ -n "$EXTRACTED_ICON" ]; then
        cp "$EXTRACTED_ICON" "$ICON_PATH"
        rm -rf squashfs-root
        echo "✓ Icon extracted successfully"
    else
        ICON_PATH="printer"  # Fallback to system icon
        echo "Using system printer icon as fallback"
    fi
else
    ICON_PATH="printer"  # Fallback to system icon
    echo "Using system printer icon"
fi

echo "Creating desktop menu entry..."
cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Orca Slicer Nightly
Comment=3D Printing Slicer (Nightly Build)
Exec=$APP_DIR/OrcaSlicer-nightly.AppImage %F
Icon=$ICON_PATH
Terminal=false
Categories=Graphics;3DGraphics;Engineering;
MimeType=model/stl;application/vnd.ms-3mfdocument;application/prs.wavefront-obj;application/x-amf;
StartupNotify=true
StartupWMClass=OrcaSlicer
Keywords=3D;Printing;Slicer;
EOF

chmod +x "$DESKTOP_FILE"

# Update desktop database to refresh menu
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

echo "✓ Desktop menu entry created: Orca Slicer Nightly"
echo ""

read -p "Launch Orca Slicer nightly now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./OrcaSlicer-nightly.AppImage &
    echo "Orca Slicer Nightly launched in background"
fi
