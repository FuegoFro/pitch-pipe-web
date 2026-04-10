# Mobile Toggle Mode Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a "toggle" mode button on mobile so users can tap a note to start/stop it, instead of needing to hold.

**Architecture:** `AnnularButton` already has a `'sustain'` state that keeps a note playing after pointer-up — toggle mode simply forces that path on every tap. A boolean `toggleMode` prop is added to `AnnularButton` and driven by a global UI button in `PitchPipe` that is hidden on non-touch devices via a CSS media query.

**Tech Stack:** Svelte 3, TypeScript, Vite, no test framework (manual testing only)

---

### Task 1: Add `toggleMode` prop to `AnnularButton` and wire it into the state machine

**Files:**
- Modify: `src/AnnularButton.svelte`

**Step 1: Add the `toggleMode` prop**

In the `<script>` block, after the existing `export let releaseNote: () => void` line, add:

```ts
export let toggleMode: boolean = false
```

**Step 2: Use `toggleMode` in `onPointerDown`**

Change the line:
```ts
state = (e.shiftKey) ? 'sustain' : 'hold'
```
to:
```ts
state = (e.shiftKey || toggleMode) ? 'sustain' : 'hold'
```

**Step 3: Verify the TypeScript compiles**

Run: `pnpm check`
Expected: no errors

**Step 4: Commit**

```bash
git add src/AnnularButton.svelte
git commit -m "feat: add toggleMode prop to AnnularButton"
```

---

### Task 2: Add `toggleMode` state and UI button to `PitchPipe`

**Files:**
- Modify: `src/PitchPipe.svelte`

**Step 1: Add `toggleMode` reactive variable**

In the `<script>` block (anywhere after the imports), add:

```ts
let toggleMode = false
```

**Step 2: Pass `toggleMode` to every `AnnularButton`**

In the template, the existing `<AnnularButton ... />` element has props on separate lines. Add `toggleMode={toggleMode}` to it:

```svelte
<AnnularButton
    angle={(note.tempering == 'equal') ? note.angle : note.angle + wheelAngle}
    outerRadius={radii[note.level]}
    height={radii[note.level] - radii[note.level + 1]}
    name={note.name}
    startNote={() => startNote(audio, note)}
    releaseNote={() => releaseNote(audio, note)}
    toggleMode={toggleMode}
    />
```

**Step 3: Add the toggle button markup**

In the `<div class="waves">` section (right after the closing `{/each}` of the wave selectors), add:

```svelte
<div class="toggle-mode-btn" on:pointerdown={() => toggleMode = !toggleMode}>
    {toggleMode ? 'toggle' : 'hold'}
</div>
```

**Step 4: Add CSS for the toggle button**

In the `<style>` block, add:

```css
.toggle-mode-btn {
    display: none;
    width: 70px;
    height: 40px;
    justify-content: center;
    align-items: center;
    color: white;
    font-size: 12pt;
    cursor: pointer;
    border: 1px solid white;
    border-radius: 4px;
    opacity: 0.7;
}

@media (hover: none) and (pointer: coarse) {
    .toggle-mode-btn {
        display: flex;
    }
}
```

**Step 5: Verify TypeScript and template compile**

Run: `pnpm check`
Expected: no errors

**Step 6: Commit**

```bash
git add src/PitchPipe.svelte
git commit -m "feat: add mobile hold/toggle mode button"
```

---

### Task 3: Manual testing

**Step 1: Start dev server**

Run: `pnpm dev`

**On desktop browser:**
- Confirm the hold/toggle button does NOT appear
- Confirm shift-click sustain still works

**On Android Chrome (or Chrome DevTools mobile emulation):**
- Confirm the hold/toggle button appears
- In hold mode: tap a note, it plays while held, stops on release
- In toggle mode: tap a note, it stays playing; tap again, it stops
- Confirm multiple notes can be toggled on simultaneously

**Step 2: Build to confirm no build errors**

Run: `pnpm build`
Expected: exits cleanly
