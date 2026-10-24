# Upstream touchpoints

Tesseract changes are additive layers on top of Helium. Every upstream file we
had to edit is listed here, so a Helium merge conflict can be traced to the
reason for the edit.

| File | Why | Owning task |
|------|-----|-------------|
| `.gitmodules` | `helium-chromium` points at `ArianHobson333/tesseract` | M1 Task 1 |
| `README.md` | Tesseract header above the upstream text | M1 Task 1 |
| `.gitignore` | Ignore local tool config, clean-room raw data, key files | M1 Task 1 |
