# Tesseract — design (v3, 2026-10-24)

A calm, Arc-style macOS browser on Chromium that stays cool with many tabs,
uses Apple's own features where macOS allows it, and uses only on-device
Apple Intelligence for its smart features. Planned for public, likely
open-source release.

Status: v3 — APPROVED by owner 2026-10-24 (with micro-interaction + sound additions); owner decisions folded in; reviewed by an independent builder
check and an adversarial engineering critique (v1→v2). Next: build plan for M1 + observer workstream.

---

## 1. Owner decisions (2026-10-24)

| Topic | Decision |
|---|---|
| Product | **Separate browser from day 1** (no extension stage). |
| Base | **Fork of Helium** (built on ungoogled-chromium), inheriting its privacy patches. |
| Licence | Helium is GPL-3.0 → **Tesseract is GPL-3.0**. ungoogled-chromium (BSD-3) and Chromium licences retained. |
| Distribution | Release someday, probably open source → public GitHub repo. |
| Build infra | Hobby budget → **free GitHub Actions macOS runners (public repo)**, multi-job resumable build like ungoogled-chromium-macos, to fit the 6 h job limit. Owner's Mac only runs builds. |
| Apple account | Personal Developer account (signing + notarization OK; passkey entitlement: request, may be refused). |
| Safe Browsing | **Add back** (v4 API, non-commercial key; move to Web Risk if ever commercial). |
| DRM | Netflix/Spotify/Disney+ in Safari for now; **Widevine wanted eventually** (apply to Google once there is a public release). |
| Sync | Eventually. Storage designed for it now (stable IDs, timestamps, tombstones). |
| Arc features | All of them, **most-loved first**, with **easy porting from Arc** (§5). |
| AI features | Archive labels, tab triage, tidy titles, **semantic search of history/archive (top priority)**, Focus-aware Spaces (§9). |
| Arc/Dia study | **Clean-room** process (§13). |
| Machine | M2, 8 GB RAM; owner is freeing internal disk; SSD renamed to `/Volumes/AriSSD` (no spaces). |

## 2. Why

- Arc shuts down: no new accounts since 2026-10-22; **desktop app stops
  working 2026-12-22**; account data deleted within 30 days after.
- Dia has excellent UI/UX and onboarding, but is AI-first (cloud), asks for an
  Atlassian/work sign-in, and lacks Peek, Air Traffic Control, Little Arc,
  nested folders and shared Favorites.
- Arc ran hot (years of leak/CPU/battery fixes; users report 100% CPU and
  8–9 GB RAM with many tabs). Dia shows the same pattern.

## 3. Goals

1. Arc's most-loved features (§5), importable from Arc in one step.
2. Light on an **8 GB M2**: measured idle CPU / energy / swap budget (§7).
3. Full Chrome Web Store extensions, including full uBlock Origin (MV2 via Helium).
4. Native Apple integration where public APIs allow (§8).
5. Local-only AI; off switch removes every AI surface (§9).
6. Security as close to Chrome stable as the base allows; every gap written down (§11).
7. Dia-quality full-screen onboarding (§12).

## 4. Non-goals, anti-goals

Non-goals (v1): Windows/Linux/iOS; our own sync server; cloud AI, chat
assistant, agentic browsing; Boosts with JavaScript that syncs or is fetched
remotely; mandatory accounts.

Anti-goals (a failure even if it "works"):
- A permanent AI button/ad in the UI.
- Any backend that decides what code runs in the user's pages (Arc Boosts, CVE-2024-45489).
- Telemetry phoning home.
- Any Arc/Dia proprietary code, decompiled output, binaries or assets in the repo (§13).

## 5. Feature order — most-loved first

Order comes from user sentiment (HN/Reddit/X, release notes) plus "port from
Arc easily". Each milestone is a usable daily driver.

**M1 — Tesseract exists.** Rebranded Helium fork builds, signs, notarizes and
auto-updates from CI. No UI changes. Safe Browsing restored.

**M2 — Arc core (the reasons people stayed on Arc).**
1. Vertical sidebar (built on upstream Chromium vertical tabs, Views), auto-hide.
2. **Pinned vs. Today tabs**: drag above the line to keep; pinned tabs return
   to their original URL.
3. **Auto-archive** of Today tabs (12 h / 1 d / 7 d / 30 d) + **Archive view**
   (see §6, foundation for semantic search).
