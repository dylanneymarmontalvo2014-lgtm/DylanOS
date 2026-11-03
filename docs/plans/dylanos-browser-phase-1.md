# DylanOS Browser Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish a real, traceable DylanOS Browser fork of Zen 1.24b plus a tested source contract in DylanOS, without yet replacing the working system browser.

**Architecture:** Browser product code lives in a dedicated `DylanOS-Browser` repository derived from Zen stable, while the DylanOS repository owns only the pinned source/release contract and later Debian integration. Phase 1 changes branding and release metadata, blocks accidental Zen updates, preserves MPL notices, and adds fast contract tests; the full Gecko bootstrap/build is Phase 2.

**Tech Stack:** Zen/Firefox overlay, Surfer, Node 22, Python 3.11, Rust 1.95.0, Gecko `mach`, JSON/YAML, Python `unittest`, XDG desktop entry.

**Spec:** `docs/design/dylanos-browser.md`

## Global Constraints

- Base exactly on Zen Browser 1.24b commit `f75390aa2b797ddc3524ff9ed52ceb32a839f9fa` (Firefox 159.0).
- Preserve MPL-2.0 license text and existing copyright/license headers.
- Use product name `DylanOS Browser`, binary `dylanos-browser`, desktop ID `org.dylanos.browser.desktop`, and vendor `DylanOS`.
- Do not use Zen or Mozilla names/logos as DylanOS Browser product branding.
- Do not add telemetry or weaken Gecko/Firefox security controls.
- Keep internal `zen.*` APIs and source paths where renaming would create needless upstream divergence.
- APT is the planned stable update authority; the fork must never contact Zen's update server.
- Do not remove `firefox-esr` from DylanOS until a real browser binary passes Phase 2 integration tests.
- Product default accent is `#E50914`; system-follow mode may use DylanOS `#DC143C`.
- Comments and user-facing UI added by DylanOS are in Spanish.

## Review Focus

- A checkout with the wrong upstream SHA must fail the contract test with the expected and actual SHA.
- Product metadata must not retain `updates.zen-browser.app`, `app.zen-browser`, `binaryName: zen`, or user-facing `Zen Browser` values.
- The updater policy must remain disabled for the future Debian package, including after upstream synchronization.
- The desktop entry must accept multiple URLs and expose working New Window and Private Window actions without shell interpolation.
- License/source notices must identify both the upstream base and the exact corresponding DylanOS source location without implying Mozilla/Zen endorsement.

---

### Task 1: Create the dedicated fork and provenance record

**Files:**
- Create in browser repo: `dylanos/upstream.json`
- Create in browser repo: `scripts/dylanos/test_product_contract.py`
- Modify in browser repo: `README.md`
- Preserve in browser repo: `LICENSE`

**Interfaces:**
- Consumes: Zen stable tag `1.24b` at the pinned SHA.
- Produces: `upstream.json` with `repository`, `tag`, `commit`, `firefox_version`, and `audit_date`; local remotes named `upstream` (Zen) and `origin` (intended DylanOS fork).

- [ ] **Step 1: Clone Zen stable into `/home/dylan/DylanOS-Browser` and create `development` from the exact pinned commit**

Run read-only checks first to ensure the destination does not already contain user work. Rename the official remote to `upstream`; configure `origin` as `git@github.com:dylanneymarmontalvo2014-lgtm/DylanOS-Browser.git` without pushing.

- [ ] **Step 2: Write the failing provenance tests**

Tests assert the exact five keys and values in `dylanos/upstream.json`, that `LICENSE` contains the MPL 2.0 text, and that README includes “DylanOS Browser”, the upstream Zen URL, the pinned commit, MPL-2.0, and a non-affiliation notice.

- [ ] **Step 3: Run the tests to verify failure**

Run: `python3 scripts/dylanos/test_product_contract.py -v`

Expected: FAIL because the provenance file and DylanOS notices do not exist.

- [ ] **Step 4: Add provenance and README notices without deleting upstream attribution**

Create the exact machine-readable record and replace the product introduction while retaining a clear “Derivado de” section. Do not modify `LICENSE`.

