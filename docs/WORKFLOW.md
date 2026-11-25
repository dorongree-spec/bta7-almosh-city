# How this repo is worked on

This is how the original authors work day to day. If you want to contribute,
[CONTRIBUTING.md](../CONTRIBUTING.md) is the guide for you; the photo tour and
export sections below are useful to everyone.

Two sides commit to `main`:

- **Cloud side** writes game systems (new scripts, gameplay, generators) but
  cannot run Godot. Its code is syntax-checked with `gdparse` only.
- **PC side** has Godot 4.3 and a GPU. It pulls, runs, fixes script and
  runtime errors, tunes numbers that can only be judged by eye (lighting,
  physics feel, colours, sizes) and saves screenshots to `docs/screenshots/`.

To keep merges painless:

- Always `git pull --rebase origin main` before pushing.
- PC-side fixes should stay local to the failing lines; note anything larger
  in `docs/RUN_NOTES.md` (what looked wrong, what was changed, fps) so the
  cloud side can see it without a screenshot.
- Screenshots come from the built-in photo tour, which plays through a
  fixed set of views, saves a JPEG of each and quits:

  ```
  godot --path . -- --tour
  ```

  It writes `docs/screenshots/*.jpg` (`start`, `car`, `car_model`, `person`,
  `old_city`, `shikun`, `driving`, `handbrake`, `night`, `haze`, `map`) and
  `docs/screenshots/tour.txt` with the frame rate at each view. Commit them
  as they are; the same names are overwritten every run.

## A build for friends

`export_presets.cfg` holds one Windows preset. On the PC side:

```
godot --headless --export-release "Windows Desktop" export/BTA7AlmoshCity.exe
```

writes a single self-contained `export/BTA7AlmoshCity.exe` (the `export/` folder
is git-ignored). It needs the Godot 4.3 export templates installed.

