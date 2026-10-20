-- User keybinds. Loads AFTER ~/.config/hypr/hyprland/keybinds.lua, which is
-- framework-owned and replaced on every dots-hyprland update. Nothing in here
-- is touched by an update, so this is where user binds belong.
--
-- IMPORTANT: Hyprland fires EVERY bind registered for a key combo, not just
-- the last one registered. The framework relies on that deliberately (each
-- shell bind has a `qs ipc call TEST_ALIVE || <fallback>` twin, so actions
-- degrade to standalone tools if Quickshell dies). The consequence is that
-- re-binding an already-bound combo here ADDS a second action rather than
-- replacing the first. Call hl.unbind(key) first when replacing a framework
-- bind; only skip it when adding a genuinely unused combo.

local eeVolume = HOME .. "/.local/bin/ee-volume.sh"

-- ── Volume / mute: route through EasyEffects, not wpctl ──────────────────
-- easyeffects_sink's own PipeWire volume is cosmetic: EasyEffects reads its
-- DSP input from that sink's *monitor* port, which is pre-fader by PipeWire
-- convention, so `wpctl set-volume @DEFAULT_AUDIO_SINK@` never reaches the
-- real speakers/headphones. ee-volume.sh computes from the real hardware
-- sink and writes both, keeping them in sync -- the same reasoning behind the
-- pushRealVolume/pushRealMute functions added to quickshell's
-- services/Audio.qml. See docs/machine.md "Local Quickshell modifications".
--
-- These four combos were previously edited directly into the framework's
-- keybinds.lua, i.e. on the wrong side of the update boundary. Upstream binds
-- them to wpctl, so unbind before rebinding or both fire and volume steps
-- twice per keypress.
hl.unbind("XF86AudioRaiseVolume")
hl.unbind("XF86AudioLowerVolume")
hl.unbind("XF86AudioMute")
hl.unbind("SUPER + SHIFT + M")

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(eeVolume .. " up 2%"),
    { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(eeVolume .. " down 2%"),
    { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(eeVolume .. " mute-toggle"),
    { locked = true })
hl.bind("SUPER + SHIFT + M", hl.dsp.exec_cmd(eeVolume .. " mute-toggle"),
    { locked = true, description = "Media: Toggle mute" })

-- ── Pomodoro (Solanum) ──────────────────────────────────────────────────
-- Moved off SUPER+SHIFT+P. That combo is upstream's "Media: Play/pause", and
-- since every matching bind fires, binding Solanum there too meant a single
-- keypress both toggled the Pomodoro timer and paused whatever was playing.
-- It was the only unintentional duplicate among ~196 binds.
-- Note Quickshell also ships its own pomodoro (config.json `time.pomodoro`),
-- so Solanum is arguably redundant -- kept for now, just on its own key.
hl.bind("SUPER + SHIFT + O", hl.dsp.exec_cmd("solanum"),
    { description = "App: Toggle Pomodoro timer (Solanum)" })

-- ── Meta ────────────────────────────────────────────────────────────────
hl.bind("CTRL + SUPER + ALT + Slash",
    hl.dsp.exec_cmd("xdg-open " .. HOME .. "/.config/hypr/custom/keybinds.lua"),
    { description = "Edit user keybinds" })

-- ── Named scratchpads ───────────────────────────────────────────────────
-- Upstream ships exactly one special workspace ("special", SUPER+S) used as
-- a generic scratchpad. These add purpose-built ones so a terminal or a
-- notes buffer is always one keypress away and one keypress gone, without
-- consuming a numbered workspace or disturbing the current layout.
--
-- Each spawns its app on first use rather than at login, so an unused
-- scratchpad costs nothing. `toggle_special` creates the workspace on
-- demand; the `[workspace special:<n> silent]` exec prefix puts the new
-- window there without pulling focus mid-spawn.
--
-- Deliberately no "music" scratchpad: Spotify already has workspace 5 and
-- SUPER+5 reaches it in one key, so a scratchpad would add a bind without
-- adding a capability.

-- Spawn-on-first-use, then toggle. Placement onto special:<name> is handled
-- by the window rules in custom/rules.lua, keyed off the window class -- not
-- by an exec prefix (see the comment there for why).
local function scratchpad(key, name, class, spawnCmd, desc)
    hl.bind(key, function()
        local existing = hl.get_windows({ class = "^(" .. class .. ")$" })
        if (existing == nil) or (#existing == 0) then
            hl.dispatch(hl.dsp.exec_cmd(spawnCmd))
        end
        hl.dispatch(hl.dsp.workspace.toggle_special(name))
    end, { description = desc })
end

-- Terminal scratchpad: a drop-down shell over whatever you're doing.
scratchpad("SUPER + ALT + Return", "term", "kitty-scratch",
    "kitty --class kitty-scratch", "Scratchpad: Terminal")

-- Notes scratchpad: quick capture without leaving what you're on.
-- Uses micro, not nvim -- modeless, no vim knowledge needed -- and not
-- VS Code, which is both too heavy for a scratchpad and would be captured
-- by the ^([Cc]ode)$ -> workspace 1 rule in custom/rules.lua.
scratchpad("SUPER + ALT + N", "notes", "kitty-notes",
    "kitty --class kitty-notes micro " .. HOME .. "/notes.md",
    "Scratchpad: Quick notes")

-- ── Developer workflow (Stage 6) ────────────────────────────────────────
-- Scripts live in this repo under scripts/desktop/ and are symlinked into
-- ~/Scripts/bin by `apply.sh --scripts`. Absolute paths here for the same
-- reason ee-volume.sh uses one: a Hyprland bind does not inherit the
-- interactive shell's PATH additions from config.fish.
local bin = HOME .. "/Scripts/bin"

-- Project launcher: fuzzy-pick any git checkout under ~/dev or ~/Code and
-- open editor + terminal there. The real dev tree is ~/dev/<owner>/<repo>
-- (29 checkouts), so this replaces typing a two-level path from memory.
-- Editor and terminal land on workspaces 1 and 3 via custom/rules.lua.
hl.bind("SUPER + SHIFT + Return", hl.dsp.exec_cmd(bin .. "/project-open"),
    { description = "Dev: Open project (editor + terminal)" })

-- Dev/admin action palette: SSH hosts, git, docker, k8s, and the utility
-- scripts in this repo -- which are otherwise invisible in ~/Scripts/bin
-- unless you already remember their exact names.
hl.bind("SUPER + SHIFT + Space", hl.dsp.exec_cmd(bin .. "/dev-palette"),
    { description = "Dev: Action palette" })

-- lazygit in a picked project. Duplicates a palette entry on purpose:
-- git is frequent enough to be worth skipping one menu level.
hl.bind("SUPER + ALT + G",
    hl.dsp.exec_cmd("kitty sh -c 'p=$(" .. bin .. "/project-open --print) && cd \"$p\" && lazygit'"),
    { description = "Dev: lazygit (pick project)" })
