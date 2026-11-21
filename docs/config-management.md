# Configuration management

## Ownership

`home/` mirrors selected files in `$HOME`. `etc/` mirrors selected system files in `/etc`. The `end-4/dots-hyprland` checkout provides the Illogical Impulse base. This repository owns only user overlays, such as `hypr/custom/`, selected Quickshell modifications, and personal application settings. Do not copy the entire upstream tree into this repository. Check upstream licenses before including assets or code.

## Directions

Edit a tracked file in the checkout. Compare it with the corresponding live file before deployment. `./apply.sh --scripts` updates command links. `./apply.sh --configs` deploys home and system files. The default mode also installs packages. It can change boot, audio, and desktop behavior, so review each system change first.

`./sync-from-home.sh` previews differences. Import one reviewed file with `./sync-from-home.sh --pull .config/path/to/file`. It rejects private paths and obvious credential text. `./sync-from-etc.sh` handles already tracked system files. Inspect every diff and run a secret scan before committing.

The deploy script skips differing files. Apply one reviewed, non-private home file with `./apply.sh --replace-home PATH`. It first saves the former live file under `.apply-backups/`. Root-owned changes need separate review.

## Secrets and host data

Never commit passwords, API keys, SSH private keys, signing keys, OAuth stores, kubeconfigs, wireless profiles, generated databases, browser profiles, or local backups. Keep hotspot credentials in a local private source outside this checkout. Keep host addresses and tokens in local-only configuration when a public example is sufficient. Do not add `.apply-backups/` or an entire `$HOME` or `/etc` directory.

The live Zed settings contain a private API key, and the live rclone config contains a Google Drive client secret and token. Both files are tracked as sanitized copies: the Zed copy has an empty `context7_api_key` and a placeholder Ollama URL, and the rclone copy keeps the remote name and type only. Edit the live file to change the real values. Never copy either live file into the checkout. `sync-from-home.sh` refuses both paths. The rclone sync scripts contain no credentials and stay tracked as is.

The hotspot script reads two lines from `~/.config/hotspot/credentials`: SSID, then passphrase. The file has mode `600` and stays outside Git. The Quickshell toggle uses `status`, `stop`, `restart`, and `--daemon`. Status returns `0` for an active AP, `1` when stopped, and `2` when the daemon loses its AP channel. The button offers restart for state `2`. Restart recomputes the current upstream channel. No automatic network or suspend hook restarts the hotspot.

## End-4 base

Install end-4 from its upstream project and use its chosen revision as the base. Its `hyprland.lua` loads `hyprland/*` and then `custom/*`, so `custom/` is the stable user extension point. Quickshell runs as `qs -c ii` in the current session. Rebase local Quickshell changes onto the upstream version before deploying. Keep the patch and any required owned modules synchronized.

`patches/quickshell-ii-local.patch` records the tracked Quickshell overlays against upstream commit `cb1c428b`. It includes the selected desktop widgets and their compiled shader. Apply it from `~/.config/quickshell/ii/` with `git apply --binary /path/to/quickshell-ii-local.patch`. Use `git apply --check` first.

Regenerate the patch after changes to tracked Quickshell files. Copy the upstream tree to a scratch Git repository. Commit that baseline. Overlay the tracked files. Generate the patch with `git diff --cached --binary`.

The Hyprland base needs no patch, because upstream includes the `render_power` fix. Matugen overwrites generated color files and theme outputs. Do not track those files.

## Desktop widgets and lyrics

End-4 remains the upstream base. Selected widgets derive from `pctrade/end4-pC` commit `7538c66f2597959733c26a4ccccac1ebe6b4f56e`. `THIRD_PARTY.md` records their source and license.

The tracked preferences enable Media, Calendar, World Clock, and Resources. `Background.qml` loads them through `WidgetsLoader.qml`. Clock, Weather, and the existing visualizer retain their settings.

- Drag a widget to change its position. The `free` placement strategy stores its coordinates.
- Use the corner handle to resize widgets that support size modes.
- Use the World Clock settings button to select time zones.
- Resources shows CPU usage, RAM usage, and battery charge. Machines without a battery show swap usage instead.

The Media widget uses size mode `1x3` to display lyrics below its controls. Its lyrics button changes `background.widgets.media.showLyrics`. `media.showLyrics` also controls lyrics in the existing media popup.

Lyrics follow the active MPRIS player, including Spotify. The Python helper queries LRCLIB, then BetterLyrics when necessary. These services receive the track title, artist, and duration. No Spotify credentials are required. Songs without synchronized lyrics do not show timed lines.

