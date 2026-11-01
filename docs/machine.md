# Sonder configuration map

Sonder runs CachyOS with Hyprland. The login shell is fish. SDDM starts the active Hyprland session. Hyprland loads the end-4 `hyprland.lua` entry and then files under `hypr/custom/`. The session runs the Illogical Impulse Quickshell configuration with `qs -c ii`.

## Active sources

- This repository owns all managed links under `~/Scripts/bin`.
- `~/dev/upayanmazumder/dots-hyprland` is a fork of the upstream desktop base. Its upstream remote points to `end-4/dots-hyprland`.
- The live GRUB theme is the third-party `astronaut` theme. The live SDDM theme is the third-party `pixel-night-city` theme. Neither is in this repository. The tracked `sonder` GRUB theme and the Silent `sonder.conf` profile are my own and are currently unused.
- A leftover `99-amdgpu-overdrive.conf` in the initramfs kept `ppfeaturemask` at `0xfff7ffff` after the drop-in was removed from `/etc`. Rebuild with `mkinitcpio -P` after changing modprobe drop-ins. With only `99-amdgpu-no-overdrive.conf` present, the driver reports `0xfff7bfff`.
- The speaker volume range is 0 to 153%, which is the pavucontrol maximum. 153% is +11.08 dB of gain after EasyEffects. The `Speakers-Night` and `Speakers-Game` limiters have `gain-boost` off and a -12 dBFS ceiling, so a full-scale peak lands near -0.9 dBFS at 153%. With `gain-boost` on, the limiter ceiling stays at 0 dBFS for any threshold, and gain above 100% clips. `ee-volume.sh` caps every other sink at 100%, because the Bluetooth and DAC presets keep a 0 dBFS ceiling. To change the maximum, change `MAX_SPEAKER_PCT` in `ee-volume.sh`, `Audio.maxVolume` in `Audio.qml`, and the limiter threshold in both speaker presets.

Some live applications keep independent settings outside this curated mirror. Examples include Neovim, Atuin, GTK themes, and browser profiles. Review each file for secrets and generated state before adding it. Not every file under `~/.config` is safe to publish.

## Boundaries

This repository does not own package defaults, generated Quickshell state, browser profiles, credentials, personal images, or private service environment files. Selected systemd units can refer to private environment files, but those files must remain outside Git. Hardware-specific `/etc` files need review before installation on another machine. GRUB configuration and hooks require a separate boot check before deployment.

Hardware-specific files under `etc/` apply to this laptop (AMD Ryzen 7 7840U, MediaTek mt7921e Wi-Fi). Review them before using them on another machine.