4. Favorites row (icons at the top).
5. Command bar (Cmd-T): fuzzy search across open tabs, pinned, archive, history, commands.
6. **Arc importer**: Spaces, pinned tabs, nested folders, Favorites, tab
   names (from Arc's export / sidebar file), plus Chrome/Safari importers from Chromium.

**M3 — Spaces and layout.**
7. Spaces with colour/theme, optional **profile per Space**, Favorites shared across Spaces.
8. Nested folders in the pinned section; rename tabs.
9. Split view.

**M4 — The "can't leave Arc" extras.**
10. Peek (links open in a preview overlay).
11. Little window (quick floating window, e.g. links from other apps, SSO popups).
12. Air Traffic Control (rules: URL → Space).
13. Auto picture-in-picture when leaving a tab with video.
14. Capture/screenshot, copy-URL shortcuts.

**M5 — Local intelligence + Apple.** §8 and §9.

**M6 — Hardening and reach.** Threat-model review, QA matrix, passkey
entitlement, Widevine application, sync design, optional local-only CSS "boosts".

Arc features with low usage (Easels, Calendar preview, Live Folders) are not planned.

## 6. Closed tabs and groups: Archive (top-priority design)

The owner's main concern: auto-closing must never lose anything, and picking
up a closed tab or group must be easy.

- Every archived/closed tab becomes an **Archive record**: stable ID, URL,
  title (original + tidy title), favicon, Space, group/folder ID, opened/closed
  times, closing reason (auto-archive, manual, triage), and optionally a short
  text snippet of the page.
- **Groups are archived as one unit**: closing or auto-archiving a cluster
  stores a group record; restoring it reopens all its tabs in the same Space/group.
- Archive view: grouped by day and by label ("Flights to Lisbon (6 tabs)"),
  with restore-one / restore-group / delete.
- **Search works from M2 without AI** (keyword over title/URL/snippet via
  SQLite FTS5). M5 adds **semantic search** on top (§9).
- Privacy: stored locally in the profile; never for incognito/private
  windows; per-site exclusions; "clear archive" and retention limits; covered
  by Chromium's "clear browsing data". Snippet capture can be turned off.
- Sync-ready: stable UUIDs, updated-at timestamps, tombstones for deletes.

## 7. Performance plan

Ranked by impact on an 8 GB M2:
1. Content blocking (uBO, MV2 via Helium): biggest CPU/energy win.
2. Aggressive discarding of hidden, silent, non-capturing tabs; exceptions:
   audio, calls, unsaved forms, user-locked.
3. Auto-archive: tabs actually go away (and are safe in the Archive, §6).
4. Freeze hidden tabs always (not only under Energy Saver).
5. Keep Chromium defaults that help: timer throttling, intensive wake-up
   throttling, back/forward cache (Dia disabled it and regretted it).
6. Pause hidden video; auto-PiP only when enabled.
7. Per-extension CPU visibility; flag heavy background workers.
8. GPU process and hidden-tab animation frames; favicon/snapshot memory caps.
9. Per-tab "hot" indicator from Chromium's process metrics (sampled ≤ 1/min).
10. Never weaken site isolation.

Measurement: scripted 50-tab corpus via CDP; on the 8 GB M2, on battery,
fixed brightness; record `powermetrics --samplers tasks`, `top -stats power`,
`vm_stat`/swap. Baselines: Chrome, Safari, Helium (and Arc before 12-22 if
available). Target: idle energy ≤ Safari × 1.5; no swap growth over 1 h idle.
Run in CI on every release candidate where possible, otherwise on the owner's Mac.

## 8. Apple integration

| Feature | Status | How / caveat |
|---|---|---|
| Apple Passwords autofill in web pages | Partly | No public API for system password AutoFill in a third-party browser's web content. Use Apple's **iCloud Passwords extension**, which needs a native-messaging host manifest in Tesseract's directory. Ship that path pre-wired; offer it in onboarding. |
| Passkeys in iCloud Keychain | Entitlement | Chromium has the code; restricted entitlement, request may be refused for a personal account. Request early. |
| 2FA code autofill, Credential Exchange import | Verify | macOS 26 support for third-party browsers unconfirmed. |
| Touch ID before revealing passwords | Yes | `LAContext`. |
| Default browser, Share sheet, Universal Clipboard | Yes | Mostly free in Chromium. |
| Handoff | Yes | `NSUserActivity.webpageURL`. |
| **Focus-aware Spaces** | Yes | App Intents Focus filter: each Focus (Work/Personal…) picks a Space. No AI. |
| Spotlight, Shortcuts | Yes | Core Spotlight (opt-in: pinned + Favorites), App Intents. |
| Writing Tools, Live Text | Partly | Chromium partial support. |
| Apple Pay on websites | Limited | Only Apple's QR-code-to-iPhone flow. |

## 9. Local intelligence

Constraints: Apple Foundation Models has a **4,096-token context** (including
instructions, schemas and output); needs Apple Intelligence on, supported
language/region, ~7 GB free internal disk; **rate-limited for background
work, especially on battery**; safety guardrails sometimes refuse web text;
the ~3B model adds memory pressure on 8 GB. All features degrade gracefully
when unavailable.

Rules:
- The LLM runs only in the foreground or on small batches while charging/idle.
  NaturalLanguage embeddings (cheap) do clustering and search; the LLM only
  names, labels and shortens.
- Page text is **untrusted input**. AI output only displays text or
  rearranges the sidebar after user confirmation. No AI tools click, type,
  navigate or submit. Runs outside the browser process.
- AI off = no AI UI anywhere; keyword search and plain archive still work.

Chosen features, in build order:
1. **Semantic search of history and the Archive** (top priority). Embeddings
   of title + URL + snippet for archived tabs, groups, pinned, Favorites (and
   history, if storage/CPU allow), computed while charging/idle. Command bar and
   Archive view mix keyword (FTS5) and semantic results ("that M2 thermals
   article", "the Lisbon flights group").
2. **Archive labels**: when tabs/groups are archived, cluster them and label
   each cluster ("Flights to Lisbon (6 tabs)"); restore as a group.
3. **Tab triage**: "17 of your 41 tabs look finished. Archive them?"; one
   click archives them (safely, into §6).
4. **Tidy titles**: shorten long titles on demand or when pinned/archived; cached.
5. **Focus-aware Spaces** (§8, no AI).

Not chosen for now: auto tab grouping of open tabs, Peek summary, smart
routing. Dropped: smart download renaming (spoofing risk).

## 10. Lessons from Arc/Dia release notes

- Leaks and CPU regressions recurred for years → automated perf runs (§7).
- PiP + Google Meet, extensions (MetaMask), keyboard layouts (AZERTY, Dvorak,
  AltGr), non-Latin input in the command bar, printing → per-release QA checklist.
- Sync bugs dominated Arc's notes → sync later, designed carefully.
- Late Arc releases were mostly Chromium bumps → the update pipeline is the product.
- Dia's quadratic HTML→Markdown bug → bound all per-page preprocessing.
- Arc's "novelty tax" → familiar defaults, power features discoverable over the first week.

## 11. Security requirements

- **Patch latency:** rebase onto each Helium release and ship within 24 h;
  out-of-band for actively exploited 0-days. CI must make this a button press.
- **Safe Browsing:** restored (v4, non-commercial key, honour the
  list-freshness rules).
- **Helium services:** Helium proxies some extension/Web Store traffic via its
  own services. Document it; decide keep / self-host / patch out before release.
- Keep stock: sandbox, full site isolation, Chrome Root Store + verifier, HSTS preload.
- Custom UI (sidebar, command bar, Peek, Little window, split view):
  - URLs displayed only via Chromium's security formatter (IDN/punycode, RTL).
  - Always-visible origin in Peek and Little windows.
  - Defined anchor for permission prompts, cert errors, fullscreen-exit bubble;
    split view shows which pane a prompt belongs to.
  - UI says clearly when Spaces share cookies vs. are isolated profiles.
- Signing: Chromium's own mac signing scripts (per-helper entitlements),
  Hardened Runtime, notarize + staple; Sparkle 2 EdDSA-signed appcast over
  HTTPS; signing/notary keys only in CI secrets (GitHub environments with
  required reviewers, since the repo is public).
- CI supply chain: pinned action SHAs, no secrets in PR builds from forks,
  reproducible build inputs, SBOM per release.
- No server holding user data or code. Optional CSS "boosts" are local-only,
  JS off by default, never synced/fetched.
- Archive/semantic index: local only, excluded from private windows, clearable.
- Crashpad minidumps stored locally; opt-in manual upload only.
- Threat model before the first public build; vulnerability disclosure policy
  (SECURITY.md) before going public.

## 12. Onboarding

Full-screen, Dia-style, original artwork (no Arc/Dia assets):
1. Welcome animation.
2. **Import from Arc** (Spaces, pinned, folders, Favorites, tab names), Chrome,
   Safari, Dia. One screen, preview of what will come over.
3. Set as default browser.
4. Passwords: Apple Passwords via iCloud Passwords extension.
5. Look: theme/colour per Space.
6. Intelligence: off / on (local-only, with availability check and why).
7. Teach three things (Cmd-T, pin = keep, Archive); drip further tips over week 1.

**Sound design.** Owner wants onboarding sound like Arc/Dia's, which draws
attention without being loud. Use **original** sounds only (commissioned,
self-made, or CC0/licensed). Clean-room observers record *what* plays *when*
(trigger, length, mood, how it lines up with motion), never extract or
resample their audio files. Sounds respect the system volume and a
"reduce sounds" setting, and are skipped when Reduce Motion is on or the
Mac is muted.

## 12a. Micro-interactions (a first-class workstream)

The owner values Arc's and Dia's small UI details, e.g. the close button
appearing only on tab hover. A good share of time goes to studying and
rebuilding these.

- **Interaction catalog** (`docs/cleanroom/interactions/`), written by
  observers from Arc 1.170.0 and Dia 1.54.x. One entry per interaction:
  - trigger, visible states, timing (delays, durations), easing feel,
    hit areas, keyboard equivalent;
  - how Arc and Dia differ;
  - a priority: must / nice / skip.
- Seed list to observe:
  - tab hover: close button, mute button, hover delay
  - tab drag/reorder; drag above the line to pin
  - sidebar show/hide on edge hover (and its misclick complaints)
  - Space switch swipe and colour transition
  - command bar open/close and result highlighting
  - Peek open/close
  - archive/restore animation; split-view drag
  - favicon badges and loading states; audio indicator
  - copy-URL toast; download indicator
  - window traffic-light placement; rename-tab inline editing
  - empty states
  - onboarding sequence, including sound
- Each catalog entry becomes a small, separately testable change.
  Animations respect Reduce Motion and never block input.
- Performance rule: hover/animation work must not wake hidden tabs or cause
  main-thread hitches; measured with the §7 harness.

## 13. Clean-room process (Arc/Dia study)

Goal: learn behaviour and data formats without any of their code entering Tesseract.

- **Two roles, never mixed:**
  - **Observer** (separate sessions/agents): may run REA, inspect app bundles
    and Arc's data files, record video, measure timings. Writes **behaviour
    specs** in `docs/cleanroom/`: plain-language behaviour, measurements,
    flows, and data-format descriptions needed for the importer
    (interoperability). No code, no decompiled snippets, no assets, no
    symbol-level internals.
  - **Builder** (all implementation sessions): works only from specs, Chromium
    and Helium source. Never opens REA output or raw artifacts.
- Raw artifacts (REA output, disassembly, recordings) live **outside the repo**
  (e.g. `/Volumes/AriSSD/cleanroom-raw/`) and are never committed.
- Each spec records provenance (what was observed, how, when).
- A reviewer checks each spec for leaked implementation detail before it goes
  to builders.
- Check Arc/Dia licence terms first (could not be retrieved yet; the terms
  pages found returned 404).
- **Time-critical:** Arc must be observed before 2026-12-22. Arc 1.170.0
  installed and signed in on 2026-10-24. The owner's Arc data folder was
  backed up to `/Volumes/AriSSD/cleanroom-raw/arc-backup-2026-10-24/`
  (private, outside the repo; contains login tokens/cookies, never commit or share).
  Still do Arc's official Export Data before 12-22.

## 14. Roadmap (rough)

- **Week 1:** repo + CI skeleton; prove one vanilla Helium build on free
  GitHub runners (record wall time); rebrand; sign/notarize; Sparkle. Owner
  daily-drives stock Helium. Clean-room observation of Arc starts.
- **Weeks 1–8 (parallel, before Arc dies):** observer workstream: Arc
  interaction catalog first (Arc dies 12-22), then Dia; onboarding and
  sound notes; Arc data-format spec for the importer.
- **Weeks 2–4:** M1 complete (Tesseract auto-updates), Safe Browsing restored,
  perf harness.
- **Weeks 4–10:** M2 (sidebar, pinned/Today, auto-archive + Archive, command
  bar, Arc importer).
- **Then:** M3 → M4 → M5 → M6, each shipped when usable.
- Arc will die before M2 lands: owner bridges on stock Helium, then imports
  from the saved Arc export.

## 15. Left to the builder

- Patch boundaries within Helium; how Tesseract's patches are layered.
- Discard/freeze/archive defaults (tuned via benchmark).
- Embedding model choice (NLEmbedding vs. NLContextualEmbedding), clustering thresholds.
- CI job splitting and caching strategy.

## 16. Open items

- Arc install + export for observation and importer test data (time-critical).
- Arc/Dia licence terms (find the current URLs).
- Owner to free internal disk (≥ 15 GB) for Apple Intelligence.
- Verify GitHub free macOS runner disk/time limits suffice; fallback: self-hosted
  runner on a rented Mac.
