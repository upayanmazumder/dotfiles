# dotfiles

My CachyOS setup on Sonder. The desktop starts with [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland). This repo keeps the files I change on top of it: Hyprland overrides, selected Quickshell changes, shell settings, system configuration, and scripts.

`home/` maps to `$HOME`, `etc/` maps to `/etc`, and `usr/` maps to `/usr` (my GRUB theme, plus my changes to the SDDM Silent theme). `scripts/` contains commands linked into `~/Scripts/bin`. Package lists live in `packages/`. I keep the end-4 base in its own checkout so updates to it do not get mixed with my overrides.

## Setup

Install CachyOS and the end-4 desktop framework first. The framework supplies `~/.config/hypr/hyprland/` and most of `~/.config/quickshell/ii/`. Check `docs/config-management.md` and the package lists before applying the files here.

```sh
./apply.sh --scripts
./apply.sh --configs
```

`--scripts` installs the command links. `--configs` copies files that do not exist yet. It leaves changed files alone, including root-owned files under `/etc`. To replace one reviewed home file, run `./apply.sh --replace-home PATH`. The script saves the old copy under `.apply-backups/`. Running `./apply.sh` with no option also installs the listed packages.

## Editing

Edit a file in `home/` or `etc/` and test it on the machine. Both sync scripts show live differences without copying them. Use `--pull` with a mirror-relative path to import one file after reviewing it. `docs/machine.md` records machine-specific behavior.

Keep private data outside Git. The hotspot reads its SSID and password from `~/.config/hotspot/credentials`, which must have mode `600`. Zed and other applications can also hold API keys in their live settings. Review every diff and scan the repository before publishing changes.

## What is not tracked

Credentials, API keys, SSH keys, kubeconfigs, Wi-Fi profiles, browser and Electron profiles, shell history, caches, application databases, `sudoers.d`, and `machine-id` stay on the machine. A few files are tracked with the secret removed. `home/setup-hotspot.sh` has a `CHANGE_ME_MIN_8_CHARS` placeholder, and `home/.config/plasma-nm` omits the hotspot password. The hotspot needs a sudoers rule for `create_ap`, which I do not publish. Wallpapers are not tracked either, but `config.json` refers to one by path.

Some tracked files depend on packages I install separately. `etc/pam.d/system-login` calls Howdy, so it only works with `howdy-bin`. `etc/fstab`, `mkinitcpio.conf` and `pacman.conf` fit this laptop, so read them before copying.

## License

GPL-3.0, because the Quickshell changes derive from end-4's GPL-3.0 code. See `LICENSE` and `THIRD_PARTY.md` for other sources and files I left out.
