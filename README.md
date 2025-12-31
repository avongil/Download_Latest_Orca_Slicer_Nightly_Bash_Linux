# Download_Latest_Orca_Slicer_Nightly_Bash_Linux
Downloads the latest Orca Slicer nightly, saves it to your app image folder then makes a .desktop file and installs it.

This requires the jp Command-line JSON processor to install.   On Arch, Pacman -Syu jq


This script checks both repositories installs the Ubuntu2404 AppImage and fallsback to, Ubuntu2204, then generic Linux AppImage if not found. 
After it is downloaded and moved to the AppImage folder, it makes a .desktop file and icon for your menu.