Live preferences and saved personal data remain local. Do not copy unrelated preferences or personal content into this repository.

Run `/usr/lib/qt6/bin/qmllint --only-explicit-categories --syntax error` on changed QML files. Verify the running shell and the rendered widgets before committing.

## Nothing Liquid glass

The glass comes from `shlok-shinde/nothing-liquid`. The shell material uses dotfiles commit `c1c730608a55129ce07e407d365f3675d8d1f009`. The compositor plugin uses `shlok-shinde/hyprglass` commit `93dbe1907391b12699b57040ed694e4dc851a1e5`.

End-4 remains the base. Do not run the upstream installer over this overlay. It also changes unrelated shell behavior. The selected widgets, their layout, the wallpaper, and existing shortcuts remain independent of the glass.

`custom/general.lua` loads `custom/liquidglass.lua`. That file loads the plugin and restores saved settings. `services/LiquidGlass.qml` applies settings immediately and writes `~/.local/state/quickshell/user/generated/liquidglass.lua`. Do not track that generated file or the plugin binary.

Settings → Glass has separate controls for application windows and shell surfaces. Application settings apply globally, including terminals, browsers, messaging windows, and fullscreen windows. They control opacity, blur, grain, tint, colour, refraction, highlights, edges, and advanced glass effects. Balanced, Frosted, and Clear presets provide starting points. Individual controls allow custom settings. Balanced is the default. Select Frosted to add stronger blur, grain, tint, and frost. Window controls do not change the explicit bar, dock, panel, or desktop widget presets.

The saved window settings prioritize readable app content. Active opacity is `0.94` and inactive opacity is `0.92`. Fullscreen opacity remains `0.90`. Blur uses strength `2` with three iterations. Brightness is `1.00` and saturation is `1.08`. Adaptive dimming, self-sampling, and frost are disabled. Grain is `0.008`, and the pale tint has alpha `08`. The former `0.64` opacity faded text and controls. Its `1.20` brightness and stronger pale tint also reduced contrast against bright wallpaper.

Before the appearance change, the live configuration was copied to `~/.local/state/glass-backups/20261120-194704/config.json`. Backups remain local because the full configuration can contain private state. Shell glass settings and the plugin binary remain unchanged.

The later native transparency change has backups in `~/.local/state/glass-backups/20261120-native/`. This directory contains the preceding Kitty and shell configuration files.

The readability correction has backups in `~/.local/state/glass-backups/20261121-121035-contrast/`. It restores app opacity and reduces the pale tint without disabling glass.

Kitty uses native background opacity `0.55` to preserve glass without exposing too much wallpaper behind text. Dynamic background opacity is enabled. Reload the Kitty configuration to update existing transparent windows. Windows started with an opaque rendering surface can require a new terminal window. Whole-window opacity also affects text, while native background opacity does not. Game mode disables glass and forces compositor opacity to `1`, but Kitty retains native background transparency.

Darkly supplies Qt transparency through `kdeglobals` and `darklyrc`. Zed can also expose glass through its transparent theme. Whole-window opacity makes opaque application content translucent too, including its text. Increase opacity in Settings when text needs more contrast.

### Build the plugin

The current build targets Hyprland 0.57.2. The required compiler, headers, `make`, and Wayland development files are already installed on Sonder. Darkly is already listed as `darkly-bin` in `packages/aur.txt`.

```sh
src="$HOME/.local/share/nothing-liquid/source/hyprglass"
mkdir -p "$(dirname "$src")"
if [ ! -e "$src/.git" ]; then
    git clone https://github.com/shlok-shinde/hyprglass "$src"
fi
git -C "$src" checkout --detach 93dbe1907391b12699b57040ed694e4dc851a1e5
make -C "$src" clean
make -C "$src" -j2 HYPRGLASS_VERSION=nothing-liquid-93dbe19
mkdir -p "$HOME/.local/lib/nothing-liquid"
strip --strip-debug -o "$HOME/.local/lib/nothing-liquid/hyprglass.so.new" "$src/hyprglass.so"
mv "$HOME/.local/lib/nothing-liquid/hyprglass.so.new" "$HOME/.local/lib/nothing-liquid/hyprglass.so"
```

Rebuild after updates to Hyprland or its libraries, including hyprutils. Do not bypass the plugin's ABI guard. Save application work before restarting Hyprland.

Always declare `hl.plugin.load(plugin)` when the plugin file exists. Do not condition that declaration on `hl.plugin.hyprglass` being absent. Hyprland reconciles declarations after each configuration load. The conditional declaration caused repeated plugin unloads and reloads, then a crash.

