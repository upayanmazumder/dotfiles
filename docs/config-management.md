# Configuration management

## Ownership

`home/` mirrors selected files in `$HOME`. `etc/` mirrors selected system files in `/etc`. The `end-4/dots-hyprland` checkout provides the Illogical Impulse base. This repository owns only user overlays, such as `hypr/custom/`, selected Quickshell modifications, and personal application settings. Do not copy the entire upstream tree into this repository. Check upstream licenses before including assets or code.

## Directions

Edit a tracked file in the checkout. Compare it with the corresponding live file before deployment. `./apply.sh --scripts` updates command links. `./apply.sh --configs` deploys home and system files. The default mode also installs packages. It can change boot, audio, and desktop behavior, so review each system change first.

`./sync-from-home.sh` previews differences. Import one reviewed file with `./sync-from-home.sh --pull .config/path/to/file`. It rejects private paths and obvious credential text. `./sync-from-etc.sh` handles already tracked system files. Inspect every diff and run a secret scan before committing.

The deploy script skips differing files. Apply one reviewed, non-private home file with `./apply.sh --replace-home PATH`. It first saves the former live file under `.apply-backups/`. Root-owned changes need separate review.

## Secrets and host data

Never commit passwords, API keys, SSH private keys, signing keys, OAuth stores, kubeconfigs, wireless profiles, generated databases, browser profiles, or local backups. Keep hotspot credentials in a local private source outside this checkout. Keep host addresses and tokens in local-only configuration when a public example is sufficient. Do not add `.apply-backups/` or an entire `$HOME` or `/etc` directory.

The live Zed settings contain a private API key. The tracked settings must not pick it up through synchronization. A scanner cannot prove the absence of all secrets, so read every diff.

The hotspot script reads two lines from `~/.config/hotspot/credentials`: SSID, then passphrase. The file has mode `600` and stays outside Git. The Quickshell toggle calls `~/Scripts/bin/hotspot` with `status`, `stop`, and `--daemon`. There is no sleep-resume hook, because a root hook cannot read the user-owned credential safely. Restart the hotspot by hand after suspend.

## End-4 base

Install end-4 from its upstream project and use its chosen revision as the base. Its `hyprland.lua` loads `hyprland/*` and then `custom/*`, so `custom/` is the stable user extension point. Quickshell runs as `qs -c ii` in the current session. Rebase local Quickshell changes onto the upstream version before deploying. Keep the patch and any required owned modules synchronized.

## Special state

Fish universal variables are machine state, not files to publish. The local setting `MISE_FISH_AUTO_ACTIVATE=0` prevents the vendor hook from changing PATH. Set it on a new installation with `set -U MISE_FISH_AUTO_ACTIVATE 0`. Keep personal wallpaper assets outside Git unless redistribution rights are clear.

The tracked Hyprlock configuration uses a solid background. The private photograph stays on the machine. The tracked Zed settings exclude private Context7 and Ollama values. Restore those settings through local-only configuration if needed.

Hyprlock media helpers use `playerctl`, ImageMagick (`magick`), and `curl`. End-4 may supply them. Verify them before enabling the helpers.

The system mirror does not contain the active Sonder GRUB theme, SDDM theme assets, or SKLauncher JAR. Review these dependencies before installing the related files on another machine. The conflicting GPU drop-in is archived. The new driver mask applies after a reload or reboot, not to the running driver.
