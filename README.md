# Niri desktop dotfiles

A portable Niri desktop with a Quickshell bar, Control Center, dock, Spotlight,
notification center, power menu, clipboard, and wallpaper
picker. It also includes the Hyprlock theme, Dolphin styling, a btop task manager
launcher, and the greetd theme source.

## Install

On a Niri setup, review the files under `home/` and run `./install.sh`.
It copies missing files into your home directory and reports differing files
it skipped. You can pass a destination directory to stage everything first.
Use a conventional XDG directory layout and add `~/.local/bin` to your
session's `PATH`.

The core setup uses Niri, Quickshell, Python 3, PipeWire/WirePlumber,
NetworkManager, and wl-clipboard. Control Center uses brightnessctl for the
backlight, BlueZ for Bluetooth, and GSettings with the GNOME desktop schemas
for appearance. Optional features use cliphist, swaybg,
hyprlock, swayidle, swaylock, Dolphin, qt6ct, Kitty, btop, FeatherPad, and
khal. Swaylock locks the screen before sleep. Check the Niri bindings before
using them. Terminal, screenshot, and recording
shortcuts point to specific apps that you can swap for your own.

Install the [MacTahoe icon theme](https://github.com/vinceliuice/MacTahoe-icon-theme)
for the matching desktop icons. The shell uses Aptos Narrow when installed.
Aptos files and the desktop photo are supplied separately.

For Dolphin, set the qt6ct palette path to
`~/.config/dolphin/palette.conf` and choose the MacTahoe icon theme in qt6ct.
Set Dolphin as the file manager with
`xdg-mime default org.kde.dolphin.desktop inode/directory`.

## Emoji picker

`Mod+.` opens it, and so does the Emoji command in Spotlight. It stays open
while you pick. It needs `wtype`, wl-clipboard, and an emoji font such as
`noto-fonts-emoji`. It draws whichever font fontconfig picks for `emoji`.

Foot, Kitty, and Ghostty get the emoji typed directly. Other apps get a paste,
because Chromium drops most typed emoji. The paste borrows the clipboard, then
restores one format of what was there. To add another terminal, put its app ID
in `insert-emoji.sh`.

The emoji list in `emojis.json` comes from
[emojibase-data](https://github.com/milesj/emojibase) 17.0.0, under the license
in `emojis.LICENSE`.

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
- The screen recording helper expects OpenScreen, flock, and notify-send. Review its shortcut before
  enabling it.

The repository contains config and shell assets. User credentials, notes,
history, real dock favorites, wallpapers, and display layout stay on the
source machine.
