---
name: livekit-gnani-voice-agent
description: "Build or debug a LiveKit voice agent using Gnani (Vachana) speech: pipeline wiring, a non-LLM backend as the model stage, React transcript rendering, resource sizing, and self-hosting livekit-server on Kubernetes."
---

# LiveKit + Gnani voice agent

Use when building a browser/phone voice agent whose speech comes from Gnani (Vachana) and whose
"brain" is an existing HTTP chat backend rather than an LLM SDK.

## Packages (check they still track each other)

- `livekit-agents` and `livekit-plugins-gnani` share a version line (both 1.8.4 at time of writing).
- `livekit-plugins-silero` for local VAD.
- Browser: `livekit-client`, `@livekit/components-react`, **and `@livekit/components-styles`**
  (separate package; omitting it fails the Next.js build with "Can't resolve").
- Tokens: `livekit-server-sdk` (`AccessToken`) minted in a server route; never ship the key pair.

## Wiring the pipeline

```python
AgentSession(
    vad=silero.VAD.load(),            # local turn detection; model ships in the wheel
    stt=GnaniSTT(language="en-IN", use_streaming=True),
    llm=<your adapter>,
    tts=GnaniTTS(model="timbre-v2.5", container="raw", synthesize_method="websocket"),
)
```

- **Always pass a VAD.** Without one the worker reaches for `agent-gateway.livekit.cloud` and 401s,
  then falls back with retries — noisy and slow.
- `AgentSession` binds to the running event loop. Construct it inside a coroutine (`asyncio.run`),
  never at import time, or tests fail with "There is no current event loop".
- Gnani's TTS default model in the plugin was older than the documented current one — pass `model`
  explicitly. Gnani TTS also returns transient `500 "We are facing technical difficulties"`, which
  the plugin retries; a second provider behind `tts.FallbackAdapter` is the real fix.

## Adapting a non-LLM backend as the model stage

Subclass `livekit.agents.llm.LLM`; return a `LLMStream` whose `_run()` emits one
`ChatChunk(id=..., delta=ChoiceDelta(role="assistant", content=text))` via
`self._event_ch.send_nowait(...)`. Extract the newest user turn from
`self._chat_ctx.messages()` (walk backwards for `role == "user"`; content entries are `str` or
objects with `.text`).

Send only the newest utterance when the backend owns the dialogue state — do not replay history, or
the remote agent sees its own turns twice.

Use `NotGivenOr[...] = NOT_GIVEN` for the `chat()` signature's optional params.

## Rendering the transcript in React

- **`useTranscriptions()` is the hook for voice turns inside a plain `<LiveKitRoom>`.** It returns
  `TextStreamData[]` with `text`, `participantInfo.identity`, `streamInfo.{id,attributes,timestamp}`.
- **`useSessionMessages()` does NOT work there** — it is beta and reads from a `SessionProvider`; with
  none it returns an empty array and no error, so the transcript silently renders nothing.
  `useChat()` is for text chat (`lk.chat`) and carries no voice transcriptions either.
- **LiveKit streams a sentence as growing revisions** (“Hello!”, “Hello! How”, “Hello! How can”, …)
  and the agent's TTS-aligned transcript opens a **new stream id per revision**, so appending each
  one renders twelve lines for one sentence. Fold on `streamInfo.attributes['lk.segment_id']`
  (fallback: a prefix growth from the same speaker is the same utterance), rewriting in place.
- Render rows with `<ChatEntry hideName entry={...} />` from the same package for the framework's
  markup and styling; `BarVisualizer` for the visualiser and `VoiceAssistantControlBar` for
  mic/leave controls.

## Publishing the media ports

WebRTC media cannot traverse an Ingress — only the signalling WebSocket can — so the browser must
reach the node's own ports. How to do that depends on the cluster:

