# Syncing with Helium

Tesseract is two repos that mirror Helium's layout:

| Ours | Upstream | Role |
|------|----------|------|
| `ArianHobson333/tesseract-macos` (this repo) | `imputnet/helium-macos` | macOS packaging, CI, signing, updates |
| `ArianHobson333/tesseract` (submodule `helium-chromium`) | `imputnet/helium` | core patches, branding, utils |

Both repos have an `upstream` remote pointing at imputnet. Helium security
releases should reach a Tesseract build within 24 hours.

## Merging a new Helium release by hand

1. Core repo first:
   ```sh
   cd helium-chromium
   git fetch upstream --tags
   git merge <helium-core-commit-for-the-release>
   git push origin main
   ```
2. Then this repo:
   ```sh
   cd ..
   git fetch upstream --tags
   git merge <helium-macos-tag>      # e.g. 0.20.1.1
   ```
   The upstream merge moves the submodule pointer to imputnet's commit. Point
   it back at our merged core commit:
   ```sh
   git -C helium-chromium checkout main
   git add helium-chromium
   git commit -m "sync: Helium <tag>"
   ```
3. Check `.gitmodules` still points at `ArianHobson333/tesseract`.
4. Resolve conflicts using `docs/upstream-touchpoints.md`: each listed file
   says why we changed it. Tesseract patches live in `patches/tesseract/` and
   are appended last in `patches/series`, so they rarely conflict.
5. Push to a `sync/<tag>` branch and open a PR; CI must build before merge.

An automated job does the same every 6 hours (added in M1 Task 8).
