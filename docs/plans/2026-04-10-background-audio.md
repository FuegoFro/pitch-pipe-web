# Background Audio (Screen Lock) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Keep audio playing on Android Chrome when the screen locks.

**Architecture:** Web Audio alone stops on screen lock because the OS doesn't recognise it as "media". The fix is two-fold: (1) route the audio graph through a `MediaStreamDestinationNode` piped into an `<audio>` element — this makes the browser register it as a media stream the OS won't kill — and (2) register with the MediaSession API so Android treats the page as an active media player and shows lock screen controls. A `statechange` listener on the AudioContext auto-resumes if the context is ever suspended.

**Tech Stack:** Svelte 3, TypeScript, Web Audio API, MediaSession API. No test framework — manual testing only.

---

### Task 1: Route audio through a MediaStream bridge

This is the core fix. Instead of the gain node outputting directly to `ctx.destination`, it also feeds a `MediaStreamDestinationNode`. An `<audio>` element is given that stream as its source. Once the AudioContext starts running (first user interaction), the `<audio>` element plays, which causes the OS to treat the audio as media playback that should survive screen lock.

**Files:**
- Modify: `src/PitchPipe.svelte` — `setupAudio()` function (lines ~123–143)

**Step 1: Read the current `setupAudio` function**

The current function (around line 124) looks like:

```ts
function setupAudio() {
    let ctx = new window.AudioContext()
    let analyserNode = new AnalyserNode(ctx, { fftSize: 4096 * 2 })
    let gainNode = new GainNode(ctx, { gain: 0.04 })
    gainNode.connect(ctx.destination)
    analyserNode.connect(gainNode)
    const dataArray = new Uint8Array(analyserNode.frequencyBinCount)
    return { ctx, analyserNode, destination: analyserNode, dataArray }
}
```

**Step 2: Replace `setupAudio` with the MediaStream-bridged version**

Replace the entire `setupAudio` function body with:

```ts
function setupAudio() {
    let ctx = new window.AudioContext()
    let analyserNode = new AnalyserNode(ctx, {
        fftSize: 4096 * 2,
    })
    let gainNode = new GainNode(ctx, {
        gain: 0.04,
    })

    // Route through a MediaStreamDestinationNode so the OS treats this as
    // media playback, which allows audio to continue when the screen locks.
    let mediaStreamDest = ctx.createMediaStreamDestination()
    gainNode.connect(mediaStreamDest)
    analyserNode.connect(gainNode)

    // The <audio> element is never added to the DOM; it just registers the
    // stream with the browser's media machinery.
    let mediaAudioElt = new Audio()
    mediaAudioElt.srcObject = mediaStreamDest.stream

    // Autoplay is blocked until a user gesture. Resume the element
    // whenever the AudioContext first starts (or resumes after lock).
    ctx.addEventListener('statechange', () => {
        if (ctx.state === 'running' && mediaAudioElt.paused) {
            mediaAudioElt.play().catch(() => {})
        }
    })

    const dataArray = new Uint8Array(analyserNode.frequencyBinCount)

    return {
        ctx,
        analyserNode,
        destination: analyserNode,
        dataArray,
    }
}
```

Note: `gainNode.connect(ctx.destination)` is intentionally removed — audio now exits via `mediaAudioElt` instead. The `destination: analyserNode` return value is unchanged, so oscillators still connect correctly.

**Step 3: Type-check**

Run: `pnpm check`
Expected: 0 errors (the pre-existing hint about `triangle`'s implicit `any` is fine to ignore)

**Step 4: Commit**

```bash
git add src/PitchPipe.svelte
git commit -m "feat: route audio through MediaStream so screen lock doesn't stop playback"
```

---

### Task 2: Register with the MediaSession API and add statechange auto-resume

Registering with MediaSession tells Android this is an active media player. The lock screen will show controls (play/pause). Without this, even with the MediaStream bridge, some Android versions may still kill the audio session after a short idle period.

**Files:**
- Modify: `src/PitchPipe.svelte` — after the `const audio = setupAudio()` call (line ~144)

**Step 1: Add `setupMediaSession()` and call it**

After the `const audio = setupAudio()` line, add:

```ts
function setupMediaSession() {
    if (!('mediaSession' in navigator)) return
    navigator.mediaSession.metadata = new MediaMetadata({
        title: 'Pitch Pipe',
    })
    // Registering play/pause handlers is required for Android to show lock
    // screen controls and maintain the audio session.
    navigator.mediaSession.setActionHandler('play', () => {
        audio.ctx.resume()
    })
    navigator.mediaSession.setActionHandler('pause', () => {
        // We don't actually pause — pitch pipe is always-on while a note is
        // held. But registering the handler prevents the OS from taking over.
    })
}
setupMediaSession()
```

**Step 2: Add a statechange auto-resume on the AudioContext**

Directly after `setupMediaSession()`, add:

```ts
// If the OS suspends the AudioContext (e.g. briefly on some devices),
// resume it immediately so playback continues.
audio.ctx.addEventListener('statechange', () => {
    if (audio.ctx.state === 'suspended') {
        audio.ctx.resume()
    }
})
```

**Step 3: Type-check**

Run: `pnpm check`
Expected: 0 errors

**Step 4: Commit**

```bash
git add src/PitchPipe.svelte
git commit -m "feat: register MediaSession API and auto-resume AudioContext on suspend"
```

---

### Task 3: Manual testing

**Step 1: Build and deploy**

```bash
pnpm build
./deploy.sh
```

**On Android Chrome (non-PWA, browser tab):**
1. Open the deployed site
2. Start playing a note (tap a note button; in toggle mode is easiest)
3. Lock the phone screen
4. Wait 10–15 seconds
5. Unlock — audio should still be playing
6. Check that the Android lock screen showed a media notification for "Pitch Pipe"

**On desktop Chrome (sanity check):**
1. Open the site
2. Play a note — should still work identically to before
3. No regressions in the frequency analyser display

**If audio stops on screen lock:**
- Check DevTools console for errors from `mediaAudioElt.play()` being rejected
- Ensure the note was started AFTER the first user interaction (AudioContext needs to be in `running` state before the `<audio>` element can play)
