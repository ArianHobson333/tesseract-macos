# Performance baseline

Measures what Tesseract is meant to fix: energy use and memory pressure with
many tabs open on an 8 GB M2.

## Running

```sh
sudo -v   # optional: lets powermetrics fill the energy_impact column
python3 tools/perf/run_benchmark.py --browser /Applications/Tesseract.app \
  --minutes 60 --out tools/perf/results/2026-10-24/tesseract.csv
```

- Chromium browsers (Tesseract, Helium, Chrome, Arc, Dia) start with a
  throwaway profile and open the 50 pages in `corpus.txt` through the
  DevTools port. Tab 1 is focused, so the other 49 are background tabs.
  Quit the browser first.
- Safari: add `--no-cdp --process-prefix Safari --process-prefix com.apple.WebKit`.
  Pages open in the normal Safari profile.
- Run on battery, at a fixed screen brightness, with other apps quit.

## Output

One CSV row per minute: `t_min, browser, energy_impact, top_power, swapins,
swapouts, pages_compressed`.

- `energy_impact`: summed powermetrics Energy Impact of the browser's
  processes (empty without sudo).
- `top_power`: summed `top` POWER of processes matching the prefix. top cuts
  names to 16 characters, so the prefix is cut too.
- `swapins`, `swapouts`: system-wide cumulative counters; compare the
  difference between the first and last rows.
- `pages_compressed`: pages currently held in the memory compressor.

## Tests

`python3 -m pytest tools/perf/tests`. The `top` and `vm_stat` fixtures follow
output captured on the owner's Mac (process rows changed to Tesseract). The
powermetrics fixture follows the documented `--samplers tasks` layout and
should be replaced with a real capture (`sudo powermetrics --samplers tasks -n 1`).

## Results

| Date | Browser | Median top_power | Swapouts (delta) | Notes |
|------|---------|------------------|------------------|-------|
| | | | | |
