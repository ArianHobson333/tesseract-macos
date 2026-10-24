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
| `.github/actions/do-build/action.yml` | Log disk usage after each build phase; expose the Actions cache to sccache | M1 Task 2 |
| `.github/scripts/github_prepare_artifacts.sh` | Skip the signing keychain when no certificate secret is set (unsigned builds) | M1 Task 2 |
