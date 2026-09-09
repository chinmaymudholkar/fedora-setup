#!/usr/bin/env bash
# ==============================================================================
# Fedora 44 (KDE Plasma 6) Automated Setup Script - Klassy Light & Secure Setup
# ==============================================================================
set -euo pipefail

# --- Setup Logging ---
LOG_FILE="${HOME}/setup_fedora.log"
exec > >(tee -i "${LOG_FILE}") 2>&1

# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO $(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS $(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN $(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR $(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"; }

failure_handler() {
  local exit_code=$?
  local line_number=$1
  log_error "Script failed at line ${line_number} with exit code ${exit_code}."
  log_error "Check log at: ${LOG_FILE}"
  exit "${exit_code}"
}
trap 'failure_handler ${LINENO}' ERR

log_info "Starting Fedora setup script..."

# --- 1. Secure Private DNS (DNS-over-TLS) Setup & Verification ---
log_info "1/10: Configuring Secure Private DNS (Systemd-Resolved DoT)..."

sudo systemctl enable --now systemd-resolved

# Configure systemd-resolved for DNS-over-TLS using Cloudflare & Quad9
sudo mkdir -p /etc/systemd/resolved.conf.d/
cat << 'EOF' | sudo tee /etc/systemd/resolved.conf.d/privacy-dns.conf > /dev/null
[Resolve]
DNS=1.1.1.1#one.one.one.one 9.9.9.9#dns.quad9.net
FallbackDNS=1.0.0.1#one.one.one.one 149.112.112.112#dns.quad9.net
DNSOverTLS=yes
DNSSEC=allow-downgrade
EOF

sudo systemctl restart systemd-resolved

# Instruct NetworkManager to hand off DNS resolving to systemd-resolved
sudo mkdir -p /etc/NetworkManager/conf.d/
cat << 'EOF' | sudo tee /etc/NetworkManager/conf.d/10-dns-resolved.conf > /dev/null
[main]
dns=systemd-resolved
EOF

sudo systemctl restart NetworkManager

log_info "Verifying Secure DNS configuration..."
sleep 2
if resolvectl status | grep -E "DNS Server|DNS-over-TLS" > /dev/null; then
    log_success "DNS-over-TLS enabled on systemd-resolved."
else
    log_warn "Failed to verify DoT status via resolvectl."
fi

log_info "Testing DNS query resolution..."
if resolvectl query cloudflare.com > /dev/null; then
    log_success "DNS query verified successfully."
else
    log_warn "DNS query test failed."
fi


# --- 2. Remove Unwanted Third-Party Repositories & Packages ---
log_info "2/10: Removing Google Chrome & PyCharm (phracek COPR) repositories..."

# Disable & remove phracek's PyCharm COPR repository
sudo dnf copr disable -y phracek/PyCharm 2>/dev/null || true
sudo rm -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:phracek:PyCharm.repo \
           /etc/yum.repos.d/copr:copr.fedorainfracloud.org:phracek:PyCharm.repo

# Disable & remove Fedora Google Chrome repository
sudo dnf config-manager --set-disabled google-chrome 2>/dev/null || true
sudo rm -f /etc/yum.repos.d/google-chrome.repo /etc/yum.repos.d/google-chrome*.repo

# Remove installed packages if present
sudo dnf remove -y google-chrome-stable pycharm-community pycharm-professional 2>/dev/null || true

# Force DNF cache purge so removed repos disappear from upgrade lists immediately
sudo dnf clean metadata


# --- 3. System Update & Repository Setup ---
log_info "3/10: Setting up repositories and updating system..."
sudo dnf install -y dnf-plugins-core fedora-workstation-repositories curl wget

# Active Klassy COPR Repositories
log_info "Enabling Klassy COPR repositories..."
sudo dnf copr enable -y errornointernet/klassy || sudo dnf copr enable -y major-tom/klassy || log_warn "Failed to enable Klassy COPR repo."

