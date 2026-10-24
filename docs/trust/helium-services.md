# Helium services in Tesseract

Helium sends some traffic through its own server, `services.helium.imput.net`,
run by the Helium team (imput). Tesseract inherits this. This note lists what
uses it, from Helium's patches (`helium-chromium/patches/helium/core/`),
so the decision before a public release is an informed one.

## What goes through Helium services

Each feature has its own pref under `helium.services.*`, plus a master
switch (`enabled`) and a consent flag (`user_consented`). All of them can be
turned off in Settings → Privacy → Helium services, and the server can be
replaced with a self-hosted one (`origin_override`, HTTPS only).

| Pref | What it's for | Patch |
|------|---------------|-------|
| `ext_proxy` | Extension downloads from the Chrome Web Store, proxied | `proxy-extension-downloads.patch` |
| `ublock_assets` | uBlock Origin filter-list updates | `ublock-helium-services.patch` |
| `spellcheck_files` | Spell-check dictionary downloads | `reenable-spellcheck-downloads.patch` |
| `bangs` | Search shortcuts (`!g`-style bangs) | `services-prefs.patch` |
| `browser_updates` | Helium's own update checks | `add-updater-preference.patch` |

Tesseract's own updates come from its own appcast
(`arianhobson333.github.io`, M1 Task 6), not from Helium services.

## Why it matters

Whoever runs the server sees the IP address and timing of these requests
(which extensions are installed or updated, when filter lists refresh). It
can't see browsing history. It is a third party Tesseract users never chose.

## Decision

**Kept for M1** (owner's personal builds). Revisit before any public
release, per design spec §11. Options:

1. Keep, and say so clearly in onboarding.
2. Self-host the same service for Tesseract (`origin_override`).
3. Patch it out and fetch directly from the original sources.
