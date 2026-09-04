# Fedora bootstrapping scripts

The shell scripts in this repo are to be used on a fresh install of Fedora Linux.They were written for Fedora 44, but can be used for newer versions too.

### On KDE Plasma workstation, it will:
1. Ugrade the OS
2. Install the following using dnf as much as possible(don’t use flatpak or others):
    1. git
    2. thunderbird
    3. keepassXC (set it to start with system startup)
    6. brave browser (with keepassXC extension)
    7. Add Keepass XC extension to firefox
    8. Add ‘Anonymous story viewer’ extension to firefox
    9. Onlyoffice Desktop Editors
    10. Obsidian
    11. Librewolf browser (make it ephemeral)
    12. Nautilus file manager (make default)
    13. Eye of gnome
    14. Visual studio code
    15. megasync
    16. telegram
    17. tor
    18. haruna
    19. bleachbit
    20. czkawka
    21. virtual machine manager
    22. fish
    23. Remove libreoffice
3. Change the desktop
    1. Remove all panels and widgets
    2. Then, add a panel, bottom center aligned, fit content.  Add the KDE launcher button followed by the task manager
    3. Then, add a panel, top center aligned, fit content.  Add system tray and clock.
    4. On the clock widget, remove the date from the clock and add a timezone for India.  Default should still be UK.
    5. Add a system monitor widget
    6. Then, add a panel, left center aligned, fit content.  Add icons to thunderbird, keepassxc, obsidian
4. Set Kwrite as the default text editor with new document to open every time it is opened
5. Enable third party repositories
6. Set Fedora Light or Fedora Dark theme based on time
7. Set fish as the default shell
