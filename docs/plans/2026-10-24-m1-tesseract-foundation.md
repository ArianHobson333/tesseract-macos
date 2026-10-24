# M1: Tesseract Foundation Implementation Plan


**Goal:** A Tesseract-branded fork of Helium that builds on free GitHub Actions
macOS runners, is signed and notarized, restores Safe Browsing, auto-updates
via Sparkle from our own appcast, and tracks Helium releases within 24 h. No
UI changes yet.

**Architecture:** Mirror Helium's two-repo layout so upstream merges stay
mechanical. `tesseract` is a fork of `imputnet/helium` (core patches,
branding, utils). `tesseract-macos` is a fork of `imputnet/helium-macos`
(macOS packaging, CI, signing, Sparkle) and holds the core repo as the
`helium-chromium` submodule. All Tesseract changes are **additive layers**:
a `patches/tesseract/` patch group appended last in each `patches/series`, a
post-pass substitution script, our own branding resources and CI secrets.
Upstream files are edited only where a hook is unavoidable, and each such
edit is listed in `docs/upstream-touchpoints.md`.

**Tech Stack:** Chromium (via Helium/ungoogled-chromium), GN, quilt patches,
Python 3 (stdlib + pytest), Bash, GitHub Actions (macOS arm64 runners),
Sparkle 2 (EdDSA), Apple notarytool.

**Spec:** `docs/specs/2026-10-24-tesseract-browser-design.md` (v3, approved).

## Global Constraints

- Licence: Tesseract code is **GPL-3.0**; keep `LICENSE.ungoogled_chromium`
  (BSD-3) and all upstream notices intact.
