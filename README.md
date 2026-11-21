# Niri desktop dotfiles

This is the first portable snapshot of a Niri desktop with a Quickshell bar,
dock, Spotlight, notification center, power menu, clipboard, and wallpaper
picker. It also includes the Hyprlock theme, Dolphin styling, a btop task manager
launcher, and the greetd theme source.

## Install

On a Niri setup, review the files under `home/` and run `./install.sh`.
It copies missing files into your home directory and reports differing files
it skipped. You can pass a destination directory to stage everything first.
Use a conventional XDG directory layout and add `~/.local/bin` to your
session's `PATH`.

The core setup uses Niri, Quickshell, Python 3, PipeWire/WirePlumber,
NetworkManager, and wl-clipboard. Optional features use cliphist, swaybg,
hyprlock, swayidle, Dolphin, qt6ct, Kitty, btop, FeatherPad, and khal. Check
the Niri bindings before using them. Terminal, screenshot, and recording
shortcuts point to specific apps that you can swap for your own.

Install the [MacTahoe icon theme](https://github.com/vinceliuice/MacTahoe-icon-theme)
for the matching desktop icons. The shell uses Aptos Narrow when installed.
Aptos files and the desktop photo are supplied separately.

For Dolphin, set the qt6ct palette path to
`~/.config/dolphin/palette.conf` and choose the MacTahoe icon theme in qt6ct.
Set Dolphin as the file manager with
`xdg-mime default org.kde.dolphin.desktop inode/directory`.

## Machine-specific configuration

- Dock pins ship with one starter entry. Hover an app tile and left-click its
  plus or minus badge to update the pin list.
- Put a wallpaper in `~/Pictures/Wallpapers/default.jpg`, or select an image
  in the wallpaper picker. Set the Hyprlock image path independently.
- Greeter installation is separate. Review the included greetd configuration
  and deploy the QML under `/etc/greetd/rice-greeter`. Supply a greeter-readable
  `lock-background.jpg` for the wallpaper. To start at the password field, set
  `defaultUser` and `accountLabel` in the deployed QML. You can place an optional
  `account-avatar.png` beside it.
- If you use GNOME Keyring, add its optional auth and session hooks to greetd's
  PAM stack so it can unlock the login keyring. The account and keyring passwords
  must match. Follow the [Arch keyring setup instructions](https://wiki.archlinux.org/title/GNOME/Keyring#PAM_step)
  and keep a known working login available.
- Portal routing expects the LXQt and wlr backends. Install and set up
  `niri-screenshare` separately for its window picker. The Secret portal entry
  refers to GNOME Keyring. Adjust it to match the credential provider in use.
- Run `systemctl --user daemon-reload` after installing user units.
- The screen recording helper expects OpenScreen. Review its shortcut before
  enabling it.

The repository contains config and shell assets. User credentials, notes,
history, real dock favorites, wallpapers, and display layout stay on the
source machine.