- [ ] **Step 5: Run the focused tests**

Run: `python3 scripts/dylanos/test_product_contract.py -v`

Expected: provenance/license/README tests PASS.

- [ ] **Step 6: Commit the fork foundation**

```bash
git add README.md dylanos/upstream.json scripts/dylanos/test_product_contract.py
git commit -m "chore(browser): establecer procedencia del fork"
```

### Task 2: Rebrand build metadata and block accidental upstream updates

**Files:**
- Modify in browser repo: `surfer.json`
- Modify in browser repo: `configs/common/mozconfig`
- Modify in browser repo: `build/AppDir/distribution/policies.json`
- Modify in browser repo: `build/AppDir/zen.desktop`
- Extend in browser repo: `scripts/dylanos/test_product_contract.py`

**Interfaces:**
- Consumes: provenance contract from Task 1.
- Produces: build metadata for `DylanOS Browser`, XDG launcher contract `org.dylanos.browser.desktop`, and an update policy that cannot use Zen infrastructure.

- [ ] **Step 1: Add failing metadata tests**

Assert `surfer.json` has `name: DylanOS Browser`, `vendor: DylanOS`, `appId: org.dylanos.browser`, `binaryName: dylanos-browser`, Firefox `159.0`, and release display version `1.0.0-alpha.1`; assert its update hostname is the reserved non-resolving `updates.dylanos.invalid` until DylanOS owns a signed service. Assert mozconfig basename/distribution/source values use DylanOS identifiers and no Zen update hostname remains in product-critical files.

- [ ] **Step 2: Add failing desktop/updater tests**

Assert the desktop entry has `Name=DylanOS Browser`, `Exec=dylanos-browser %U`, `Icon=dylanos-browser`, `StartupWMClass=org.dylanos.browser`, `Categories=Network;WebBrowser;`, HTTP/HTTPS/HTML MIME handlers, and actions for a new window and private window. Assert all four updater policy flags remain disabled.

- [ ] **Step 3: Run the tests to verify the expected failures**

Run: `python3 scripts/dylanos/test_product_contract.py -v`

Expected: FAIL on upstream metadata values.

- [ ] **Step 4: Implement the minimal metadata changes**

Change product/release fields and mozconfig identifiers without mass-renaming internal `zen.*` namespaces. Rename the desktop file only when the build/package references are updated in the same change; otherwise retain its source filename but make its installed ID explicit in the packaging contract.

- [ ] **Step 5: Run the contract tests**

Run: `python3 scripts/dylanos/test_product_contract.py -v`

Expected: all tests PASS.

- [ ] **Step 6: Run syntax and license checks available without Gecko bootstrap**

Run: `python3 -m json.tool surfer.json >/dev/null`, `python3 -m json.tool build/AppDir/distribution/policies.json >/dev/null`, `npm ci`, and `npm run lc`.

Expected: JSON parses; dependency install and MPL license check succeed.

- [ ] **Step 7: Commit product metadata**

```bash
git add surfer.json configs/common/mozconfig build/AppDir scripts/dylanos/test_product_contract.py
git commit -m "feat(browser): definir identidad técnica de DylanOS Browser"
```

### Task 3: Add DylanOS product preferences without increasing upstream divergence

**Files:**
- Create in browser repo: `prefs/dylanos/product.yaml`
- Extend in browser repo: `scripts/dylanos/test_product_contract.py`

**Interfaces:**
- Consumes: Surfer preference compiler already used by `npm run ffprefs`.
- Produces: preferences `dylanos.browser.schema-version`, `dylanos.browser.follow-system-theme`, `dylanos.browser.performance-profile`, `dylanos.browser.crimson-glass.force-opaque`, and `dylanos.browser.accent`.

- [ ] **Step 1: Add failing preference-schema tests**

Assert schema version `1`, follow-system `true`, profile `balanced`, force-opaque `false`, and accent `#E50914`. Assert no preference disables telemetry/security controls by unrelated Firefox keys.

- [ ] **Step 2: Run the focused tests to verify failure**

