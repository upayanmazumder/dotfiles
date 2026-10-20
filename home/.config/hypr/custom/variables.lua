-- Overrides for ~/.config/hypr/hyprland/variables.lua, which is
-- framework-owned and replaced on every dots-hyprland update. That file says
-- to copy what you want to change into this one; this is that file.
--
-- Upstream defines each app as a `launch_first_available.sh 'a' 'b' 'c'`
-- chain and tries the candidates in order. On this machine several chains
-- had no installed candidate at all, which made the corresponding keybind
-- silently do nothing, and others only resolved after 1-2 failed lookups:
--
--   SUPER+X          textEditor     kate / gnome-text-editor / emacs
--                                   -> none installed, bind was fully DEAD
--   CTRL+SUPER+
--   SHIFT+ALT+W      officeSoftware wps / onlyoffice / libreoffice
--                                   -> only the last candidate exists
--   CTRL+SHIFT+Esc   taskManager    gnome-system-monitor /
--                                   plasma-systemmonitor / btop
--                                   -> only the last candidate exists
--   SUPER+Return     terminal       foot / kitty / ...
--                                   -> foot not installed, kitty is 2nd
--
-- Pinning them to what is actually installed removes the dead bind and the
-- wasted lookups. Revisit if any of these apps are installed/removed later.

terminal       = "kitty -1"
codeEditor     = "zeditor"
textEditor     = "zeditor"    -- was dead (kate/gnome-text-editor/emacs); then
                              -- VS Code 2026-08..09-16; now Zed. Binary is
                              -- `zeditor`, NOT `zed` -- Arch's zed package
                              -- installs /usr/bin/zeditor.
officeSoftware = "libreoffice"
taskManager    = "kitty -1 fish -c btop"
fileManager    = "gio launch $HOME/.local/share/applications/org.kde.dolphin.desktop"

browser = "/usr/bin/thorium-browser-avx2" -- wrapper reads thorium-flags.conf.
-- Dolphin uses the same desktop entry for SUPER+E and Quickshell.
-- The entry selects its dark Qt palette and Kvantum theme.
-- The other upstream chains keep their first installed candidate.
--
-- workspaceGroupSize is left at upstream's 10.
