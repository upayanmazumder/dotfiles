-- User window/workspace rules. Loads AFTER ~/.config/hypr/hyprland/rules.lua
-- (framework-owned, replaced on every dots-hyprland update), so this is where
-- user rules belong.
--
-- 2026-09-15: added semantic workspace pins (1 code / 2 browser / 3 terminal
-- / 4 comms / 5 media) plus "persistent" workspaces 1-5.
-- 2026-09-16: both removed. The terminal pin in particular fought the
-- "terminal beside my code" workflow (flagged as a likely annoyance when it
-- was added), and with the pins gone the persistent rules were just five
-- always-on slots in the bar advertising a semantic layout that no longer
-- existed. Back to stock illogical-impulse behaviour: windows open wherever
-- you are, and empty workspaces stop existing.
-- Scratchpad placement below is unrelated and kept.

-- ── Scratchpad placement ────────────────────────────────────────────────
-- Scratchpad windows are routed to their special workspace declaratively
-- here rather than with an `[workspace special:x silent]` prefix on the
-- exec. Reason: Hyprland 0.56's Lua config layer evaluates dispatch
-- arguments as Lua, so the classic bracket-prefix string is not a reliable
-- way to place a spawned window any more.
--
-- The classes are distinct from plain "kitty" on purpose: the scratchpad
-- keybinds spawn `kitty --class kitty-scratch` / `kitty-notes`, so only
-- those windows are captured here and ordinary kitty windows keep opening
-- wherever you already are.
hl.window_rule({ match = { class = "^(kitty-scratch)$" }, workspace = "special:term silent" })
hl.window_rule({ match = { class = "^(kitty-notes)$" },   workspace = "special:notes silent" })

-- ── Glass for Zed ───────────────────────────────────────────────────────
-- The framework's hyprland/rules.lua disables blur on *every* window
-- (`class = ".*"` -> no_blur = true) and only blurs layer surfaces (bar,
-- launcher, notifications). Zed's "Matugen Glass" theme is semi-transparent
-- (editor pane 65%, chrome 75-95%), so without re-enabling blur here the
-- editor would be plainly see-through rather than frosted.
--
-- This file loads after the framework's, so this rule wins. Blur params come
-- from hyprland/general.lua (size 10, passes 3, xray = true) -- xray means the
-- blur samples the wallpaper rather than the windows behind, which is what
-- makes it read as frosted glass over the desktop instead of a smear of
-- whatever is underneath.
hl.window_rule({ match = { class = "^(dev\\.zed\\.Zed)$" }, no_blur = false })

-- Keep Dolphin's native Kvantum transparency and blur the desktop behind it.
hl.window_rule({ match = { class = "^(org\\.kde\\.dolphin)$" }, no_blur = false })

-- ── Transparent EasyEffects ────────────────────────────────────────────────
-- EasyEffects is GTK4/libadwaita, so Kvantum cannot provide translucency.
-- Keep its existing compositor opacity without changing its blur behavior.
hl.window_rule({ match = { class = "^(com\\.github\\.wwmm\\.easyeffects)$" }, opacity = "0.80 0.80" })

-- ── Glass for Spotify + comms apps ────────────────────────────────────────
-- Same idea as the Zed rule above (re-enable blur, which the framework
-- disables for every window), but these are plain Electron apps with a
-- fully opaque background -- unlike Zed's "Matugen Glass" theme, they have
-- no real alpha channel of their own for blur to show through. Blur alone
-- (no_blur = false) would render as a hard rectangle with a crisp edge and
-- no visible glass. So this pairs it with an explicit opacity windowrule
-- (same mechanism as the EasyEffects rule above), which compositor-blends
-- the whole window against the blurred desktop behind it regardless of what
-- the app itself draws -- that combination is what actually reads as frosted
-- glass for an app that doesn't support it natively.
--
-- Classes: Spotify (media), discord / org.telegram.desktop /
-- com.rtosta.zapzap (comms) -- the same app set machine.md's now-removed
-- workspace-role table (2026-09-15) grouped as "media"/"comms", i.e. the
-- apps this machine already treats as a matched pair, not the full window
-- set. Deliberately NOT applied to document/text-heavy apps (LibreOffice,
-- Dolphin) because whole-window opacity would reduce text contrast.
-- Dolphin uses native Kvantum alpha and a separate blur rule above.
hl.window_rule({ match = { class = "^(Spotify|discord|org\\.telegram\\.desktop|com\\.rtosta\\.zapzap)$" }, no_blur = false, opacity = "0.88 0.80" })

-- ── Glass for the browser ──────────────────────────────────────────────
-- Same reasoning as the Spotify/comms rule above: Thorium and Chrome are
-- plain Chromium windows with an opaque background, so re-enabling blur
-- alone would show a hard-edged rectangle -- pair it with the same
-- opacity windowrule to blend the whole window against the blurred
-- desktop. Both classes are listed because the installed browser has
-- switched between the two (`custom/variables.lua`'s `browser` var) and
-- this rule should not need to change every time it does.
--
-- Added 2026-10-06: a `./apply.sh --configs` run (to point `browser` at
-- Thorium) overwrote an uncommitted, on-disk-only version of this file
-- that had browser transparency already configured by hand -- `apply.sh`
-- does a blind `cp` with no backup/diff (see `apply_configs()`), so the
-- prior rule's exact match string could not be recovered (checked:
-- `snapper list-configs` only covers the `/` subvolume, `/home` is a
-- separate `@home` subvolume with no snapper config at all; no shell or
-- editor history survived either). Re-derived here from the live window
-- class instead. Thorium's class differs by XWayland vs native Wayland:
-- `Thorium-browser` under XWayland (the default, `thorium-flags.conf`
-- had `--ozone-platform-hint=wayland` commented out -- fixed, see
-- `~/.config/thorium/thorium-flags.conf`) vs `thorium-browser` (all
-- lowercase) once forced native Wayland. Matching both cases so this
-- survives either path. `google-chrome` kept for the same reason as
-- the comment above.
hl.window_rule({ match = { class = "^([Tt]horium-browser|google-chrome)$" }, no_blur = false, opacity = "0.88 0.80" })

