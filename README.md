# CODICE — FFT/HFR ultrasound fascicle tracking

MATLAB pipeline for automatic fascicle tracking in B-mode ultrasound, based on
Josh Baxter's (UPenn) optical-flow (KLT) tracker and extended with an FFT/Hough
("EM") method plus a supervised drift-correction layer. Two tracking methods run
in parallel on each clip: `automatic_traditional` (Drazan-style optical flow) and
`automatic_EM` (frequency-domain enhanced) — the latter is the one benchmarked
against UltraTimTrack.

A GUI app (`FascicleTrackerApp`) drives the whole workflow — load a video, track,
manually validate, compare, and export — without the original `.mat` clip-list.

👉 **New here? Read [USER_GUIDE.md](USER_GUIDE.md) for a step-by-step quick start.**

## Requirements

- **MATLAB R2021b or newer** (developed/tested on R2025b).
- Toolboxes:
  - **Computer Vision Toolbox** — required (KLT `vision.PointTracker`,
    `detectSIFTFeatures`, `detectMinEigenFeatures`, `insertShape/Marker/Text`).
    Without it the pipeline cannot run.
  - **Image Processing Toolbox** — required (`imwarp`, `fibermetric`, `hough`,
    `drawline`, `imcrop`, …).
  - **Signal Processing Toolbox** — required (`butter`, `filtfilt`, `findpeaks`).
  - **Statistics and Machine Learning Toolbox** — required (`prctile`).

## Folder structure

```
CODICE/
├── FascicleTrackerApp.m    Entry-point GUI app  ( >> FascicleTrackerApp )  ← start here
├── setup_paths.m           Adds all subfolders to the MATLAB path
├── README.md               This file
├── USER_GUIDE.md           Quick-start / user manual
│
├── scripts/
│   └── main_FFT_HFR.m      legacy entry-point SCRIPT (.mat clip-list workflow)
│
├── tracking/               Core tracking engine
│   ├── trackfascicle.m         orchestrates one trial (called by main/app)
│   ├── initializepoints.m      first-frame seeding + aponeurosis Hough detection
│   ├── trackpoints.m           per-frame KLT loop + supervised controls (EM path)
│   ├── trackablepoints.m       ROI feature-point detection / re-seeding
│   └── trackpoints_validate.m  informed manual validation (apo from auto)
│
├── image_processing/       In-pipeline image operations
│   ├── preprocessing.m         per-frame crop / contrast / sharpen
│   ├── Tissue_angle.m          FFT muscle-belly enhancement (EM method)
│   └── hough_fas.m             fascicle-angle estimate via Hough transform
│
├── enhancement/            Standalone, shareable image enhancement
│   ├── enhanceUSImage.m        preprocessing + FFT enhancement, no Params/Data
│   └── demo_enhancement.m      demo script for enhanceUSImage
│
├── geometry/               Fascicle geometry
│   ├── calculatefascicle.m     length + pennation from tracked points
│   └── linesintersect.m        two-line intersection
│
├── config/
│   └── tracking_params.m       default tracking + control parameters
│
├── plotting/
│   └── plottrial.m             overlay lines/points on frames
│
└── video/                  Sample clips (not code)
```

## Getting started

1. In MATLAB, `cd` into this `CODICE` folder.
2. Launch the app: `>> FascicleTrackerApp`
3. Follow **[USER_GUIDE.md](USER_GUIDE.md)**.

Both entry points call `addpath(genpath(...))` on startup, so the subfolders are
added to the path automatically. To use `demo_enhancement` on its own, run
`>> setup_paths` first.

The legacy **script** (`main_FFT_HFR.m`) still works but uses the old
`list_of_clips.mat` workflow and requires two external helpers not shipped here
(`selezione_incl_fascicoli`, `getMetrics` + a `BlandAltman` toolbox). **Prefer
the app** — it replaces all of those.

## What the app produces

Per trial, three tracking series (when available), all directly comparable:

| Series | Source | Colour |
|--------|--------|--------|
| **EM (auto)** | automatic FFT/Hough + KLT tracking | red / blue |
| **Informed manual** | manual validation *after* an auto run (aponeuroses from auto, you draw the fascicle) | green ○ |
| **Pure manual** | fully independent manual tracking (you draw everything) | magenta □ |

Outputs: `TrackedData.mat` (auto-saved), CSV export (time series + agreement
metrics), Bland–Altman plots, and RMSE / Pearson-r readouts.

## Notes / known limitations

- The deep tracking functions are still **interactive**: initialization and the
  supervised re-track prompt pop MATLAB dialogs during a run. The app wraps setup
  and results around them. (The EM initialization pass is silent — only the
  traditional pass asks for input.)
- Temporary flipped videos are written to MATLAB's `tempdir`.
- Some persisted parameter fields keep their original Italian names
  (e.g. `Params.punti_di_controllo`, `Params.ritracciati`) to stay compatible
  with already-saved `.mat` result files.
- Code has been reorganized and commented in English; a few standalone helper
  functions from the original project (`getMetrics`, `selezione_incl_fascicoli`)
  are intentionally not included because the app supersedes them.
