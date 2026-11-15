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

The hotspot script reads two lines from `~/.config/hotspot/credentials`: SSID, then passphrase. The file has mode `600` and stays outside Git. The Quickshell toggle calls `~/Scripts/bin/hotspot` with `status`, `stop`, and `--daemon`. There is no sleep-resume hook, because a root hook cannot read the user-owned credential safely. Restart the hotspot by hand after suspend.

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

## Special state

Fish universal variables are machine state, not files to publish. The local setting `MISE_FISH_AUTO_ACTIVATE=0` prevents the vendor hook from changing PATH. Set it on a new installation with `set -U MISE_FISH_AUTO_ACTIVATE 0`. Keep personal wallpaper assets outside Git unless redistribution rights are clear.

The tracked Hyprlock configuration uses a solid background. The private photograph stays on the machine. The tracked Zed settings exclude private Context7 and Ollama values. Restore those settings through local-only configuration if needed.

Hyprlock media helpers use `playerctl`, ImageMagick (`magick`), and `curl`. End-4 may supply them. Verify them before enabling the helpers.

The system mirror does not contain the third-party GRUB theme `astronaut`, the SDDM theme `pixel-night-city`, or the SKLauncher JAR. Review these dependencies before installing the related files on another machine. The conflicting GPU drop-in is archived. The new driver mask applies after a reload or reboot, not to the running driver.
