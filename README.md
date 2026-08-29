# KLTsup — supervised muscle fascicle tracking

**KLTsup** is the supervised, KLT-based fascicle-tracking method described in
Cesti et al. (see [Citation](#citation)). This repository provides its
open-source MATLAB implementation: automatic optical-flow (KLT) tracking with an
FFT/Hough image enhancement and a **supervision module** (Hough-signal
drift-correction), plus manual tracking, validation and method-comparison tools.

Built on
Josh Baxter's (UPenn) optical-flow (KLT) tracker (https://github.com/joshrbaxter/ultrasound_tracking) 
and extended with an FFT/Hough ("EM") method plus a supervised drift-correction layer. 
Two tracking methods run in parallel on each clip: `automatic_traditional` (Drazan-style optical flow) and
`automatic_EM` (frequency-domain enhanced) — the latter is the one benchmarked
against UltraTimTrack.

A GUI app (`FascicleTrackerApp`) drives the whole workflow — load a video, track,
manually validate, compare, and export.

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
├── tracking/               Core tracking engine
│   ├── trackfascicle.m         orchestrates one trial (called by main/app)
│   ├── initializepoints.m      first-frame seeding + aponeurosis Hough detection
│   ├── trackpoints.m           per-frame KLT loop + supervised controls
│   ├── trackablepoints.m       ROI feature-point detection / re-seeding
│   └── trackpoints_validate.m  informed manual validation (apo from auto)
│
├── image_processing/       In-pipeline image operations
│   ├── preprocessing.m         per-frame crop / contrast / sharpen
│   ├── Tissue_angle.m          FFT muscle-belly enhancement 
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

## What the app produces

Per trial, three tracking series (when available), all directly comparable:

| Series | Source | Colour |
|--------|--------|--------|
| **EM (auto)** | automatic FFT/Hough + KLT tracking | red / blue |
| **Informed manual** | manual validation *after* an auto run (aponeuroses from auto, you draw the fascicle) | green ○ |
| **Pure manual** | fully independent manual tracking (you draw everything) | magenta □ |

Outputs: `TrackedData.mat` (auto-saved), CSV export (time series + agreement
metrics), Bland–Altman plots, and RMSE / Pearson-r readouts.

## Citation

If you use **KLTsup** in your research, please cite the paper that describes it:

> Cesti E., Carbonaro M., Boccardo M., Truscello F., Seoni S., Cerone G. L.,
> Meiburger K. M., Raiteri B. J., Botter A. *Ultrasound-based methods to track
> skeletal muscle architecture in dynamic tasks: a comparative study.* (year).
> [DOI to be added]

The KLTsup approach was first introduced in:

> Cesti E. et al. *Ultrasound-based assessment of gastrocnemius architecture
> during locomotion: analysis of fascicle tracking accuracy along the gait
> cycle.* Annual Int. Conf. IEEE Eng. Med. Biol. Soc. (EMBC), Copenhagen,
> Jul. 2025.

A citable software DOI will also be minted via Zenodo when the repository is
made public.

## Authors

Software developed by **Marco Carbonaro**, **Elena Cesti**, **Marta Boccardo**,
and **Francesca Truscello** (Politecnico di Torino).

## Acknowledgements

This software builds on the semi-automatic KLT ultrasound fascicle tracker by
**Josh R. Baxter** (University of Pennsylvania),
<https://github.com/joshrbaxter/ultrasound_tracking>, from which portions of the
tracking pipeline are derived — we gratefully acknowledge that work. Comparisons
are made against **UltraTimTrack**
(<https://github.com/timvanderzee/UltraTimTrack>). See `NOTICE` for attribution
details.

## Notes / known limitations

- The deep tracking functions are still **interactive**: initialization and the
  supervised re-track prompt pop MATLAB dialogs during a run. The app wraps setup
  and results around them.
- Temporary flipped videos are written to MATLAB's `tempdir`.
- Some persisted parameter fields keep their original Italian names
  (e.g. `Params.punti_di_controllo`, `Params.ritracciati`) to stay compatible
  with already-saved `.mat` result files.