- **`hostNetwork: true` is the obvious answer and is often unavailable.** On any namespace with Pod
  Security `baseline` it is rejected outright (`host namespaces`, `hostPort`) and the pod never
  schedules; you find out from `kubectl describe pod` / the ReplicaSet's `FailedCreate`, not from a
  validation error when applying.
- **The PSA-clean equivalent is a `LoadBalancer` Service with `externalTrafficPolicy: Local`.** On
  k3s, ServiceLB binds the *same port numbers* on the node — the mechanism Traefik already uses for
  80/443 — which is what ICE requires, since the advertised port must equal the listening port. An
  ordinary `NodePort` (30000-32767) does **not** work for this.
- **Do not relax a namespace's Pod Security level to suit one pod.**
- **Then fix the NetworkPolicy.** ServiceLB forwards with the *caller's* source address preserved,
  so there is no in-cluster source to match — a policy allowing only the ingress controller and
  same-namespace peers drops every media packet. The symptom is a call that connects with **no
audio**, not an error. Add an `ipBlock` (0.0.0.0/0) rule for the media ports.
- Advertise the node address with `NODE_IP` from the downward API (`fieldRef: status.hostIP`) —
  correct whether or not the pod shares the node's network namespace — and set
  `use_external_ip: false`.
- Keys: pass config YAML via `--config-body "$(LIVEKIT_CONFIG)"` from a ConfigMap, and the key pair
  through the `LIVEKIT_KEYS` env var (`"key: secret"`) from a Secret, so no secret lands in git.
- Watch for `UDP receive buffer is too small for a production set-up` — `net.core.rmem_max` on the
  node, worth a sysctl before real traffic.

## Resource sizing (this one is audible)

A worker running STT/TTS sockets + an ONNX VAD + HTTP uses roughly 370m CPU and 600Mi+. At
`limits: 500m` it was throttled in **~18% of scheduling periods** and callers heard the audio break
up before the media transport stalled and the client reconnected. Diagnose inside the container:

```bash
kubectl exec deploy/<worker> -- grep -E 'nr_periods|nr_throttled' /sys/fs/cgroup/cpu.stat
```

Any meaningful `nr_throttled` fraction is a bug. Size to ~2 CPU / 1Gi, and keep interactive
services out of a `low-priority` class (value -1 is evicted first under memory pressure, mid-call).

## Verifying without a browser

Join the room with `livekit.rtc` and publish synthesized speech as the microphone track:

```python
source = rtc.AudioSource(16000, 1)
track = rtc.LocalAudioTrack.create_audio_track("microphone", source)
await room.local_participant.publish_track(
    track, rtc.TrackPublishOptions(source=rtc.TrackSource.SOURCE_MICROPHONE))
frame = rtc.AudioFrame.create(16000, 1, 320)
frame.data[:] = memoryview(chunk).cast("h")   # data is int16, not bytes
await source.capture_frame(frame)             # pace at 20ms per frame
```

- `frame.data` is a memoryview with format `h`; assigning raw bytes raises
  "lvalue and rvalue have different structures".
- Read transcriptions with `room.register_text_stream_handler("lk.transcription", handler)`, not the
  legacy `transcription_received` event.
- Count **loud** frames, not frames: an agent's audio track delivers continuous silence from the
  moment it publishes, so "audio received" alone proves nothing.
- The worker needs a couple of seconds to dispatch into a brand-new room; wait for it to join before
  the caller speaks or the first words are clipped.
- To verify a portal-issued token, fetch it from the page in a signed-in browser and join with
  *that* token — it proves the signing key, the ingress and the worker dispatch together.
- To exercise a page's own UI without a microphone, stub `getUserMedia` with a `MediaStreamAudioDestinationNode`
  and speak into the same room from the Python client; then read the page's DOM.

## Token/room design worth copying

One room per viewer (`kirro-<email-slug>`), minted in a server route only for an authenticated
session, with `canPublish`/`canSubscribe`/`canPublishData` and a short TTL. The worker is dispatched
automatically (`agent_name: ""`), so any room a legitimate participant can join gets an agent.
