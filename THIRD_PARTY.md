# Third-party material

This repo is licensed under GPL-3.0 (see `LICENSE`). Several files come from other projects.

## end-4/dots-hyprland

Files under `home/.config/quickshell/ii/` and `patches/quickshell-ii-local.patch` are modified copies of, or additions to, [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland), which is GPL-3.0. The patch was made against upstream commit `301185c7`. Upstream copyright notices in those files stay in place.

`home/.config/quickshell/ii/services/MprisController.qml` has a header saying it comes from [outfoxxed/nixnew](https://git.outfoxxed.me/outfoxxed/nixnew). The header says that code has no license but the author allows redistribution. Keep the header intact.

## Oh My Posh themes

`home/.config/oh-my-posh/themes/night-owl.omp.json` and `catppuccin.omp.json` are modified copies of themes shipped with [Oh My Posh](https://github.com/JanDeDobbeleer/oh-my-posh), which is MIT licensed. The license text is in `licenses/oh-my-posh-MIT.txt`.

## BonaFides Rounded Kvantum

`home/.config/Kvantum/BonaFides-Rounded-Kvantum/` is the unmodified theme by l4k1 (L4ki), from [L4ki/BonaFides-Plasma-Themes](https://github.com/L4ki/BonaFides-Plasma-Themes), which is GPL-3.0. It supplies the translucent and blurred Qt look, including Dolphin's glass. `kvantum.kvconfig` selects it.

## Cava shaders

`home/.config/cava/shaders/orion_*.frag` are by rezky_nightky and carry an MIT SPDX header. Keep the headers intact.

## DolphinGlass color scheme

`home/.local/share/color-schemes/DolphinGlass.colors` derives from a KDE color scheme and keeps its LGPL-2.0-or-later SPDX header with the KDE authors' names.

## SDDM Silent theme

`usr/share/sddm/themes/silent/` holds only my changes to the [SilentSDDM](https://github.com/uiriansan/SilentSDDM) theme (GPL-3.0-or-later): a `sonder.conf` profile, a modified `metadata.desktop`, and one background image. Install the theme from the `sddm-silent-theme` package first.

## Images

`home/.config/hypr/hyprlock/sonder-mountain-4k.jpg`, the matching SDDM background, and the GRUB theme background under `usr/share/grub/themes/sonder/` are images I chose for my own setup. Their original authors and licenses are not recorded here. Remove them if you reuse this repo and cannot confirm the rights.