Check the deployed configuration with `Hyprland --verify-config -c ~/.config/hypr/hyprland.lua`. Check `hyprctl configerrors` after a reload. `hyprctl -j hyprglass status` must report an active plugin, matching version, ready shaders, and active window and layer features.

The initial replacement has a private rollback copy under `.apply-backups/nothing-liquid-TIMESTAMP/`. Compare archived files with live files before restoring them. Do not replace newer layout or application settings with an older backup.

## Special state

Fish universal variables are machine state, not files to publish. The local setting `MISE_FISH_AUTO_ACTIVATE=0` prevents the vendor hook from changing PATH. Set it on a new installation with `set -U MISE_FISH_AUTO_ACTIVATE 0`. Keep personal wallpaper assets outside Git unless redistribution rights are clear.

The tracked Hyprlock configuration uses a solid background. The private photograph stays on the machine. The tracked Zed settings exclude private Context7 and Ollama values. Restore those settings through local-only configuration if needed.

Hyprlock media helpers use `playerctl`, ImageMagick (`magick`), and `curl`. End-4 may supply them. Verify them before enabling the helpers.

The system mirror does not contain the third-party GRUB theme `astronaut`, the SDDM theme `pixel-night-city`, or the SKLauncher JAR. Review these dependencies before installing the related files on another machine. The conflicting GPU drop-in is archived. The new driver mask applies after a reload or reboot, not to the running driver.

## Custom GRUB and ESP slots

Firmware entry `0002` loads `EFI/cachyos/grubx64-custom.efi`. Its prefix points to `/grub` on ESP UUID `0281-97BB`.
The active menu is `/boot/efi/grub/grub.cfg`, not `/boot/grub/grub.cfg`.
The menu reads `/boot/efi/grub/slot.cfg`. It currently selects `cachyos-esp-b`.

`usr/local/bin/cachyos-esp-boot-sync` publishes kernels to the inactive slot and updates both selectors.
Its Pacman hook runs after `linux-cachyos` updates. Keep both slots and the recovery entry.
`cachyos-grub-resync` embeds FAT, graphics, font, PNG, and Windows chainloader modules in the custom EFI image.
It copies existing astronaut assets to `/boot/efi/grub/themes/astronaut`.
The theme assets, kernels, initramfs files, and EFI binaries remain outside Git.

The firmware order starts with custom GRUB, then Windows, then the older CachyOS loader.
HP firmware can append device entries. Do not delete those entries to enforce a cosmetic list.
Do not run `grub-install` or regenerate the custom setup merely to deploy these mirrors.
Review the UUIDs and preserve the installed files before any boot deployment.
The normal `apply.sh --configs` mode skips boot scripts, boot hooks, boot defaults, and `boot/`.
Sonder keeps vendor generators `10_linux`, `30_os-prober`, `30_uefi-firmware`, `31_efi_bootnext`, and `41_snapshots-btrfs` non-executable.
The custom generator invokes selected vendor generators explicitly. Preserve these modes when restoring the setup.

## Automatic synchronization and agent changes

The standing rule in `home/.agents/AGENTS.md` covers AI-agent edits, not only package updates.
Agents must mirror relevant changes, verify them, scan for secrets, commit, and push during the same task.
Ask before adding a file when its relevance or publication safety is ambiguous.

`etc/dotfiles-autosync.json` lists reviewed live paths and repository destinations.
Systemd watches those files and collects changes after writes. A minute timer retries missed events and failed publication.
Unknown paths require review and explicit enrollment. The collector never copies entire directories or deletes missing files from Git.
Credential checks, symlink rejection, size limits, and Gitleaks block unsafe snapshots.
The collector runs root-owned installed code. The publisher runs as `upayan`, with a 256 MiB memory limit and no swap.

Publication uses an isolated bare repository under `~/.local/state/dotfiles-autosync/repo.git`.
It does not modify this checkout, its index, or pending edits. It never force-pushes.
Concurrent remote changes to managed files block publication until reviewed. Network failures retain the snapshot for another attempt.
Fetch and merge `origin/main` before subsequent work when the publisher advanced the remote.
Do not overwrite remote edits with stale live copies.

