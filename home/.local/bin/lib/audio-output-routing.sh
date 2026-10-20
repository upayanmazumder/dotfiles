#!/usr/bin/env bash
# audio-output-routing.sh
#
# Shared logic for pinning EasyEffects' REAL hardware output between the
# built-in laptop speaker and a connected Bluetooth headset, overriding
# the automatic BT-always-wins policy in
# ~/.config/wireplumber/wireplumber.conf.d/51-bluetooth-audio-priority.conf
# when the user explicitly wants otherwise (e.g. force speakers while
# headphones stay connected).
#
# Sourced by:
#   - audio-output-switch.sh   (manual switch, e.g. the quickshell bar button)
#   - easyeffects-bt-relink.sh (daemon that converges the real graph on intent)
#   - ee-volume.sh             (volume/mute: needs to know the real sink)
#
# STATE FILES (~/.config/audio-output-switch/)
#   override  -- "speaker" | "headphones" | absent (= auto, BT-wins policy)
#   route     -- "speaker" | "headphones": the CURRENTLY INTENDED target
#                (override if set, else the BT-wins policy pick), i.e.
#                route_label_for_sink(desired_sink_name()). This is what
#                the bar button's icon reads (via quickshell FileView).
#
# NOTE ON WHY THE ICON SHOWS "intended" AND NOT "verified real link":
# EasyEffects' internal SOE (sink output effects) chain -- including
# ee_soe_output_level, the node whose output ports actually reach
# hardware -- gets destroyed and rebuilt by EasyEffects itself while
# idle/resuming (observed directly: `pw-link -l` output for this node
# flaps across consecutive calls a second apart even with no BT/device
# changes happening), and again for ~20s after a restart. Driving the bar
# icon off that raw link would flap the icon on every idle/resume cycle
# for reasons that have nothing to do with which output the user asked
# for. `route` instead reflects *intent*; the daemon's converge() is what
# makes the real graph match it again.
#
# WHY INTENT ALONE IS NOT ENOUGH (2026-10-02, root-caused):
# The real link is created by EasyEffects from its *own* stored output
# device (`outputDevice` in ~/.config/easyeffects/db/easyeffectsrc`,
# currently the built-in speaker), not from the BT-wins policy: observed
# directly on 2026-10-02, with the OnePlus Buds connected (bluez sink at
# priority.session 2500 vs the speaker's 200), a freshly restarted
# EasyEffects still created
# `ee_soe_output_level:output_FL -> alsa_output...Speaker__sink:playback_FL`.
# The system default sink is easyeffects_sink itself (apps must route
# through the DSP), so EE's `useDefaultOutputDevice=true` cannot resolve
# to a real device and EE falls back to its stored outputDevice -- which
# means "restart EE and let it re-pick" (the original design) can never
# converge for Bluetooth at all, and the link has to be re-pointed from
# the outside. That is only possible while EE's chain is up, and that
# (see above) is only while audio is actually flowing. Two live symptoms
# followed from ignoring that:
#   * a switch made while idle did nothing until the *next* stream
#     started, and then only 15-25s later (the old sweep + recheck) --
#     "the switcher only works if audio is already playing";
#   * "chain down while a stream is listed" looked like a wedged
#     EasyEffects, so the daemon restarted EE every ~22s forever (a
#     paused Spotify keeps a sink input listed even though nothing is
#     playing).
# Everything below is therefore written to be called from a tight loop by
# the daemon: cheap, idempotent, and honest about what it can and cannot
# do right now. Playback is tested with streams_playing() (uncorked), and
# chain presence with ee_chain_present() (ports, not links).

set -u

AUDIO_SWITCH_DIR="$HOME/.config/audio-output-switch"
OVERRIDE_FILE="$AUDIO_SWITCH_DIR/override"
ROUTE_FILE="$AUDIO_SWITCH_DIR/route"
SPEAKER_SINK="alsa_output.pci-0000_04_00.6.HiFi__Speaker__sink"

# Handshake between the manual switch and the daemon: the switch touches
# WAKE_FILE so its change is picked up immediately instead of at the next
# safety tick (see wake_converger below).
ROUTING_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}/audio-output-routing"
WAKE_FILE="$ROUTING_RUNTIME_DIR/wake"

