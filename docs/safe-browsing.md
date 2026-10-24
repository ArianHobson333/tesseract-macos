# Safe Browsing in Tesseract

Status: **not restored in M1** (spike done 2026-10-24, decision pending with
the owner). This file records why, and the options.

## What removes Safe Browsing today

Helium builds with `safe_browsing_mode=0` (`helium-chromium/flags.gn`). On its
own that flag would be easy to flip, but the code it would switch back on is
gone. These upstream steps remove or break it:

| Step | Effect | Needed only when `safe_browsing_mode=0`? |
|------|--------|------------------------------------------|
| `ungoogled-chromium/fix-building-without-safebrowsing.patch` | Deletes about 2,100 lines of Safe Browsing integration (downloads, enterprise connectors, interstitial wiring) unconditionally, with no `BUILDFLAG` guards | Yes, but it's not conditional: it must be dropped |
| `ungoogled-chromium/remove-unused-preferences-fields.patch` | Removes the Safe Browsing prefs and the code that reads them (about 450 changed lines touch Safe Browsing) | No: it serves other goals too, and later patches build on it |
| `pruning.list` | Deletes `components/safe_browsing/core/common/safe_browsing_prefs.{cc,h}` from the source tree | Yes |
| `inox-patchset/fix-building-without-safebrowsing.patch` | Stubs out Safe Browsing callers | Yes |
| `helium/core/fix-building-without-safebrowsing.patch` | Build fix for `components/resources` | Yes |
| `ungoogled-chromium/macos/fix-disabling-safebrowsing.patch` (macOS repo) | macOS build fixes, partly guarded by `FULL_SAFE_BROWSING` | Mostly yes |
| `domain_substitution` (`domain_regex.list`) | Rewrites `*.googleapis.com` in the Safe Browsing sources (77 files listed), so requests would go to a dead `*.qjz9zk` domain | Those files would need excluding |
| `iridium-browser/safe-browsing-disable-reporting.patch` | Turns off reporting to Google | Keep, if Safe Browsing comes back |

## Why "GN args only" doesn't work

Restoring needs all of the following, against Chromium source that patches
apply to with zero fuzz:

1. drop four patches and un-prune two files;
2. split `remove-unused-preferences-fields.patch` to bring back only the Safe
   Browsing prefs (it's one of ungoogled-chromium's largest patches, and other
   ungoogled and Helium patches apply on top of it);
3. exclude the Safe Browsing sources from domain substitution;
4. then re-check every later patch, on every Helium release.

Step 2 conflicts with the 24-hour Helium sync target: every Chromium bump
touches those prefs, and we'd be keeping a private split of a patch that
ungoogled-chromium maintains for the opposite goal. ungoogled-chromium itself
treats Safe Browsing as unsupported.

## What protects users meanwhile

Helium ships uBlock Origin, and its filter set includes the URLhaus
"Malicious URL Blocklist" (malware hosts). That's a blocklist, not
Google-grade coverage: no phishing-page heuristics, no download reputation.

## Options

1. **Ship M1 without Safe Browsing** (spec §11 option b): document the gap in
   the README and onboarding. Turn on uBlock Origin's "Phishing URL
   Blocklist" by default as well, as a cheap extra layer. *(Recommended for M1.)*
2. **Full restore** as above: weeks of work plus permanent merge cost on every
   Helium release.
3. **Later, a separate Safe Browsing v4 Update API client** in a Tesseract
   component (local hash-prefix database, full-hash check, our own
   interstitial), independent of the deleted Chromium code. Smaller merge
   surface, but it's new security-critical code.

The API key (`TESSERACT_SAFE_BROWSING_API_KEY`) isn't needed until option 2
or 3 is chosen.
