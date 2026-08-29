# KLTsup — User Guide

A step-by-step guide to **KLTsup** (supervised KLT-based fascicle tracking)
through its GUI app `FascicleTrackerApp` — ultrasound fascicle tracking with
automatic tracking, manual validation, and comparison.

See [README.md](README.md) for requirements and folder layout.

---

## 1. Quick start (5 steps)

1. In MATLAB, `cd` into the `CODICE` folder and run:
   ```matlab
   >> FascicleTrackerApp
   ```
2. **Load video…** — pick an mp4/avi clip. Frame rate, frame count and crop are
   auto-filled from the video.
3. On the **Preview** tab, scrub to a clear frame and click **Draw crop** to box
   the ultrasound image region (or leave the full frame).
4. Click **Initialize & Track**. Follow the pop-up prompts: confirm the
   auto-detected aponeuroses, then **draw the fascicle** on the same window.
5. When it finishes, the **Results** tab shows pennation, length and the Hough
   signal. Results auto-save to a `tracked/…/TrackedData.mat` next to the video.

That's a full automatic track. Everything below is detail and extras.

---

## 2. Window layout

- **Left panel** — all setup fields and the action buttons.
- **Right panel** — a status line plus two tabs:
  - **Preview** — the video, a frame slider, crop/overlay tools.
  - **Results** — pennation / length / Hough plots and comparison tools.

---

## 3. Setup panel (left)

### Video
- **Load video (mp4/avi)…** — choose the clip. Fills the info line
  (`N frames @ fps`), the trial name, frame rate, last frame and crop.
- **Trial name** — used for saved files and the results key (edit if you like).

### Frames & timing
| Field | Meaning |
|-------|---------|
| **Frame rate (Hz)** | acquisition rate; sets the time axis and the Hough filter. Auto-filled from the video. |
| **Hough cutoff (Hz)** | low-pass cutoff for the Hough signal used by the supervised controls (and shown on the Results Hough plot). |
| **First / Last frame** | range of frames to track. Typing a value jumps the preview there. |
| **Frame step** | tracking stride (1 = every frame). |
| **Validation step** | frame spacing for manual/validation drawing. |

### Image geometry
- **Depth (mm)** / **Probe width (mm)** — physical size of the (cropped) image;
  they set the mm-per-pixel scaling, so fascicle length is in mm.
- **Crop x / y / width (nx) / height (ny)** — the ultrasound image region.
  Easiest to set with **Draw crop** on the Preview tab.

### Acquisition
- **Superficial apo visible** — untick if the superficial aponeurosis is out of view.
- **Flip horizontally** — tick so fascicles run bottom-left → top-right.
- **Number of fascicles** — how many fascicles to track (usually 1).

### Tracking parameters (KLT)
Optical-flow settings (block size, pyramid levels, bidirectional error, max
points, re-seed thresholds) and **Save tracked video**. Defaults are sensible;
change only if tracking is unstable.

### Supervised controls
The Hough-signal drift-correction that makes the EM method "supervised".
- **Use supervised controls** — master switch. Ticking it selects all
  sub-controls; unticking gives **plain KLT** (no correction). Individual checks:
  - **Periodic re-seed** (+ Re-seed segments)
  - **Derivative agreement** (+ Deriv-agree fraction)
  - **Min-max diff (peaks)** (+ threshold)
  - **Length jump** (+ threshold, mm)
  - **Pennation range** (+ min / max, deg)
- When a control detects a bad frame during tracking, a **"Re-track the fascicle
  here?"** dialog appears — **Yes** lets you redraw the fascicle at that frame.

---

## 4. Preview tab

- **Slider** — scrub through frames. The dashed yellow box shows the current crop.
- **Draw crop** — click-drag a rectangle to set the crop (fills the Crop fields).
  **Reset crop** returns to the full frame.
