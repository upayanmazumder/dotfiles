# Sonder configuration map

Sonder runs CachyOS with Hyprland. The login shell is fish. SDDM starts the active Hyprland session. Hyprland loads the end-4 `hyprland.lua` entry and then files under `hypr/custom/`. The session runs the Illogical Impulse Quickshell configuration with `qs -c ii`.

## Active sources

- This repository owns all managed links under `~/Scripts/bin`.
- `~/dev/upayanmazumder/dots-hyprland` is a fork of the upstream desktop base. Its upstream remote points to `end-4/dots-hyprland`.
- The live GRUB theme is the third-party `astronaut` theme. The live SDDM theme is the third-party `pixel-night-city` theme. Neither is in this repository. The tracked `sonder` GRUB theme and the Silent `sonder.conf` profile are my own and are currently unused.
- A leftover `99-amdgpu-overdrive.conf` in the initramfs kept `ppfeaturemask` at `0xfff7ffff` after the drop-in was removed from `/etc`. Rebuild with `mkinitcpio -P` after changing modprobe drop-ins. With only `99-amdgpu-no-overdrive.conf` present, the driver reports `0xfff7bfff`.
- The speaker volume range is 0 to 153%, which is the pavucontrol maximum. 153% is +11.08 dB of gain after EasyEffects. The `Speakers-Night` and `Speakers-Game` limiters have `gain-boost` off and a -12 dBFS ceiling. `Speakers-Night` uses a -16 LUFS autogain target and a 60 ms limiter release, so a full-scale peak lands near -0.9 dBFS at 153%. With `gain-boost` on, the limiter ceiling stays at 0 dBFS for any threshold, and gain above 100% clips. `ee-volume.sh` caps every other sink at 100%, because the Bluetooth and DAC presets keep a 0 dBFS ceiling. To change the maximum, change `MAX_SPEAKER_PCT` in `ee-volume.sh`, `Audio.maxVolume` in `Audio.qml`, and the limiter threshold in both speaker presets.

Some live applications keep independent settings outside this curated mirror. Examples include Neovim, Atuin, GTK themes, and browser profiles. Review each file for secrets and generated state before adding it. Not every file under `~/.config` is safe to publish.

## Boundaries

This repository does not own package defaults, generated Quickshell state, browser profiles, credentials, personal images, or private service environment files. Selected systemd units can refer to private environment files, but those files must remain outside Git. Hardware-specific `/etc` files need review before installation on another machine. GRUB configuration and hooks require a separate boot check before deployment.

Hardware-specific files under `etc/` apply to this laptop (AMD Ryzen 7 7840U, MediaTek mt7921e Wi-Fi). Review them before using them on another machine.

## Memory and swap

The root btrfs filesystem spans three partitions (`devid` 1, 2, 3 on `nvme0n1p5`, `p6`, `p7`). The kernel refuses a swapfile on a multi-device btrfs filesystem, so `swapon` returns `EINVAL` for every swapfile on that filesystem.

Swap is zram plus one partition:

- `zram0`: `zram-size = ram`, zstd, priority 100. Configured by `zram-generator`.
- `nvme0n1p8`: 16 GiB, priority 10, Linux swap type `0657FD6D-A4AB-43C4-84E5-0933C84B4F4F`. Created 2026-11-10.

The partition came from shrinking `nvme0n1p6` online. Btrfs refuses that shrink on a nearly full filesystem: relocation needs allocatable workspace, and the only unallocated space sits above the new boundary. Free space inside chunks is not enough. The sequence that works is: `btrfs balance start -dusage=50 -musage=50 /` to compact, then `btrfs filesystem resize 1:-16G /`, then `parted resizepart 6`, then `mkpart`.

Do not add a disk swapfile through a loop device. Under pressure, memory reclaim waits for the loop worker while the loop worker waits for an allocation, and the machine freezes with no log entry. That loop-backed 16 GiB swapfile existed from 2026-11-08 17:27 to 2026-11-10 00:42 and produced six hard hangs that needed a forced power-off.

## Crash capture

`panic=10`, `hung_task_panic=1`, and `log_buf_len=8M` are on the kernel command line. A task blocked for 120 s panics, and the machine reboots after 10 s. Hard-lockup detection needs the three sysctls in `/etc/sysctl.d/99-lockup-detect.conf`. `cachyos-settings` sets `kernel.nmi_watchdog = 0` for power saving, and this kernel does not accept `hardlockup_panic=` on the command line. `systemd-journald` runs with `SyncIntervalSec=1s`, so the last messages survive a power-off.

## Resume from swap

`resume=UUID=bc715af5-53ed-470a-8033-48b4cd1858bb` on the kernel command line points at the 16 GiB swap partition. The `resume` hook in `mkinitcpio.conf` loads that swap before the root filesystem. Rebuild the initramfs with `mkinitcpio -P` after a change to either file.

## Screen sharing

`~/.config/quickshell/ii/scripts/screenshare/toggle.sh` starts `wayvnc` on TCP 5900 for the focused monitor. It writes `screenshare.pid` and `screenshare.log` under `$XDG_RUNTIME_DIR`, copies `vnc://IP:5900` to the clipboard, and prints `1` or `0` for the bar icon. The script prefers the `ap0` hotspot address, then the default route address.

Three tracked files carry the bar button: `showScreenShare` in `Config.qml`, `screenshareToggleScriptPath` in `Directories.qml`, and the Loader in `BarContent.qml`. The ufw rules allow TCP 5900 from any source, so the session is reachable by every host that can route to this machine. Stop the toggle when the port must stay closed.

## Audio routing

The system default sink stays on the hardware output, and EasyEffects keeps its virtual sink in front of applications. `audio-output-switch.sh` records intent in `~/.config/audio-output-switch/route`. `easyeffects-bt-relink.sh` converges the real links when the EasyEffects chain exists, and `lib/audio-output-routing.sh` repairs a stale route under `flock`. Links count as valid only as one `output_FL` and one `output_FR` pair.

`easyeffects-bt-relink.service` runs with `KillMode=control-group`. EasyEffects starts on its own, so stopping the unit stops only the routing helpers. Volume keys cap every sink other than the speaker at 100%.

## Prompt and tracked copies

The fish prompt is Tide, which loads from the fish functions directory. The `oh-my-posh` themes stay tracked for reuse, but no file loads them.

`home/.config/zed/settings.json`, `home/.config/rclone/rclone.conf`, and the rclone sync scripts are tracked. The Zed copy has an empty Context7 key and a placeholder Ollama URL. The rclone copy keeps only the remote name and type, with no client secret or token. Set the real values in the live files. Never copy a live Zed or rclone file into the checkout.

`home/.config/Code/extensions.txt` and `home/.config/dconf/user.dump` stay tracked as reinstall references. The live machine no longer has either file.
