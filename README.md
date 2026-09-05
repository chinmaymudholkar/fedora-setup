# Fedora bootstrapping scripts

The shell scripts in this repo are to be used on a fresh install of Fedora Linux.They were written for Fedora 44, but can be used for newer versions too.

### On KDE Plasma workstation, it will:
1. Upgrade the OS
1. Enable third party repositories
1. Install the following using dnf as much as possible(don’t use flatpak or others):
    - Git
    - Thunderbird email client
    - KeePassXC (set it to start with system startup)
    - Brave Browser (with keepassXC extension)
    - Add Keepass XC extension to firefox
    - Onlyoffice Desktop Editors
    - Obsidian (Notes)
    - Librewolf browser (make it ephemeral)
    - Nautilus file manager (make it the default file manager)
    - Eye of gnome (make it the default image viewer)
    - Visual Studio Code
    - Megasync (Cloud storage)
    - Telegram Desktop
    - Tor Browser
    - Haruna media player
    - BleachBit
    - Czkawka duplicate file finder
    - Virtual machine manager
    - Fish shell
    - Remove libreoffice
1. Change the desktop layout
    1. Remove all panels and widgets
    2. Then, add a panel, bottom center aligned, fit content.  Add the KDE launcher button followed by the task manager
    3. Then, add a panel, top center aligned, fit content.  Add system tray and clock.
    4. On the clock widget, remove the date from the clock and add a timezone for India.  Default timezone should still be the UK.
    5. Then, add a panel, left center aligned, fit content.  Add icons to thunderbird, keepassxc, obsidian
1. Set Kwrite as the default text editor with new document to open every time it is opened
1. Set Fedora Light or Fedora Dark theme based on time
1. Set fish as the default shell