# RPM Fusion Repositories
log_info "Enabling RPM Fusion..."
sudo dnf install -y "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" || log_warn "Failed RPM Fusion Free."
sudo dnf install -y "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" || log_warn "Failed RPM Fusion Non-Free."

# Brave Browser Repo
log_info "Adding Brave repository..."
sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc || true
curl -sSL https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo | sudo tee /etc/yum.repos.d/brave-browser.repo > /dev/null

# VS Code Repo
log_info "Adding Visual Studio Code repository..."
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc || true
cat << 'EOF' | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

# OnlyOffice Repo setup
log_info "Adding OnlyOffice repo..."
sudo dnf install -y https://download.onlyoffice.com/repo/centos/main/noarch/onlyoffice-repo.noarch.rpm || log_warn "Failed OnlyOffice Repo installation."

# Refresh metadata cleanly and upgrade
log_info "Rebuilding DNF cache and upgrading system..."
sudo dnf makecache
sudo dnf upgrade -y


# --- 4. DNF Package Installation ---
log_info "4/10: Installing packages via DNF..."
PACKAGES=(
  git
  thunderbird
  firefox
  keepassxc
  brave-browser
  onlyoffice-desktopeditors
  nautilus
  eog
  code
  telegram-desktop
  tor
  haruna
  bleachbit
  virt-manager
  fish
  kwrite
  qt6-qttools
)

sudo dnf install -y "${PACKAGES[@]}"

# Attempt Klassy package install via DNF or build from source fallback
log_info "Installing Klassy..."
if ! sudo dnf install -y klassy; then
    log_warn "RPM package for Klassy not found in COPR. Building from official source..."
    
    # Install build dependencies
    sudo dnf install -y git cmake extra-cmake-modules gettext gcc-c++ \
        "cmake(KF6Config)" "cmake(KF6CoreAddons)" "cmake(KF6ColorScheme)" \
        "cmake(KF6I18n)" "cmake(KF6IconThemes)" "cmake(KF6KCMUtils)" \
        "cmake(KF6GuiAddons)" "cmake(KF6WindowSystem)" "cmake(KDecoration3)"
    
    BUILD_DIR=$(mktemp -d)
    git clone https://github.com/paulmcauley/klassy.git "$BUILD_DIR"
    cd "$BUILD_DIR"
    ./install.sh || log_warn "Klassy compilation failed."
    cd ~
    rm -rf "$BUILD_DIR"
fi


# --- Standalone Applications (Direct Installation) ---

# MEGAsync RPM direct installation
log_info "Installing MEGAsync..."
MEGA_RPM_URL="https://mega.nz/linux/repo/Fedora_40/x86_64/megasync-Fedora_40.x86_64.rpm"
if sudo dnf install -y "$MEGA_RPM_URL"; then
    log_success "MEGAsync installed successfully."
else
    log_warn "Failed to install MEGAsync directly."
fi

# Obsidian AppImage Setup
log_info "Installing Obsidian..."
mkdir -p ~/.local/bin ~/.local/share/applications
OBSIDIAN_URL="https://github.com/obsidianmd/obsidian-releases/releases/download/v1.6.7/Obsidian-1.6.7.AppImage"
wget -q -O ~/.local/bin/Obsidian.AppImage "$OBSIDIAN_URL" || log_warn "Failed to download Obsidian."
chmod +x ~/.local/bin/Obsidian.AppImage

cat << 'EOF' > ~/.local/share/applications/obsidian.desktop
[Desktop Entry]
Name=Obsidian
Exec=/home/%U/.local/bin/Obsidian.AppImage --no-sandbox %U
Icon=obsidian
Type=Application
Terminal=false
Categories=Office;Utility;
MimeType=x-scheme-handler/obsidian;
EOF
sed -i "s|%U|$(whoami)|g" ~/.local/share/applications/obsidian.desktop

