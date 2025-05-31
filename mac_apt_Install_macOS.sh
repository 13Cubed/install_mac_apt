#!/bin/bash
# mac_apt Installation Script for macOS - Version 2.6
# Author: Zachary Burnham (@zmbf0r3ns1cs), Yogesh Khatri (@swiftforensics)
# Forked and updated by 13Cubed Studios LLC on 2025-05-03
# ----------------------------------------------------------------------------------------------
# Script to auto-download Yogesh Khatri's mac_apt tool from GitHub (with necessary dependencies)
# and install https://github.com/ydkhatri/mac_apt

# Run as './mac_apt_Install_macOS.sh'

PYTHONVER="python3.13"

# Function to verify directory and ensure it exists
verifyDir() {
    # Ensure the directory exists, if not create it
    cd "$userDir" &>/tmp/mac_apt_installer_output.txt || mkdir -p "$userDir" &>/tmp/mac_apt_installer_output.txt
    if [[ $? -ne 0 ]]; then
        echo "[!] Invalid directory. Please try again."
        chooseInstallation_Dir
    else
        echo "[~] Installing mac_apt to $userDir..."
    fi
}

# Function for user to specify installation directory
chooseInstallation_Dir() {
    read -p "[*] Would you like to specify an installation directory? [Y/n] " userDecision
    case "$userDecision" in
        [Yy]*)
            echo "[~] Example: /Users/<username>/Desktop"
            read -p "Directory Path: " userDir
            verifyDir
            ;;
        [Nn]*)
            export userDir=$(pwd)
            echo "[~] Installing mac_apt to $userDir..."
            ;;
        *)
            echo "[!] Invalid response. Please try again."
            chooseInstallation_Dir
            ;;
    esac
}

# ----------------------------------------------------------------------------------- #
# ------------------------ MAIN BODY OF SCRIPT BEGINS HERE -------------------------- #
# ----------------------------------------------------------------------------------- #

echo
echo "[*] mac_apt Installation Script for macOS - Version 2.6 (13Cubed Fork)"
echo "----------------------------------------------------------------------"

# Prompt for sudo password
echo "[!] This script requires sudo privileges."
sudo ping -c 1 127.0.0.1 &>/tmp/mac_apt_installer_output.txt

# Display macOS version
echo -n "[*] macOS version is "
sw_vers -productversion

# Display architecture (ARM/x64)
echo -n "[*] Architecture is "
uname -m

chooseInstallation_Dir

# Check if Homebrew is installed, install if not
if ! command -v brew &>/dev/null; then
    echo "[+] Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/null &>/tmp/mac_apt_installer_output.txt
    eval "$(/opt/homebrew/bin/brew shellenv)"
    if [[ $? -ne 0 ]]; then
        echo "[!] Homebrew installation failed."
        echo "[!] Please report this to the developer. Send /tmp/mac_apt_installer_output.txt"
        exit 1
    fi
fi

# Ensure Homebrew is up-to-date
echo "[~] Ensuring Homebrew is up-to-date..."
brew update &>/tmp/mac_apt_installer_output.txt

# Install Python if needed
if ! command -v "$PYTHONVER" &>/dev/null; then
    echo "[+] Installing $PYTHONVER..."
    brew install "${PYTHONVER/python/python@}" git &>/tmp/mac_apt_installer_output.txt
    if [[ $? -ne 0 ]]; then
        echo "[!] Python installation failed."
        echo "[!] Please report this to the developer. Send /tmp/mac_apt_installer_output.txt"
        exit 1
    fi
else
    echo "[*] $PYTHONVER is already installed"
fi

# Download mac_apt from GitHub
echo "[+] Downloading mac_apt from GitHub..."
cd "$userDir"
git clone --recursive https://github.com/ydkhatri/mac_apt.git &>/tmp/mac_apt_installer_output.txt
if [[ $? -ne 0 ]]; then
    echo "[!] Download failed due to 'git clone' error."
    echo "[!] Please delete the existing 'mac_apt' folder and try again!"
    exit 1
fi

cd mac_apt

# Backup mac_apt.py
cp mac_apt.py mac_apt.py.bak

# Insert global warning filter into mac_apt.py
ed -s mac_apt.py << 'EOF'
1i
import warnings
warnings.filterwarnings("ignore", message="pkg_resources is deprecated as an API.*")
.
w
EOF

# Backup apfs.py and patch it to remove the pkg_resources dependency
sed -i.bak 's/^from pkg_resources import parse_version$/from packaging.version import parse as parse_version/' plugins/helpers/apfs.py

# Ensure 'packaging' is present for the patched import
grep -q '^packaging' requirements.txt || echo "packaging>=23.0" >> requirements.txt

# Install dependencies and set up the environment
echo "[+] Creating virtual environment..."
$PYTHONVER -m venv env &>/tmp/mac_apt_installer_output.txt
source env/bin/activate

# Pin setuptools for legacy dependencies
pip3 install 'setuptools<81' --no-cache-dir &>/tmp/mac_apt_installer_output.txt

echo "[+] Installing dependencies (excluding zipfile_deflate64)..."
grep -v '^zipfile_deflate64' requirements.txt > /tmp/reqs_no_zipfile.txt
pip3 install -r /tmp/reqs_no_zipfile.txt --no-cache-dir &>/tmp/mac_apt_installer_output.txt

if [[ $? -ne 0 ]]; then
    echo "[!] Installation of dependencies failed."
    echo "[!] Please report this to the developer. Send /tmp/mac_apt_installer_output.txt"
    exit 1
fi

# Optional zipfile_deflate64 installation
echo "[+] Attempting to install zipfile_deflate64 (optional)..."
pip3 install zipfile_deflate64 --no-cache-dir &>/tmp/mac_apt_installer_output.txt || {
    echo "[!] zipfile_deflate64 failed to install. Proceeding without it."
    echo "[+] Commenting out 'extract_vr_zip' import line in mac_apt.py..."
    sed -i '' 's/^\(.*from plugins.helpers.extract_vr_zip import extract_zip.*\)$/# \1/' "mac_apt.py"
}

echo "[*] mac_apt successfully installed!"
echo "----------------------------------------------------------------------"
echo "To run mac_apt, enter the following command in Terminal:"
echo "  source env/bin/activate"
echo
echo "Run mac_apt with:"
echo "  python3 mac_apt.py ..."
echo
echo "When finished, deactivate the environment with:"
echo "  deactivate"
