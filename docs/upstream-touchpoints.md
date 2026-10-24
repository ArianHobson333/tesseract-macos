# Upstream touchpoints

Tesseract changes are additive layers on top of Helium. Every upstream file we
had to edit is listed here, so a Helium merge conflict can be traced to the
reason for the edit.

| File | Why | Owning task |
|------|-----|-------------|
| `.gitmodules` | `helium-chromium` points at `ArianHobson333/tesseract` | M1 Task 1 |
| `README.md` | Tesseract header above the upstream text | M1 Task 1 |
| `.gitignore` | Ignore local tool config, clean-room raw data, key files | M1 Task 1 |
| `.github/workflows/*.yml`, `.github/actions/*/action.yml` | Third-party actions pinned to commit SHAs | M1 Task 2 |
| `.github/workflows/build.yml` | arm64 only; release job needs the `release` environment | M1 Task 2 |
| `.github/actions/do-build/action.yml` | Log disk usage after each build phase | M1 Task 2 |
| `.github/scripts/github_prepare_artifacts.sh` | Skip the signing keychain when no certificate secret is set (unsigned builds) | M1 Task 2 |
| `helium-chromium/patches/series`, `patches/series` | Append the `tesseract/` patch groups last | M1 Task 3 |
| `devutils/shared.sh` | Run `tesseract_substitution.py` right after Helium's name substitution | M1 Task 3 |
| `sign_and_package_app.sh`, `.github/scripts/github_prepare_artifacts.sh`, `dev.sh` | `Tesseract.app`, DMG name/volume, DMG signing identifier, dev profile dir | M1 Task 3 |
| `devutils/generate_sparkle_deltas.py` | Deltas diff `Tesseract.app` | M1 Task 3 |
| `resources/dmg.json`, `devutils/generate_dmg_dsstore.sh` | DMG layout uses `Tesseract.app` (`resources/dmg_dsstore` still needs regenerating) | M1 Task 3 |