# Czkawka GUI Direct Install
log_info "Installing Czkawka GUI..."
CZKAWKA_URL="https://github.com/qarmin/czkawka/releases/download/7.0.0/linux_czkawka_gui"
sudo wget -q -O /usr/local/bin/czkawka_gui "$CZKAWKA_URL" || log_warn "Failed to download Czkawka GUI."
sudo chmod +x /usr/local/bin/czkawka_gui

cat << 'EOF' > ~/.local/share/applications/czkawka.desktop
[Desktop Entry]
Name=Czkawka
Exec=/usr/local/bin/czkawka_gui
Icon=system-search
Type=Application
Terminal=false
Categories=System;Utility;
EOF


# --- 5. Configure Klassy Light Theme & Window Decorations ---
log_info "5/10: Applying Klassy Light Global Theme & Window Decorations..."

QDBUS_CMD=""
if command -v qdbus-qt6 &>/dev/null; then QDBUS_CMD="qdbus-qt6";
elif command -v qdbus6 &>/dev/null; then QDBUS_CMD="qdbus6";
elif command -v qdbus &>/dev/null; then QDBUS_CMD="qdbus"; fi

# Explicitly configure KDE Globals & KWin for Klassy + Breeze Light scheme
if command -v kwriteconfig6 &>/dev/null; then
    # Set Window Decoration to Klassy
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme "org.kde.klassy"
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library "org.kde.klassy"

    # Set Widget Style to Klassy
    kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle "klassy"

    # Set Color Scheme to Light (BreezeLight)
    kwriteconfig6 --file kdeglobals --group General --key ColorScheme "BreezeLight"
    
    # Reload live settings if qdbus is available
    if [ -n "$QDBUS_CMD" ]; then
        $QDBUS_CMD org.kde.KWin /KWin reconfigure || true
        $QDBUS_CMD org.kde.KControl /KControl reconfigure || true
    fi
    log_success "Klassy application style and window decorations configured."
else
    log_warn "kwriteconfig6 not found."
fi


# --- 6. Security Harden Firefox ---
log_info "6/10: Security Hardening Firefox..."

FIREFOX_DIR="${HOME}/.mozilla/firefox"

if [ ! -d "$FIREFOX_DIR" ]; then
    log_info "Initializing Firefox profile directory..."
    timeout 5 firefox --headless || true
    sleep 2
fi

PROFILE_DIR=$(find "$FIREFOX_DIR" -maxdepth 1 -type d -name "*.default-release" | head -n 1 || true)
if [ -z "$PROFILE_DIR" ]; then
    PROFILE_DIR=$(find "$FIREFOX_DIR" -maxdepth 1 -type d -name "*.default" | head -n 1 || true)
fi

if [ -n "$PROFILE_DIR" ] && [ -d "$PROFILE_DIR" ]; then
    log_info "Applying security preferences to profile: ${PROFILE_DIR}"
    
    cat << 'EOF' > "${PROFILE_DIR}/user.js"
// --- FIREFOX SECURITY & PRIVACY HARDENING ---

// Privacy & Tracking Protection
user_pref("privacy.firstparty.isolate", true);
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);
user_pref("privacy.trackingprotection.cryptomining.enabled", true);
user_pref("privacy.trackingprotection.fingerprinting.enabled", true);

// HTTPS-Only Mode
user_pref("dom.security.https_only_mode", true);
user_pref("dom.security.https_only_mode_ever_enabled", true);

// DNS-over-HTTPS (Cloudflare / Max Security Fallback)
user_pref("network.trr.mode", 2);
user_pref("network.trr.uri", "https://mozilla.cloudflare-dns.com/dns-query");

// Disable Telemetry & Studies
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("experiments.supported", false);
user_pref("experiments.enabled", false);
user_pref("experiments.manifest.uri", "");
user_pref("datareporting.healthreport.uploadEnabled", false);

// Disable Unnecessary Permissions & Autoplay
user_pref("media.autoplay.default", 5);
user_pref("geo.enabled", false);

// Network Hardening
user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.predictor.enabled", false);
EOF

    log_success "Firefox user.js hardened successfully."
