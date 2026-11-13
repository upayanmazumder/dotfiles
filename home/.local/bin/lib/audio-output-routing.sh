#!/usr/bin/env bash
# Shared routing for the output switch, routing controller, and volume keys.
# Keep the hardware sink as the system default so Easy Effects tracks it.
# Easy Effects redirects applications through its virtual sink.
# Manual links only repair a stale output route. Never duplicate stereo links.
# The override file contains speaker or headphones. No override means automatic.
# The route file records intent for the panel, including while audio is idle.

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
  ee_output_link_pairs | awk 'NR == 1 { sub(/:.*/, "", $2); print $2 }'
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
    {
      node = $2
      sub(/:.*/, "", node)
      if (!first) first = node
      if (node != first) mixed = 1
      if ($1 ~ /:output_FL$/ && $2 ~ /:playback_FL$/) left++
      if ($1 ~ /:output_FR$/ && $2 ~ /:playback_FR$/) right++
      n++
    }
    END {
      valid = !mixed && left == 1 && right == 1
      printf "%s %d\n", (valid ? first : "-"), n + 0
    }
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
    # Another caller can complete the route while this caller waits.
    read -r cur count < <(ee_output_state)
    [[ "$cur" == "$target" && "$count" == 2 ]] && exit 0
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