- Product name `Tesseract`; company/authors string `The Tesseract Authors`;
  bundle ID **`io.github.arianhobson333.tesseract`** (planner's call, since
  there's no owned domain; changing it after release breaks updates and profiles).
- Architecture: **arm64 only** for M1 (drop the x86_64 matrix leg).
- GitHub owner: `ArianHobson333`. Repos `tesseract` and `tesseract-macos`
  are **public** (free macOS minutes). Creating them requires the owner's
  explicit go-ahead at execution time.
- Secrets (Developer ID cert, notary credentials, Sparkle private key, Safe
  Browsing API key) are entered **by the owner** in GitHub repo settings.
  Never paste them into files, logs or chat.
- Signing/release secrets live in a GitHub **environment `release`** with
  required reviewer = owner. PR builds from forks never get secrets.
- All third-party GitHub Actions pinned by full commit SHA.
- Security patch target: a Tesseract build shipped **within 24 h of a Helium
  release**.
- No telemetry and no new network endpoints, except our appcast host
  (`arianhobson333.github.io`) and Google Safe Browsing.
- Repo text, commits and PRs: no AI/assistant attribution or mentions
  (owner's global rule). No co-author trailers.
- Chromium checkout paths must contain no spaces (the SSD is now `/Volumes/AriSSD`).
- Full Chromium builds happen in CI only. The owner's Mac (M2, 8 GB) runs
  builds, tests Python/shell tooling, and runs the perf harness.

## Review Focus

1. **Helium version with no matching upstream tag or a failed patch apply**:
   the sync job must stop with a clear failing check, never publish. Test lives in Task 8.
2. **Partially failed release** (build passes, notarization fails): no appcast
   entry is published, so users are never offered an unnotarized build. Test lives in Task 7.
3. **Substitution over-reach**: "Helium" inside URLs, licence text, credits
   and the Chrome Web Store / Root Program names must not be rewritten. Test lives in Task 3.
4. **Upgrade from stock Helium**: Tesseract uses its own bundle ID and profile
   directory and never reads or writes `~/Library/Application Support/net.imput.helium`.
   Test lives in Task 3.
5. **Appcast signature mismatch** (wrong key or tampered DMG): Sparkle rejects
   the update. Task 6's verification proves rejection with a deliberately wrong key.

---

### Task 1: Fork the repos and set up the workspace

**Files:**
- Create: `/Volumes/AriSSD/dev/Tesseract/` as a git clone of `tesseract-macos`
  (existing `docs/` carried over; no clash with upstream `docs/building.md`)
- Modify: `.gitmodules` (submodule `helium-chromium` URL → `https://github.com/ArianHobson333/tesseract.git`)
- Create: `docs/upstream-touchpoints.md`, `docs/syncing-upstream.md`
- Modify: `README.md`, `.gitignore` (add `cleanroom-raw/`, `*.p12`, `*.pem`, `build/`)

**Interfaces:**
- Produces: remotes `origin` (ours) and `upstream` (imputnet) in both repos;
  branch `main` in both, at the same Helium release tag.

- [ ] **Step 1:** Ask the owner to confirm creating two public repos under
      `ArianHobson333`. Stop if not confirmed.
- [ ] **Step 2:** `gh repo fork imputnet/helium --clone=false --fork-name tesseract`
      and `gh repo fork imputnet/helium-macos --clone=false --fork-name tesseract-macos`.
- [ ] **Step 3:** Clone `tesseract-macos` into a temp dir on `/Volumes/AriSSD`,
      move `.git` and the upstream files into `/Volumes/AriSSD/dev/Tesseract`
      (keep the existing `docs/specs`, `docs/plans`), then
      `git remote add upstream https://github.com/imputnet/helium-macos.git`.
- [ ] **Step 4:** Repoint the submodule and pin both repos to the latest Helium
      release tag. Verify: `git submodule status` shows `helium-chromium` at the
      same tag as `upstream`'s submodule pointer for that release.
- [ ] **Step 5:** Write `docs/syncing-upstream.md` (how to merge a new Helium
      tag into both repos) and an empty touchpoints table in
      `docs/upstream-touchpoints.md` (columns: file, why, owning task).
- [ ] **Step 6:** Verify: `git status` is clean apart from the new docs;
      `grep -r "cleanroom-raw" .gitignore` matches.
- [ ] **Step 7: Commit** `chore: fork Helium as Tesseract, add design docs`.

### Task 2: Prove a vanilla build on free GitHub runners (gate)

**Files:**
- Modify: `.github/workflows/build.yml` (matrix `arch: [arm64]`; default runner
  `macos-latest`; release job gated by `environment: release`)
- Create: `docs/ci-baseline.md`

**Interfaces:**
- Consumes: Task 1 repos.
- Produces: a green `Build macOS binaries` run producing an **unsigned** arm64
  `.dmg` artifact; measured numbers in `docs/ci-baseline.md`.

- [ ] **Step 1:** Make the matrix and runner changes; pin every `uses:` to a
      commit SHA (look up each action's current release SHA). List
      `build.yml` in `docs/upstream-touchpoints.md`.
- [ ] **Step 2:** Push and trigger: `gh workflow run build.yml -f do-release=false`.
- [ ] **Step 3:** Watch: `gh run watch`. Expected: retrieve-resources plus N
      chained `build_job_XX` phases, final status success, artifact
      `*.dmg` present (`gh run view --log | grep -i dmg`).
- [ ] **Step 4:** Record in `docs/ci-baseline.md`: total wall time, number of
      phases used, peak disk use (from the `df -h` log line the workflow
      prints, or add one), runner image.
- [ ] **Step 5:** **Gate.** If the build can't finish within the chained
      phases, or runs out of disk, stop and report to the owner with numbers.
      Fallbacks to present: more phases, a disk-cleanup step, or a
      self-hosted runner. Don't continue to Task 3 on a red baseline.
- [ ] **Step 6:** Download the DMG and launch it on the owner's Mac
      (right-click → Open, since it's unsigned). Expected: stock Helium starts.
- [ ] **Step 7: Commit** `ci: arm64-only free-runner build, pinned actions`.

### Task 3: Rebrand to Tesseract

**Files:**
- Create (core repo): `patches/tesseract/core/tesseract-branding.patch`
  (modifies `chrome/app/theme/chromium/BRANDING` and the crash-reporter product name, on top of Helium's branding patch)
- Modify (core repo): `patches/series` (append `tesseract/core/tesseract-branding.patch` as the last line)
- Create (core repo): `utils/tesseract_substitution.py`, `utils/tests/test_tesseract_substitution.py`
- Create (core repo): `resources/tesseract_branding/` (icons, same filenames as `resources/branding/`), `resources/tesseract_resources.txt`
- Modify (macos repo): `devutils/shared.sh` (call the post-pass right after `name_substitution.py --sub`, and apply `tesseract_resources.txt` after `helium_resources`)
- Modify (macos repo): any `net.imput.helium` / Helium product strings in macOS packaging (find with `grep -rn "net.imput.helium\|Helium" --include=*.sh --include=*.plist --include=*.gn .`)

**Interfaces:**
- Produces: `replace_text(text: str) -> tuple[str, bool]` in
  `utils/tesseract_substitution.py`; CLI `python3 utils/tesseract_substitution.py -t <src_dir>`.
  Built app: `Tesseract.app`, `CFBundleIdentifier = io.github.arianhobson333.tesseract`,
  profile dir `~/Library/Application Support/Tesseract`.

- [ ] **Step 1: Write the failing tests** in `utils/tests/test_tesseract_substitution.py`:

```python
import pytest
from tesseract_substitution import replace_text

@pytest.mark.parametrize("src,expected", [
    ("Helium", "Tesseract"),
    ("About Helium", "About Tesseract"),
    ("helium://settings", "tesseract://settings"),
    ("Helium Helium", "Tesseract Tesseract"),
])
def test_rewrites_product_name(src, expected):
    assert replace_text(src) == (expected, True)

@pytest.mark.parametrize("src", [
    "https://services.helium.imput.net",
    "https://updates.helium.computer/mac/appcast-arm64.xml",
    "Copyright 2025 The Helium Authors",
    "github.com/imputnet/helium",
    "net.imput.helium",
    "Chrome Web Store",
    "Chrome Root Program",
])
def test_leaves_urls_credits_and_ids_alone(src):
    assert replace_text(src) == (src, False)
```

- [ ] **Step 2:** Run `cd helium-chromium && python3 -m pytest utils/tests/test_tesseract_substitution.py -v`.
      Expected: FAIL (module not found).
- [ ] **Step 3:** Implement `replace_text` plus a CLI that walks the source
      tree with the same `IGNORE_DIRS` and file-type filter as Helium's
      `name_substitution.py` (reuse `name_substitution_utils` for file
      selection; only the regex differs). Rewrite whole-word `Helium` →
      `Tesseract` and the `helium://` scheme → `tesseract://`. Skip matches
      inside URLs (`[\w.-]*helium[\w.-]*\.(net|computer|com)`), `The Helium
      Authors`, `imputnet/helium` and reverse-DNS IDs.
- [ ] **Step 4:** Run the tests. Expected: PASS.
- [ ] **Step 5:** Write `tesseract-branding.patch`: `PRODUCT_FULLNAME=Tesseract`,
      `PRODUCT_SHORTNAME=Tesseract`, `COMPANY_FULLNAME=The Tesseract Authors`,
      `MAC_BUNDLE_ID=io.github.arianhobson333.tesseract`, crash-reporter
      `product_name = "Tesseract"`. Create it with quilt against a Helium
      source tree as described in `docs/building.md` ("Creating a new patch").
      Append it to `patches/series`.
- [ ] **Step 6:** Add placeholder icons (owner-supplied artwork later; a plain
      generated tesseract glyph is fine for M1) under `resources/tesseract_branding/`
      plus a `tesseract_resources.txt` mapping in Helium's format. Hook both into `shared.sh`.
- [ ] **Step 7:** Verify the patch applies without a full build: in CI, add a
      job `patch-check` that runs Helium's existing patch-validation devutil
      (see `devutils/`; the `sanity.yml` workflow already does this) on every PR.
      Expected: green.
- [ ] **Step 8:** Full CI build (Task 2 workflow). Verify on the downloaded DMG:
      `defaults read /Volumes/Tesseract/Tesseract.app/Contents/Info.plist CFBundleIdentifier`
      → `io.github.arianhobson333.tesseract`. Launch it: the window title and
      About page say Tesseract. Check `~/Library/Application Support/Tesseract`
      exists and that `net.imput.helium`'s folder modification time is unchanged.
- [ ] **Step 9:** Add every modified upstream file to `docs/upstream-touchpoints.md`.
- [ ] **Step 10: Commit** (both repos) `feat: Tesseract branding layer`.

### Task 4: Restore Safe Browsing (timeboxed, 3 days)

**Files:**
- Create (core repo): `patches/tesseract/core/restore-safe-browsing.patch` (only if source changes are needed)
- Modify (macos repo): `devutils/shared.sh` `configure_build`: when env
  `TESSERACT_SAFE_BROWSING_API_KEY` is set, append `safe_browsing_mode=1`
  and `google_api_key="$TESSERACT_SAFE_BROWSING_API_KEY"` to the generated
  args, overriding `flags.gn`'s `safe_browsing_mode=0` / `google_api_key=""`
- Modify: `.github/workflows/build-phase.yml` (pass the secret into "Prepare for building")
- Create: `docs/safe-browsing.md`

**Interfaces:**
- Produces: builds where Settings › Privacy shows Safe Browsing "Standard
  protection" on by default, using a key restricted to the Safe Browsing API.

- [ ] **Step 1:** Spike locally without building: list the patches that
      strip Safe Browsing (`patches/series` entries with `safebrowsing` in the
      name: inox `fix-building-without-safebrowsing`, iridium
      `safe-browsing-disable-reporting`, ungoogled
      `fix-building-without-safebrowsing`, helium `fix-building-without-safebrowsing`,
      macOS `fix-disabling-safebrowsing`) and record in `docs/safe-browsing.md`
      which of them are needed only when `safe_browsing_mode=0`.
- [ ] **Step 2:** Decide the minimal change: GN args only (preferred) or
      also dropping/reversing specific patches via the `tesseract` layer.
      Keep `safe-browsing-disable-reporting` (no reporting to Google).
- [ ] **Step 3:** The owner creates a Google Cloud API key restricted to the
      Safe Browsing API and stores it as secret `TESSERACT_SAFE_BROWSING_API_KEY`
      in the `release` environment. (The key ends up embedded in the
      binary, as with every Chromium build. API restriction limits misuse.)
- [ ] **Step 4:** CI build. Verify: open
      `https://testsafebrowsing.appspot.com/s/phishing.html` → red interstitial;
      `https://testsafebrowsing.appspot.com/s/malware.html` → interstitial.
- [ ] **Step 5:** **Timebox gate.** If it isn't green after 3 days of work,
      stop. Document the blocker in `docs/safe-browsing.md`, ship M1 with
      the gap documented (spec §11 option b), and open an issue.
- [ ] **Step 6: Commit** `feat: restore Google Safe Browsing (v4, no reporting)`.

### Task 5: Signing and notarization

**Files:**
- Modify: `.github/workflows/build-phase.yml`, `.github/workflows/build.yml`
  (signing secrets read only in jobs with `environment: release`)
- Create: `docs/release-secrets.md` (names and purpose of each secret, how to rotate; no values)

**Interfaces:**
- Consumes: Helium's existing signing hooks (`MACOS_CERTIFICATE*`,
  `PROD_MACOS_NOTARIZATION_*` env vars, `sign_and_package_app.sh`).
- Produces: a signed, notarized, stapled `Tesseract-<version>-arm64.dmg`.

- [ ] **Step 1:** Write `docs/release-secrets.md` listing exactly the secrets
      Helium's workflow reads: `PROD_MACOS_CERTIFICATE`,
      `PROD_MACOS_CERTIFICATE_PWD`, `PROD_MACOS_CERTIFICATE_NAME`,
      `PROD_MACOS_CI_KEYCHAIN_PWD`, `PROD_MACOS_NOTARIZATION_APPLE_ID`,
      `PROD_MACOS_NOTARIZATION_TEAM_ID`, the notarization password, plus
      Sparkle and Safe Browsing (Tasks 4 and 6). Mark
      `PROD_MACOS_SPECIAL_ENTITLEMENTS_PROFILE_B64` as not used until the
      passkey entitlement is granted (M6).
- [ ] **Step 2:** The owner creates a Developer ID Application certificate,
      exports it as .p12 and an app-specific password, and enters the secrets
      in the `release` environment (guided by the doc; the owner does all
      credential entry themselves).
- [ ] **Step 3:** Move the secret-consuming steps into jobs that declare
      `environment: release`; confirm PR-triggered runs have no access
      (`if: github.event_name != 'pull_request'`).
- [ ] **Step 4:** Release CI build. Verify on the owner's Mac:
      `spctl -a -vvv -t install Tesseract-*.dmg` → `accepted, source=Notarized Developer ID`;
      `codesign --verify --deep --strict --verbose=2 /Applications/Tesseract.app` → valid;
      `xcrun stapler validate Tesseract-*.dmg` → worked.
- [ ] **Step 5: Commit** `ci: signed and notarized releases via protected environment`.

### Task 6: Sparkle updates from our own appcast

**Files:**
- Create (core repo): `patches/tesseract/core/tesseract-update-url.patch`
  (sets `kUpdateBaseUrl` from Helium's `add-updater-preference.patch` to
  `https://arianhobson333.github.io/tesseract-updates/`, keeping the
  `mac/appcast-<arch>.xml` path scheme)
- Create repo: `ArianHobson333/tesseract-updates` (GitHub Pages; holds `mac/appcast-arm64.xml` only, DMGs stay on GitHub Releases)
- Create (macos repo): `.github/scripts/github_publish_appcast.sh`
- Modify: `.github/workflows/build.yml` release job (add a publish step after the release upload)

**Interfaces:**
- Consumes: env `PROD_MACOS_SPARKLE_ED_PUB_KEY` (already read by `shared.sh`),
  new secret `TESSERACT_SPARKLE_ED_PRIVATE_KEY` (release environment only).
- Produces: `github_publish_appcast.sh <dmg_path> <version> <release_url>`
  that runs Sparkle's `generate_appcast`/`sign_update` with the private key
  passed via stdin (never written to disk, never echoed) and pushes the
  updated `mac/appcast-arm64.xml` to `tesseract-updates`.

- [ ] **Step 1:** The owner generates an EdDSA key pair locally with Sparkle's
      `generate_keys` (the key is stored in their login Keychain), then enters the
      public key as `PROD_MACOS_SPARKLE_ED_PUB_KEY` and the exported private
      key as `TESSERACT_SPARKLE_ED_PRIVATE_KEY`. Back up the private key
      offline: losing it strands every installed copy.
- [ ] **Step 2:** Write the URL patch and append it to `patches/series`.
- [ ] **Step 3:** Write `github_publish_appcast.sh`. Behaviour: exit non-zero
      if the DMG fails `spctl`/stapler validation (Review Focus 2), or if the
      signature step fails. It only pushes the appcast after both pass.
- [ ] **Step 4:** Release two consecutive versions (e.g. a no-op version bump).
      Verify: installing version N, then Tesseract › Check for Updates, offers
      N+1, installs it and relaunches.
- [ ] **Step 5:** Negative check (Review Focus 5): hand-craft an appcast
      locally whose item is signed with a throwaway key, serve it with
      `python3 -m http.server`, and point a test build at it through Helium's
      update-channel flag (`add-update-channel-flag.patch`; use the flag name
      in that patch). Expected: Sparkle reports an invalid signature and
      doesn't install.
- [ ] **Step 6: Commit** `feat: Sparkle updates from tesseract-updates appcast`.

### Task 7: Release workflow end-to-end

**Files:**
- Modify: `.github/workflows/build.yml` (release job: `prerelease: false` for
  stable tags, name `Tesseract <version>`; drop x64 artifact handling)
- Modify: `.github/scripts/github_prepare_release.sh`, `github_generate_release_note.sh` (product name, arm64 only)
- Create: `.github/scripts/tests/test_release_gate.sh`

**Interfaces:**
- Consumes: Tasks 5 and 6.
- Produces: one manual dispatch (`do-release=true`) → GitHub Release with the
  DMG plus a published appcast entry, or a failed run with no appcast change.

- [ ] **Step 1: Write the failing test** `test_release_gate.sh`: feed
      `github_publish_appcast.sh` an unsigned dummy DMG (made with
      `hdiutil create -size 1m`). Assert exit status ≠ 0 and that the appcast
      file in a temp clone is byte-identical before and after.
- [ ] **Step 2:** Run `bash .github/scripts/tests/test_release_gate.sh`. Expected: FAIL until the gate exists, then PASS after Task 6 Step 3.
- [ ] **Step 3:** Adjust the release scripts as listed, and run the gate test
      in the `lint` workflow.
- [ ] **Step 4:** Full dispatch with `do-release=true`. Verify: release page
      shows `Tesseract <version>` with one arm64 DMG, and the appcast lists it.
- [ ] **Step 5: Commit** `ci: Tesseract release pipeline with publish gate`.

### Task 8: Track Helium releases automatically (24 h target)

**Files:**
- Create: `.github/workflows/sync-upstream.yml` (macos repo), scheduled
  every 6 h plus `workflow_dispatch`
- Create: `.github/scripts/sync_upstream.sh`, `.github/scripts/tests/test_sync_upstream.sh`

**Interfaces:**
- Produces: `sync_upstream.sh` prints `status=up-to-date|merged|conflict` to
  `$GITHUB_OUTPUT`. On `merged` it opens a PR titled
  `sync: Helium <tag>`, and the PR's `sanity` / `patch-check` jobs run.
  Merging the PR (owner, or auto-merge when checks pass) triggers a release build.

- [ ] **Step 1: Write the failing test** `test_sync_upstream.sh` using two local
      bare repos as fake `upstream`/`origin`:
      (a) no new tag → `status=up-to-date`, no branch created;
      (b) new tag that merges cleanly → `status=merged`, branch `sync/<tag>` exists;
      (c) new tag that conflicts in `patches/series` → `status=conflict`,
      exit ≠ 0, nothing pushed (Review Focus 1).
- [ ] **Step 2:** Run it. Expected: FAIL.
- [ ] **Step 3:** Implement `sync_upstream.sh`: fetch upstream tags in both
      repos, compare the newest Helium release tag with `revision.txt`/the
      last synced tag, merge into `sync/<tag>`, update the submodule pointer,
      and on conflict abort and exit 1.
- [ ] **Step 4:** Run the test. Expected: PASS.
- [ ] **Step 5:** Workflow: on `conflict`, open a GitHub issue
      `Helium <tag> needs manual sync` (labels: `security`, `upstream`).
      Owner gets notified through normal GitHub notifications.
- [ ] **Step 6:** Verify live: dispatch the workflow → `up-to-date`.
- [ ] **Step 7: Commit** `ci: automatic Helium sync PRs`.

### Task 9: Performance baseline harness

**Files:**
- Create (macos repo): `tools/perf/corpus.txt` (50 URLs: news, docs, Gmail-like webapps, YouTube, social, shopping; public pages only, no logins)
- Create: `tools/perf/run_benchmark.py`, `tools/perf/parse_metrics.py`, `tools/perf/tests/test_parse_metrics.py`, `tools/perf/README.md`

**Interfaces:**
- Produces: `python3 tools/perf/run_benchmark.py --browser <path-to-.app> --minutes 60 --out results/<name>.csv`.
  It launches the browser with `--remote-debugging-port`, opens the corpus via
  CDP (stdlib `http.client` + `websocket` via `python3 -m pip install websocket-client`,
  the only dependency), focuses tab 1, then samples every 60 s.
- `parse_metrics.py`: `parse_top_power(text: str, process_prefix: str) -> float`,
  `parse_vm_stat(text: str) -> dict[str, int]` (keys `swapins`, `swapouts`, `pages_compressed`),
  `parse_powermetrics_tasks(text: str, process_prefix: str) -> float` (summed energy impact).
- CSV columns: `t_min, browser, energy_impact, top_power, swapins, swapouts, pages_compressed`.

- [ ] **Step 1: Write failing tests** in `test_parse_metrics.py` with captured
      fixture text (save real `top -l 1 -stats pid,command,power`,
      `vm_stat`, `sudo powermetrics --samplers tasks -n 1` outputs from the
      owner's Mac under `tools/perf/tests/fixtures/`). Assert exact numbers
      read from those fixtures, e.g. `parse_vm_stat(fixture)["swapouts"] == <value in fixture>`,
      and that summing works across multiple `Tesseract Helper (Renderer)` rows.
- [ ] **Step 2:** Run `python3 -m pytest tools/perf/tests -v`. Expected: FAIL.
- [ ] **Step 3:** Implement the parsers, then `run_benchmark.py` (powermetrics
      needs sudo; if not available, skip that column and print a warning,
      don't fail).
- [ ] **Step 4:** Run the tests. Expected: PASS.
- [ ] **Step 5:** Owner runs baselines on battery at fixed brightness:
      Safari, Chrome, Helium, Arc (before 2026-12-22), Tesseract M1. Commit
      CSVs under `tools/perf/results/2026-xx-xx/` plus a summary table in `tools/perf/README.md`.
- [ ] **Step 6: Commit** `feat: perf baseline harness`.

### Task 10: Public-repo hygiene

**Files:**
- Modify: `README.md` (what Tesseract is, status "pre-alpha", built on Helium and ungoogled-chromium with credits, GPL-3.0)
- Create: `SECURITY.md` (private reporting via GitHub Security Advisories; supported version = latest; 24 h Helium-sync target)
- Create: `docs/trust/helium-services.md` (what Helium's `services.helium.imput.net` proxies, current decision "kept for M1, revisit before public release" per spec §11)
- Modify: `.github/` (enable Dependabot for GitHub Actions only)

- [ ] **Step 1:** Write the three docs.
- [ ] **Step 2:** Verify: `grep -rniE "cla[u]de|anthr[o]pic|generated [w]ith|co-authored-[b]y" . --exclude-dir=.git` → no matches.
- [ ] **Step 3:** Enable private vulnerability reporting: `gh api -X PUT repos/ArianHobson333/tesseract-macos/private-vulnerability-reporting` (same for `tesseract`).
- [ ] **Step 4: Commit** `docs: README, SECURITY, Helium services trust note`.

---

## Not in this plan (separate plans)

- **Clean-room observer workstream** (Arc interaction catalog first, before
  2026-12-22; Dia; onboarding and sound notes; Arc data-format spec) gets its own
  plan, run in separate sessions per spec §13. It can start immediately, in parallel.
- M2 (sidebar, pinned/Today, Archive, command bar, Arc importer) gets planned
  after the Task 2 gate shows CI build times, because those set the feedback
  loop for every UI patch.
