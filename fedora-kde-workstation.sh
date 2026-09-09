#!/usr/bin/env bash
# ==============================================================================
# Fedora 44 (KDE Plasma 6) Automated Setup Script - Auto-Theme & Panel Tweaks
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
log_info "1/12: Configuring Secure Private DNS (Systemd-Resolved DoT)..."

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

# Restart systemd-resolved to apply configuration
sudo systemctl restart systemd-resolved

# Instruct NetworkManager to hand off DNS resolving to systemd-resolved
sudo mkdir -p /etc/NetworkManager/conf.d/
cat << 'EOF' | sudo tee /etc/NetworkManager/conf.d/10-dns-resolved.conf > /dev/null
[main]
dns=systemd-resolved
EOF

sudo systemctl restart NetworkManager

# Verification
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


# --- 2. System Update ---
log_info "2/12: Updating system packages..."
sudo dnf upgrade -y

# --- 3. Enable Repositories ---
log_info "3/12: Setting up package repositories..."
sudo dnf install -y dnf-plugins-core fedora-workstation-repositories curl wget

# COPR Repositories (Klassy & LibreWolf)
log_info "Enabling COPR repositories..."
sudo dnf copr enable -y paulwon/klassy || log_warn "Failed to enable Klassy COPR repo."
sudo dnf copr enable -y bgstack15/librewolf || log_warn "Failed to enable LibreWolf COPR repo."

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

# Refresh metadata cleanly
log_info "Rebuilding DNF cache..."
sudo dnf makecache

# --- 4. DNF Package Installation (Includes Klassy) ---
log_info "4/12: Installing packages via DNF..."
PACKAGES=(
  git
  thunderbird
  firefox
  keepassxc
  brave-browser
  onlyoffice-desktopeditors
  librewolf
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
  klassy
)

sudo dnf install -y "${PACKAGES[@]}"

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

# --- 5. Install & Configure Klassy Theme ---
log_info "5/12: Applying Klassy Window Decoration..."

QDBUS_CMD=""
if command -v qdbus-qt6 &>/dev/null; then QDBUS_CMD="qdbus-qt6";
elif command -v qdbus6 &>/dev/null; then QDBUS_CMD="qdbus6";
elif command -v qdbus &>/dev/null; then QDBUS_CMD="qdbus"; fi

if command -v kwriteconfig6 &>/dev/null; then
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme "org.kde.klassy"
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library "org.kde.klassy"
    
    if [ -n "$QDBUS_CMD" ]; then
        $QDBUS_CMD org.kde.KWin /KWin reconfigure || log_warn "KWin reconfigure command failed."
    fi
    log_success "Klassy window decoration applied."
else
    log_warn "kwriteconfig6 not found. Please set Klassy manually in System Settings."
fi

# --- 6. Security Harden Firefox ---
log_info "6/12: Security Hardening Firefox..."

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
log_info "7/12: Removing LibreOffice..."
sudo dnf remove -y "libre*" || log_warn "LibreOffice not found."

# --- 8. Application Defaults & Configuration ---
log_info "8/12: Setting default application handlers..."

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

# LibreWolf Ephemeral Mode
mkdir -p ~/.local/share/applications
if [ -f /usr/share/applications/io.gitlab.librewolf-community.desktop ]; then
    sed 's/Exec=librewolf %u/Exec=librewolf --private-window %u/g' /usr/share/applications/io.gitlab.librewolf-community.desktop > ~/.local/share/applications/io.gitlab.librewolf-community.desktop
elif [ -f /usr/share/applications/librewolf.desktop ]; then
    sed 's/Exec=librewolf %u/Exec=librewolf --private-window %u/g' /usr/share/applications/librewolf.desktop > ~/.local/share/applications/librewolf.desktop
fi

# Default Shell to Fish
CURRENT_USER=$(whoami)
FISH_PATH=$(which fish 2>/dev/null || echo "")
if [ -n "$FISH_PATH" ]; then
    sudo chsh -s "$FISH_PATH" "$CURRENT_USER"
fi

# --- 9. Browser Extensions Reference ---
log_info "9/12: Writing extension instructions..."
mkdir -p ~/.config/browser-extensions-setup
cat << 'EOF' > ~/.config/browser-extensions-setup/urls.txt
KeePassXC Extension: https://addons.mozilla.org/en-US/firefox/addon/keepassxc-browser/
Anonymous Story Viewer: https://addons.mozilla.org/en-US/firefox/addon/anonymous-story-viewer/
EOF

# --- 10. KDE Plasma 6 Desktop Panels ---
log_info "10/12: Applying KDE Plasma 6 Desktop Panels..."

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

# --- 11. Automatic Light/Dark Theme Switching ---
log_info "11/12: Setting up Automatic Light/Dark Theme switching..."

mkdir -p ~/.local/bin ~/.config/systemd/user

cat << 'EOF' > ~/.local/bin/plasma-auto-theme.sh
#!/usr/bin/env bash
HOUR=$(date +%H)

THEME_TOOL=""
if command -v plasma-apply-lookandfeel &>/dev/null; then
    THEME_TOOL="plasma-apply-lookandfeel -a"
elif command -v lookandfeeltool &>/dev/null; then
    THEME_TOOL="lookandfeeltool -a"
fi

if [ -z "$THEME_TOOL" ]; then
    exit 0
fi

if [ "$HOUR" -ge 7 ] && [ "$HOUR" -lt 19 ]; then
    $THEME_TOOL org.kde.breezedark.desktop &>/dev/null || $THEME_TOOL org.kde.breeze.desktop
else
    $THEME_TOOL org.kde.breezedark.desktop
fi
EOF
chmod +x ~/.local/bin/plasma-auto-theme.sh

cat << 'EOF' > ~/.config/systemd/user/plasma-auto-theme.service
[Unit]
Description=KDE Plasma Automatic Theme Switcher

[Service]
Type=oneshot
ExecStart=/home/%u/.local/bin/plasma-auto-theme.sh
EOF

cat << 'EOF' > ~/.config/systemd/user/plasma-auto-theme.timer
[Unit]
Description=Run KDE Plasma Auto Theme Switcher hourly

[Timer]
OnCalendar=*-*-* *:00:00
OnBootSec=1min
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now plasma-auto-theme.timer
~/.local/bin/plasma-auto-theme.sh || log_warn "Could not evaluate immediate theme application."

# --- 12. Final Cleanup ---
log_info "12/12: Finalizing configuration..."

log_success "=== Setup process completed! ==="
log_info "Please log out and log back in to finalize changes."