mkdir -p "$AUDIO_SWITCH_DIR" "$ROUTING_RUNTIME_DIR"

# Name of the currently connected Bluetooth output sink, or empty.
# The `timeout` guards on every PipeWire/pulse client call below are
# deliberate: a dead or wedged server makes these clients block in read()
# (observed once, live: an interrupted call left the converge loop parked
# on a pw-link that never returned, so nothing was repaired afterwards).
# A bounded call degrades to "no answer" instead, which every caller here
# already treats as "nothing to do right now".
bluez_sink_name() {
  timeout 5 pactl list short sinks 2>/dev/null | awk -F'\t' '$2 ~ /^bluez_output\./ {print $2; exit}'
}

# "speaker" | "headphones" | "" (empty = auto, no manual pin).
get_override() {
  local v
  v=$(cat "$OVERRIDE_FILE" 2>/dev/null || true)
  if [[ "$v" == "speaker" || "$v" == "headphones" ]]; then
    echo "$v"
  else
    echo ""
  fi
}

set_override() {
  echo "$1" > "$OVERRIDE_FILE"
}

clear_override() {
  rm -f "$OVERRIDE_FILE"
}

# Which real sink name SHOULD ee_soe_output_level be linked to right now,
# given the override (if any) and what's actually connected?
desired_sink_name() {
  local override bt
  override=$(get_override)
  bt=$(bluez_sink_name)
  case "$override" in
    headphones)
      # Forced to headphones. If they're not actually connected there is
      # nothing to link to yet -- use the speaker so audio doesn't go
      # into a void; this re-evaluates (and switches to the headset)
      # every converge once they reconnect.
      if [[ -n "$bt" ]]; then echo "$bt"; else echo "$SPEAKER_SINK"; fi
      ;;
    speaker)
      echo "$SPEAKER_SINK"
      ;;
    *)
      # Auto: existing BT-always-wins policy.
      if [[ -n "$bt" ]]; then echo "$bt"; else echo "$SPEAKER_SINK"; fi
      ;;
  esac
}

# "speaker" | "headphones" | "none" for a given sink name.
route_label_for_sink() {
  case "$1" in
    bluez_output.*) echo "headphones" ;;
    alsa_output.*) echo "speaker" ;;
    *) echo "none" ;;
  esac
}

# Does EE's sink-output chain exist right now, i.e. are its output ports
# in the graph? True while EE's DSP chain is up even if nothing is linked
# to it, which is exactly the state EE leaves behind while it is idle.
# A *link* test (`pw-link -l` alone) cannot tell "EE is idle" from "EE's
# chain is gone"; that conflation is what made a switch while idle a
# silent no-op, and what made an idle EasyEffects look wedged.
ee_chain_present() {
  timeout 5 pw-link -o 2>/dev/null | grep -q '^ee_soe_output_level:output_FL'
}

# Is any application actually pushing audio right now? Corked sink inputs
# (paused Spotify/VLC, apps holding an idle stream open) stay in
# `pactl list short sink-inputs` forever, so counting those is not a
# playback test -- see the 2026-10-02 note up top.
streams_playing() {
  timeout 5 pactl list sink-inputs 2>/dev/null | grep -q 'Corked: no'
}

# Which real sink is ee_soe_output_level actually linked to right now?
# Empty = unlinked (or chain down). NOTE: this reflects a node that
# EasyEffects itself tears down/rebuilds on idle/resume. Used to decide
# whether a fix is needed, NOT for what the bar displays.
ee_output_target() {
  timeout 5 pw-link -l 2>/dev/null | awk '
    /^ee_soe_output_level:output_FL/ {found=1; next}
    found && /^[[:space:]]*\|->/ {
      gsub(/^[[:space:]]*\|->[[:space:]]*/, "", $0)
      sub(/:.*/, "", $0)
      print $0
      exit
    }
  '
}

