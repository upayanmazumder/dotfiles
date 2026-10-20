# Package Management

## Installing something new

1. Install it for real: `sudo pacman -S --needed <pkg>` (official repo) or
   `paru -S --needed <pkg>` (AUR). Verify it actually works before
   touching the repo -- don't record a package you haven't confirmed
   installs and runs cleanly.
2. Add it to the right file under `packages/`:
   - `packages/pacman.txt` -- official repo, no hardware dependency.
   - `packages/aur.txt` -- AUR, no hardware dependency.
   - `packages/hardware.txt` -- Sonder-specific hardware packages
     (amdgpu/vulkan/audio-codec/etc.). Rare to add to; most new software
     goes in the two files above.
   - Keep each file sorted, one package per line, no inline comments next
     to entries (header comment block at top only).
3. `git add packages/*.txt && git commit -m "..." && git push`.

Alternatively, after a session of installing several things: run
`./check-packages.sh` from the repo root, review the output, and add the
genuinely-new entries (see exclusions below) to the right `.txt` file in
one pass.

## What NOT to add, even though `check-packages.sh` will flag it

`check-packages.sh` diffs against the *entire* explicit/foreign package
list, which includes categories this repo deliberately excludes. Do not
add:

- OS-installer-scope packages: `base`, `base-devel`, `linux-cachyos*`,
  `linux-firmware`, `cachyos-*` (branding/tooling/mirrorlists/kernel
  manager), `grub*`, `mkinitcpio`, `sddm*`, `plymouth`, `os-prober`,
  filesystem tools (`btrfs-progs`, `xfsprogs`, `dosfstools`, `ntfs-3g`,
  etc.), network stack (`networkmanager*`, `iwd`, `bluez*`, `dnsmasq`,
  `wpa_supplicant`, etc.), hardware-detection utilities (`dmidecode`,
  `hwinfo`, `usbutils`, `lsscsi`, etc.). CachyOS's installer owns these;
  reinstalling them here risks fighting its own choices.
- `illogical-impulse-*` (any of them) -- local PKGBUILDs the
  `dots-hyprland` framework's own `./setup install` builds itself from
  bundled sources. They show up as "foreign" to pacman identically to a
  real AUR package, but `paru -S illogical-impulse-*` will fail with
  "target not found" -- confirmed breaking Sonder's bootstrap once
  (2026-08-03), do not repeat that mistake.

If genuinely unsure whether something is OS-scope vs a real addition,
check `pacman -Qi <pkg>` for `Installed From` and reason about whether a
fresh CachyOS install already ships it -- if yes, it's not this repo's
job to track it.

## Removing a package

Mirror the add flow: `sudo pacman -Rns <pkg>` (or `paru -Rns`), then
delete the line from the relevant `packages/*.txt`, commit.

## `apply.sh` behavior

`./apply.sh` (or `./apply.sh --packages`) runs, in order:

```sh
sudo pacman -S --needed --noconfirm $(packages/pacman.txt entries)
sudo pacman -S --needed --noconfirm $(packages/hardware.txt entries)
paru -S --needed --noconfirm $(packages/aur.txt entries)   # skipped if paru missing
```

It is idempotent -- re-running installs nothing new if the lists haven't
changed. This is the command to run after `git pull` if `packages/*.txt`
changed upstream (e.g. from another session).