Run: `python3 scripts/dylanos/test_product_contract.py -v`

Expected: FAIL because the DylanOS preference file is absent.

- [ ] **Step 3: Add the minimal YAML preference definitions**

Follow the existing `prefs/zen/*.yaml` schema. Do not yet add UI or observers; those belong to Phase 3 after Gecko bootstrap.

- [ ] **Step 4: Compile preferences and run tests**

Run: `npm run ffprefs` and `python3 scripts/dylanos/test_product_contract.py -v`.

Expected: preference compilation and all contract tests PASS.

- [ ] **Step 5: Commit the preference namespace**

```bash
git add prefs/dylanos/product.yaml scripts/dylanos/test_product_contract.py
git commit -m "feat(browser): añadir preferencias base de producto"
```

### Task 4: Pin the browser source contract in DylanOS

**Files:**
- Create: `browser/source.lock.json`
- Create: `browser/README.md`
- Create: `scripts/tests/test_browser_contract.py`

**Interfaces:**
- Consumes: release/provenance fields from the dedicated browser repo.
- Produces: one canonical DylanOS source lock consumed later by package/build scripts; no browser package is installed in this task.

- [ ] **Step 1: Write the failing DylanOS contract tests**

Assert the lock schema contains repository URL, upstream URL/tag/SHA, product version, Firefox version, binary, desktop ID, source archive placeholder, SHA-256 placeholder explicitly marked `unpublished`, and update authority `apt`. Assert the default package list still contains `firefox-esr` during Phase 1.

- [ ] **Step 2: Run the test to verify failure**

Run: `python3 -m unittest -v scripts.tests.test_browser_contract`

Expected: FAIL because the lock file does not exist.

- [ ] **Step 3: Add the source lock and concise maintainer README**

The README documents how to update the pin and states that `source_archive`/`sha256` must become real values before Phase 2 package installation. It must not claim the browser is built or integrated.

- [ ] **Step 4: Verify the suite is discovered by repository QA**

`scripts/check.sh` already executes every `scripts/tests/test_*.py` module in its own process. Run its unittest-loop selection or the full check and confirm `test_browser_contract` appears; do not modify the runner unless discovery actually fails.

- [ ] **Step 5: Run contract and staging/package regressions**

Run: `python3 -m unittest -v scripts.tests.test_browser_contract`, `python3 -m unittest -v scripts.tests.test_staging`, and `bash scripts/tests/test_packages.sh`.

Expected: all PASS; Firefox remains the active default in this phase.

- [ ] **Step 6: Commit the distribution source contract**

```bash
git add browser/source.lock.json browser/README.md scripts/tests/test_browser_contract.py
git commit -m "chore(browser): fijar contrato de fuente para DylanOS"
```

### Task 5: Verify Phase 1 as a whole

**Files:**
- Verify only; update plan checkboxes and living architecture documentation only if results match reality.

**Interfaces:**
- Consumes: Tasks 1–4.
- Produces: evidence that the fork and distribution contract are coherent before the expensive Gecko bootstrap.

- [ ] **Step 1: Run fork-side fast verification**

Run in `/home/dylan/DylanOS-Browser`: `python3 scripts/dylanos/test_product_contract.py -v`, `npm run lc`, and `git diff --check upstream/stable...HEAD`.

Expected: PASS/clean; no Zen update hostname or product identity remains in critical metadata.

- [ ] **Step 2: Run DylanOS repository QA**

Run in `/home/dylan/DylanOS`: `DYLANOS_PYTHON="$PWD/.venv/bin/python" bash scripts/check.sh`.

Expected: complete repository QA PASS.

- [ ] **Step 3: Record exact limitations**

Document that no Gecko binary, benchmark, XDG default change, Crimson Glass rendering, horizontal-tab parity, or security SLA has yet been validated. Phase 1 is complete only as fork/provenance infrastructure.

- [ ] **Step 4: Prepare Phase 2 plan**

Phase 2 must cover `npm run init`, full Linux build, upstream test subsets, binary smoke test, source artifact/hash publication, and a transitional DylanOS package installed alongside Firefox ESR.
