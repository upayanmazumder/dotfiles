# Candidate Packages

Software evaluated as potentially useful but not yet installed or a
deliberate decision either way. When the user asks "what should I
install" or a system change touches one of these areas, check here first
instead of re-deriving from scratch. Update this file's status when a
decision is made (installed -> move to `packages/*.txt` and delete the
row here; rejected -> mark Rejected with a one-line reason, keep the row
so it isn't re-suggested).

Surveyed 2026-08-07: Windows-builtin features Linux/Sonder lacked an
equivalent for. Already-covered gaps (file search via baloo, clipboard
history via cliphist, snipping tool via grim+slurp+swappy, Task Manager
via btop/htop, File History via snapper) are intentionally omitted below
-- see `docs/machine.md` for the full covered list.

| Feature gap | Package | Repo | Status |
|---|---|---|---|
| RDP/VNC client (`mstsc`) | `remmina` | official | Pending decision |
| VM manager (Hyper-V/Windows Sandbox) | `virt-manager` + `qemu-desktop` + `libvirt` | official | Pending decision |
| Print spooler + print-to-PDF | `cups` + `cups-pdf` | official | Pending decision -- currently nothing on Sonder can print at all |
| Bluetooth settings GUI | `blueman` | official | Pending decision -- currently CLI-only via `bluetoothctl` |
| Bootable USB creator (better than Rufus) | `ventoy` | AUR | Pending decision |
| System-wide touchpad gestures | `touchegg` + `touche` (GUI) | official/AUR | Rejected -- touchegg device grab blocks Hyprland's compositor-level gesture tracking; Hyprland 0.56 native gesture system (continuous volume, workspace swipes, fullscreen) is sufficient |
| OneDrive native mount | `onedriver` | AUR | Pending decision -- only relevant if OneDrive is actually used; `rclone` (installed) covers it generically |
| Disk usage GUI (WinDirStat-style treemap) | `filelight` | official | Pending decision -- `dust`/`dua-cli` (installed) cover the CLI case |
| Screen magnifier (accessibility) | `kmag` | official | Pending decision |
| Character map | `gucharmap` | official | Pending decision |
| Code editor (replace Electron VS Code) | `zed` | official | **Installed 2026-09-16** -- see `docs/machine.md` "Editor: Zed". Binary is `zeditor`. VS Code kept alongside for C# DevKit, `.ipynb` editing and Dev Containers, which Zed cannot do. |
| Modal/terminal editor | `helix` | official | Rejected -- no plugin system, so no notebooks, no C#, thin DAP. `neovim` is already installed and covers this niche better if a terminal editor is ever wanted. |
| PDF viewer (for opening PDFs from Zed/Dolphin) | `zathura` + `zathura-pdf-poppler` | official | **Installed 2026-09-17** -- minimalistic, vim-keys, tiling-friendly; picked over `okular`/`evince` since nothing else on this machine needed the KDE/GNOME PDF stack. **Default handler changed 2026-09-20 to Chrome** via `xdg-mime default com.google.Chrome.desktop application/pdf` -- zathura remains installed but unused. |
| GUI text editor (`SUPER+X`) | `kate` | official | Rejected -- `zeditor` now serves both `codeEditor` and `textEditor`; adding Kate would mean a second editor to theme and track for no new capability. |
| CLI for Vercel deployments | `vercel` | npm / AUR | **Installed 2026-09-22 via npm** (v59.25.0) -- official Vercel-recommended method per https://vercel.com/docs/cli. Installed at `~/.npm-global/bin/vercel`. AUR package `vercel` also exists but builds from npm source. |
| Slack desktop client | `slack-desktop` | AUR | **Built 2026-09-22, pending installation** -- AUR package built successfully (v4.52.155-1, 105MB at `~/.cache/paru/clone/slack-desktop/`). Installation blocked by sudo authentication requirement in current context. Can be installed manually via `sudo pacman -U ~/.cache/paru/clone/slack-desktop/slack-desktop-4.52.155-1-x86_64.pkg.tar.zst` or by re-running `paru -S slack-desktop` in an interactive terminal. |