else
    log_warn "Could not auto-detect Firefox profile directory. Please open Firefox once and rerun the script."
fi


# --- 7. Remove LibreOffice ---
log_info "7/10: Removing LibreOffice..."
sudo dnf remove -y "libreoffice*" || log_warn "LibreOffice not found."


# --- 8. Application Defaults & Configuration ---
log_info "8/10: Setting default application handlers..."

# Default file manager
xdg-mime default org.gnome.Nautilus.desktop inode/directory

# Default text editor (KWrite)
xdg-mime default org.kde.kwrite.desktop text/plain
mkdir -p ~/.config
if command -v kwriteconfig6 &>/dev/null; then
    kwriteconfig6 --file kwriterc --group "General" --key "Startup Session" "new"
else
    cat << 'EOF' >> ~/.config/kwriterc

[General]
Startup Session=new
EOF
fi

# KeePassXC Autostart
mkdir -p ~/.config/autostart
if [ -f /usr/share/applications/org.keepassxc.KeePassXC.desktop ]; then
    cp /usr/share/applications/org.keepassxc.KeePassXC.desktop ~/.config/autostart/
elif [ -f /usr/share/applications/keepassxc.desktop ]; then
    cp /usr/share/applications/keepassxc.desktop ~/.config/autostart/
fi

# Default Shell to Fish
CURRENT_USER=$(whoami)
FISH_PATH=$(which fish 2>/dev/null || echo "")
if [ -n "$FISH_PATH" ]; then
    sudo chsh -s "$FISH_PATH" "$CURRENT_USER"
fi


# --- 9. KDE Plasma 6 Desktop Panels ---
log_info "9/10: Applying KDE Plasma 6 Desktop Panels..."

JS_SCRIPT="/tmp/reset_panels.js"
cat << 'EOF' > "$JS_SCRIPT"
var allPanels = panels();
for (var i = 0; i < allPanels.length; i++) {
    allPanels[i].remove();
}

// 1. Bottom Panel (Dodge Windows)
var bottomPanel = new Panel();
bottomPanel.location = "bottom";
bottomPanel.alignment = "center";
bottomPanel.lengthMode = "fit";
bottomPanel.hiding = "dodgewindows";
bottomPanel.addWidget("org.kde.plasma.kickoff");
bottomPanel.addWidget("org.kde.plasma.icontasks");

// 2. Top Panel (Auto-Hide)
var topPanel = new Panel();
topPanel.location = "top";
topPanel.alignment = "center";
topPanel.lengthMode = "fit";
topPanel.hiding = "autohide";
topPanel.addWidget("org.kde.plasma.systemmonitor");
topPanel.addWidget("org.kde.plasma.systemtray");

var clock = topPanel.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = Array("Appearance");
clock.writeConfig("showDate", false);
clock.writeConfig("selectedTimeZones", Array("Local", "Asia/Kolkata"));

// 3. Left Panel (Dodge Windows)
var leftPanel = new Panel();
leftPanel.location = "left";
leftPanel.alignment = "center";
leftPanel.lengthMode = "fit";
leftPanel.hiding = "dodgewindows";

var launcher = leftPanel.addWidget("org.kde.plasma.icon-tasks");
launcher.currentConfigGroup = Array("General");
launcher.writeConfig("launchers", Array(
    "applications:mozilla-thunderbird.desktop",
    "applications:org.keepassxc.KeePassXC.desktop",
    "applications:obsidian.desktop"
));
EOF

if [ -n "$QDBUS_CMD" ]; then
    log_info "Using DBus command: $QDBUS_CMD"
    $QDBUS_CMD org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat "$JS_SCRIPT")" || log_warn "KDE panel DBus evaluation failed."
else
    log_warn "No suitable qdbus binary found. Could not execute panel script."
fi

rm -f "$JS_SCRIPT"


# --- 10. Final Cleanup ---
log_info "10/10: Finalizing configuration..."

log_success "=== Setup process completed! ==="
log_info "Please log out and log back in to finalize changes."