- **Set first / Set last** — stamp the current frame into the First/Last fields.
- **Play / Pause** — preview playback.
- **Overlay tracking** — after a track, overlays the tracked aponeuroses and
  fascicle(s) on the frame (EM blue/yellow/red, informed manual green, pure
  manual magenta). The line under the video shows numeric length & pennation
  (`L=… φ=…`) for each series at the current frame.

---

## 5. Running a track

- **Initialize & Track** — full automatic tracking with initialization. You'll
  be asked to confirm the aponeuroses and draw the fascicle once (on one window).
- **Track from reference init…** — reuse a previous run's initialization on a new
  clip of the **same geometry** (no re-drawing). Prompts for a `TrackedData.mat`.
- **Load tracked result (display)…** — just display a saved result (no tracking).

During a run the pipeline shows its own dialogs/figures — that's expected.

---

## 6. Manual tracking (independent)

**Manual tracking (no auto)…** does fully manual tracking with **no** automatic
step (a "pure manual" reference).

On each sampled frame:
1. **Frame 1** — draw each line by click-drag (deep apo → superficial apo →
   fascicle).
2. **Later frames** — the previous frame's lines are pre-placed; just drag the
   endpoints.
3. Confirm/adjust with the keys below.

| Key | Action |
|-----|--------|
| **Space / Enter** (or **Confirm** button) | accept the frame, go to the next |
| **R** | redraw all lines from scratch |
| **1 / 2 / 3 …** | redraw one structure (1 = deep apo, 2 = sup apo, 3+ = fascicle) |
| **Esc** (or close window) | stop (keeps frames done so far) |

Result → the **magenta "Pure manual"** curve.

---

## 7. Validation (informed manual)

To validate an **existing auto track**: run **Initialize & Track**, and when the
*"Approve tracking trial"* dialog appears, choose **Validate** instead of Yes.
You then correct the **fascicle** on sampled frames (aponeuroses are kept from
the auto track). Same keys as manual tracking.

Result → the **green "Informed manual"** curve.

---

## 8. Results tab

- **Plots** — fascicle angle (top), fascicle length (middle), Hough signal (bottom,
  raw grey + filtered at the current Hough cutoff).
- **Series toggles** — **EM (auto) / Informed manual / Pure manual** checkboxes
  show/hide each series (in the plots and the preview overlay).
- **Agreement readout** — under each plot: RMSE and Pearson r, EM-vs-informed
  and EM-vs-pure.
- **Frame cursor** — a vertical line marks the current preview frame; scrub the
  preview to move it.
- **Bland-Altman** — opens EM-vs-manual Bland–Altman plots (bias ± 1.96 SD limits
  of agreement) for fascicle angle and length.
- **Pop out** — opens the plots in a separate, live-synced window so you can view
  Preview and Results side by side.

Changing **Frame rate** rescales the time axis live; changing **Hough cutoff**
re-filters the Hough overlay live.

---

## 9. Saving & exporting

- **Save results…** / auto-save — writes `TrackedData.mat` (all series + params).
- **Export CSV…** — writes `<name>_timeseries.csv` (frame, time, and each series'
  pennation & length) and `<name>_metrics.csv` (RMSE + Pearson r per comparison).
- **Save settings… / Load settings…** — save all GUI field values to a `.mat`
  preset and reload them (for reproducibility across clips).

---

## 10. Tips & troubleshooting

- **Get the crop and depth/probe right first** — they set the mm scaling; wrong
  values give wrong lengths.
- **Frame rate should match acquisition** — it drives the time axis and the Hough
  filter used by the controls.
- **Reference / overlay assume the same clip geometry.** Overlaying or reusing an
  init on a differently-cropped video won't line up.
- **Too many re-track pop-ups?** Loosen the control thresholds (or untick some
  sub-controls), or turn **Use supervised controls** off for plain KLT.
- **"Unable to resolve vision.*"** — the Computer Vision Toolbox isn't installed
  (see README requirements).
- **Old saved results:** a standalone manual saved before the pure/informed split
  will display as "Informed manual" (green).