Install the reviewed worker as `/usr/local/lib/dotfiles-autosync/worker.py`.
Install Gitleaks there as `gitleaks`, owned by root.
Install the JSON manifest in `/etc` and the `dotfiles-autosync*` units in `/etc/systemd/system`.
Create `~/.local/state/dotfiles-autosync` as `upayan` before starting the publisher.
Enable `dotfiles-autosync.path` and `dotfiles-autosync.timer` after `systemctl daemon-reload`.
Inspect failures with `journalctl -u 'dotfiles-autosync-*'`.
No credentials belong in the manifest. Git uses the user's existing credential helper.

## Memory-pressure incident

At 01:49:37 on 2026-11-20, the kernel killed `omp` PID 21927 after global memory exhaustion.
It held 6,590,160 KiB of anonymous RAM and 6,468,514 swapped pages. Free swap reached 192 KiB.
The desktop stalled during memory reclaim. Memory recovered after the kill.
The journal does not identify the allocation that caused OMP's growth. It provides no GPU-reset evidence for that interval.
Do not attribute this incident to GRUB or the corrected Hyprland plugin declaration.

## Tailscale DNS

NetworkManager uses `dns=systemd-resolved`. `/etc/resolv.conf` must link to `/run/systemd/resolve/stub-resolv.conf`, not remain a regular file.

Repair the link:

```sh
sudo ln -sfn /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
sudo systemctl restart systemd-resolved
sudo systemctl restart NetworkManager
sudo systemctl restart tailscaled
```

Restarting NetworkManager briefly interrupts network connections. Restart Tailscale last so it detects the repaired configuration.
Changing preferences with `tailscale up` does not repeat DNS manager detection.

Check `tailscale status` for health warnings. Test a peer with `getent ahostsv4 PEER` and `tailscale ping --c 1 PEER`.

## Remote access

Sonder advertises Tailscale SSH on the tailnet and also runs Tailscale on Tailscale IP `100.94.169.60`, hostname `sonder.tail92723c.ts.net`.
Sonder no longer accepts subnet routes. `RouteAll` is false, no exit node is set, and no routes are advertised.
Normal internet traffic keeps the wlan0 default route.

OpenSSH listens only on loopback port 22 and the two Tailscale addresses on port 2222, from `etc/ssh/sshd_config.d/10-sonder-tailnet.conf`.
Tailscale SSH keeps tailnet port 22. `etc/systemd/system/sshd.service.d/10-tailscale.conf` orders sshd after tailscaled so the tailnet addresses exist at boot.
UFW allows TCP 2222 and 5900 only on `tailscale0`. KDE Connect and hotspot rules stay unchanged.

Add the Android public key to `~/.ssh/authorized_keys`. Keep password authentication until a phone key login succeeds, then set `PasswordAuthentication no` in the same drop-in.

Development servers reach the phone through foreground Tailscale Serve raw TCP forwarding:

```sh
tailscale serve --tcp=13000 tcp://127.0.0.1:3000
tailscale serve --tcp=15173 tcp://127.0.0.1:5173
tailscale serve --tcp=18000 tcp://127.0.0.1:8000
tailscale serve --tcp=18080 tcp://127.0.0.1:8080
```

Stop each with Ctrl+C. Do not use Funnel or `--bg`. Bind development servers to `127.0.0.1`.

`scripts/screenshare/toggle.sh` binds WayVNC to the current Tailscale address only and serves VeNCrypt TLS on 5900.
WayVNC 0.10 fills capture buffers only after a `zwlr_output_power_v1` event, and Hyprland emits that event only on a real DPMS change.
`warmup.py` connects with the wayvnc credentials, cycles DPMS, and exits; WayVNC serves live frames to later clients.
Without the warm-up a client sees a uniform grey frame. The warm-up briefly blanks the local display.
WayVNC credentials and TLS files stay in `~/.config/wayvnc/` and are never tracked.

Taildrop files arrive with `tailscale file get --conflict=rename ~/Downloads/Taildrop`.
Syncthing is not installed because the official Android app is discontinued. Jellyfin is not installed.

The VPS is reachable at `100.96.250.81` with the existing Hetzner key. The k3s API listens on 6443. No Raspberry Pi appears on the tailnet.

Rollback:

```sh
tailscale set --accept-routes=true          # restore subnet-route acceptance
sudo rm /etc/ssh/sshd_config.d/10-sonder-tailnet.conf
sudo rm -rf /etc/systemd/system/sshd.service.d
sudo systemctl daemon-reload && sudo systemctl restart sshd
sudo ufw delete allow in on tailscale0 to any port 2222 proto tcp
sudo ufw delete allow in on tailscale0 to any port 5900 proto tcp
sudo ufw allow 5900/tcp                     # only to restore previous LAN VNC access
```
