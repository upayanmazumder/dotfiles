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