# Every link currently leaving EE's chain output, as "<out_port> <in_port>".
# Empty when the chain is down or nothing is linked. A plain first-match
# reading (what ee_output_target does) is not enough for the repair path:
# the correct graph has exactly one link per channel (docs/machine.md --
# an extra link between the same ports sums the processed signal with
# itself), so the repair has to see *all* of them to be able to remove a
# duplicate left behind by a past race.
ee_output_link_pairs() {
  timeout 5 pw-link -l 2>/dev/null | awk '
    /^ee_soe_output_level:output_F[LR]$/ { out = $0; next }
    out && /^[[:space:]]*\|->/ {
      gsub(/^[[:space:]]*\|->[[:space:]]*/, "", $0)
      print out, $0
      next
    }
    { out = "" }
  '
}

# "<first target node> <link count>" for EE's chain output, derived from
# the same single pw-link listing (empty node when nothing is linked).
# Callers that have to judge "is the real graph already what we want?"
# need *both* facts: matching the first link while a duplicate exists (or
# while two links point elsewhere) must not read as converged. That blind
# first-match check is exactly how a duplicate pair survived a running
# daemon on 2026-10-02, so every decision below goes through this.
ee_output_state() {
  ee_output_link_pairs | awk '
    { if (!first) { first = $2; sub(/:.*/, "", first) } n++ }
    END { printf "%s %d\n", first, n + 0 }
  '
}

# Record the CURRENTLY INTENDED route (override if set, else policy) to
# the route file, for the bar icon. Only rewritten when it actually
# changes -- the converge loop calls this every tick and there is no
# reason to churn the watched file (and the bar's FileView reload) for an
# unchanged value.
write_current_route() {
  local new cur
  new=$(route_label_for_sink "$(desired_sink_name)")
  cur=$(cat "$ROUTE_FILE" 2>/dev/null || true)
  [[ "$cur" == "$new" ]] || printf '%s\n' "$new" > "$ROUTE_FILE"
}

# Ask the daemon to converge right now instead of at its next tick.
wake_converger() {
  : > "$WAKE_FILE" 2>/dev/null || true
}

# Re-point ee_soe_output_level's stereo output at $1 (a sink name,
# defaulting to the intended one), WITHOUT restarting EasyEffects. Safe:
# EasyEffects does not actively re-manage this link once its DSP chain is
# up (it only picks a target once, at chain creation), so a manually-moved
# pw-link is stable until something else moves it.
#
# Returns 0 when the link now matches the target, 1 when it could not be
# made to match -- either because the chain is not up at all (nothing to
# link yet; the next stream start rebuilds it and the daemon converges
# then), or because the target sink went away mid-flight.
relink_ee_output() {
  local target="${1:-}" cur count pairs p ok
  [[ -n "$target" ]] || target=$(desired_sink_name)
  if ! ee_chain_present; then
    write_current_route
    return 1
  fi

  read -r cur count < <(ee_output_state)
  if [[ "$cur" == "$target" ]] && (( count == 2 )); then
    write_current_route
    return 0
  fi

  # Serialize with the daemon (and any other caller). Two writers that
  # both see "unlinked" and both create the link would leave a *second*
  # copy of the audio path on the same ports -- +6 dB and comb filtering,
  # see the "do not hand-create extra links" note in docs/machine.md.
  (
    flock -w 5 9 || exit 1
    mapfile -t pairs < <(ee_output_link_pairs)
    for p in "${pairs[@]}"; do
      timeout 5 pw-link -d "${p%% *}" "${p#* }" 2>/dev/null
    done
    timeout 5 pw-link "ee_soe_output_level:output_FL" "${target}:playback_FL" 2>/dev/null
    timeout 5 pw-link "ee_soe_output_level:output_FR" "${target}:playback_FR" 2>/dev/null
  ) 9>"$ROUTING_RUNTIME_DIR/route.lock"

  write_current_route

  # Verify instead of assuming: the caller (daemon loop, manual switch)
  # uses the exit status to decide whether more work is needed, and a link
  # can fail if the sink vanished between the two calls.
  read -r cur count < <(ee_output_state)
  (( count == 2 )) && [[ "$cur" == "$target" ]] || return 1
  mapfile -t pairs < <(ee_output_link_pairs)
  ok=1
  for p in "${pairs[@]}"; do
    [[ "${p#* }" == "${target}:"* ]] || ok=0
  done
  (( ok ))
}
