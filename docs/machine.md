# Sonder configuration map

Sonder runs CachyOS with Hyprland. The login shell is fish. SDDM starts the active Hyprland session. Hyprland loads the end-4 `hyprland.lua` entry and then files under `hypr/custom/`. The session runs the Illogical Impulse Quickshell configuration with `qs -c ii`.

## Active sources

- This repository owns all managed links under `~/Scripts/bin`.
- `~/dev/upayanmazumder/dots-hyprland` is a fork of the upstream desktop base. Its upstream remote points to `end-4/dots-hyprland`.
- The live GRUB and SDDM themes exist, but their assets are not in this repository.
- A leftover `99-amdgpu-overdrive.conf` in the initramfs kept `ppfeaturemask` at `0xfff7ffff` after the drop-in was removed from `/etc`. Rebuild with `mkinitcpio -P` after changing modprobe drop-ins. With only `99-amdgpu-no-overdrive.conf` present, the driver reports `0xfff7bfff`.

Some live applications keep independent settings outside this curated mirror. Examples include Neovim, Atuin, GTK themes, and browser profiles. Review each file for secrets and generated state before adding it. Not every file under `~/.config` is safe to publish.

## Boundaries

This repository does not own package defaults, generated Quickshell state, browser profiles, credentials, personal images, or private service environment files. Selected systemd units can refer to private environment files, but those files must remain outside Git. Hardware-specific `/etc` files need review before installation on another machine. GRUB configuration and hooks require a separate boot check before deployment.

Hardware-specific files under `etc/` apply to this laptop (AMD Ryzen 7 7840U, MediaTek mt7921e Wi-Fi). Review them before using them on another machine.
