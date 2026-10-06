# TLBStacks CI & Release Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** GitHub Actions CI that gates every push/PR with a full build + all test suites, and turns a `v*` tag into a GitHub Release carrying a source tarball, a prebuilt staged tree, and a store-ready `.plasmoid` payload.

**Architecture:** One gate script (`scripts/ci-run.sh`) is shared by both workflows so the PR gate and the release gate can never drift apart. A second script (`scripts/release-assets.sh`) asserts version lockstep and builds the three release artifacts from the completed CI build. `ci.yml` runs the gate on push to `main` and PRs; `release.yml` runs the same gate plus asset building on tags, then publishes with `softprops/action-gh-release@v2`.

**Tech Stack:** GitHub Actions (`ubuntu-latest` runners with `fedora:44` containers), bash, CMake/ECM 6, Qt6/KF6, `softprops/action-gh-release@v2`, `gh` CLI for verification.

**Spec:** `docs/superpowers/specs/2026-10-06-ci-release-pipeline-design.md`

## Global Constraints

- Plasma 6 / KF6 / Qt6 only; no Plasma 5 support anywhere.
- Container image is pinned to `fedora:44` — the environment of record (local machine: fc44, Qt 6.11.2, KF6 6.30.0, plasma-activities 6.7.5). One approved deviation from the spec's "fedora:latest": pinning avoids surprise breakage when Fedora 45 lands.
- Version lockstep is mandatory: tag (without `v`) == `CMakeLists.txt:3` project version == `package/metadata.json` `KPlugin.Version`. All are `0.1.0` today.
- Release assets are exactly: `tlbstacks-<ver>-source.tar.gz`, `tlbstacks-<ver>-fedora44.tar.gz` (distro stamped from `/etc/os-release`), `com.mattphilmon.tlbstacks.plasmoid`.
- Nothing publishes unless the build and all three test suites (native QtTest, QML, Python) pass.
- `.gitignore` gains `.venv/`.
- Do not touch the local `feature/tooltip-polish` branch; all work happens on `main` or short-lived `ci/*` branches.
- Commit subjects follow the repo's existing style: plain imperative, no prefixes (e.g. "Add CI gate script").
- The repo has no tags yet; the first real release is `v0.1.0`, which needs no version bump.

## Review Focus

1. **QML suites can't find the built plugin** (import-path drift between the docs' `build/qml` and a different build dir): `ci-run.sh` asserts `libtlbstacksplugin.so` exists at `<BUILD_DIR>/qml/com/mattphilmon/tlbstacks/` before running `qmltestrunner-qt6`, with an explicit error. Pinned by Task 1's positive run (the assert sits on the real path exercised by the run).
2. **Staged tarball missing the plugin** (lib vs lib64 layout drift): `release-assets.sh` requires exactly one staged `libtlbstacksplugin.so` plus the staged widget `metadata.json` before tarring. Pinned by Task 2 Step 5's `tar -tzf` content check.
3. **`.plasmoid` shipping `__pycache__`/`.pyc`**: zip uses `-x '*__pycache__*' '*.pyc'`. Pinned by Task 2 Step 5's `unzip -l` grep returning zero matches.
4. **A version-mismatched tag publishing anyway**: the assertion in `release-assets.sh` runs before any artifact is built, and the workflow hard-fails on non-zero exit. Pinned by Task 4's negative tag test (red run, no release).
5. **Checkout failing in the container** (`git` missing from the minimal Fedora image): every workflow installs `git` via `dnf` *before* `actions/checkout`. Pinned by Task 3's PR run, which exercises in-container checkout.

---

### Task 1: CI gate script `scripts/ci-run.sh`

**Files:**
- Create: `scripts/ci-run.sh`
- Modify: `.gitignore` (add `.venv/` under the Python caches section)

**Interfaces:**
- Consumes: nothing (self-contained; requires the Qt6/KF6 dev packages listed in Task 3).
- Produces: exit 0 with `ALL CHECKS PASSED` as the last output line; a completed build at `<BUILD_DIR>` (default `build/ci`) containing `qml/com/mattphilmon/tlbstacks/libtlbstacksplugin.so`. Task 2 consumes this build **without re-running it** (it only reconfigures the install prefix).

- [ ] **Step 1: Add `.venv/` to `.gitignore`**

In `.gitignore`, change:

```
# Python caches
__pycache__/
*.py[cod]
```

to:

```
# Python caches
__pycache__/
*.py[cod]
.venv/
```

- [ ] **Step 2: Write `scripts/ci-run.sh`**

Create `scripts/ci-run.sh` with exactly:

```bash
#!/usr/bin/env bash
# TLBStacks CI gate: build the native QML plugin and run every test suite.
# Bash form of the "Automated checks" sequence in docs/TESTING_AND_STATUS.md.
# Usage: scripts/ci-run.sh [BUILD_DIR]  (default: build/ci)
set -euo pipefail

BUILD_DIR="${1:-build/ci}"
QML_IMPORT_DIR="${PWD}/${BUILD_DIR}/qml"
MODULE_DIR="${QML_IMPORT_DIR}/com/mattphilmon/tlbstacks"

[[ -f CMakeLists.txt && -d package ]] || { echo "ERROR: run from the repo root" >&2; exit 1; }

echo '== Configure + build plugin (also runs the CMake version-lockstep check) =='
cmake -S . -B "${BUILD_DIR}"
cmake --build "${BUILD_DIR}" -j "$(nproc)"

echo '== Native QtTest suite (tests/native-menus) =='
cmake -S tests/native-menus -B build-tests/native-menus
cmake --build build-tests/native-menus -j "$(nproc)"
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    ./build-tests/native-menus/folder-popup-test

echo '== QML suites (folder-source, categories, navigation) =='
if [[ ! -f "${MODULE_DIR}/libtlbstacksplugin.so" ]]; then
    echo "ERROR: expected ${MODULE_DIR}/libtlbstacksplugin.so after the build" >&2
    exit 1
fi
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QML_IMPORT_PATH="${QML_IMPORT_DIR}"
qmltestrunner-qt6 -input tests/folder-source -o -,txt
qmltestrunner-qt6 -input tests/categories -o -,txt
qmltestrunner-qt6 -input tests/navigation -o -,txt

echo '== Python profile tests =='
python3 -m unittest discover -s tests -v

echo 'ALL CHECKS PASSED'
```

Then make it executable:

```bash
chmod +x scripts/ci-run.sh
```

- [ ] **Step 3: Syntax-check the script**

Run: `bash -n scripts/ci-run.sh`
Expected: no output, exit 0.

- [ ] **Step 4: Verify the root guard fails outside the repo root**

Run: `cd package && ../scripts/ci-run.sh; echo "exit=$?"`
Expected: `ERROR: run from the repo root` and `exit=1` (the `set -e` exit of the guard propagates as a failed script).

- [ ] **Step 5: Run the full gate locally**

Run from the repo root: `scripts/ci-run.sh && echo "exit=$?"`
Expected: all four sections pass — native suite reports 21 QtTest cases, all three QML suites report `Totals: ... passed`, Python `unittest` reports `OK` — and the last line is `ALL CHECKS PASSED` with `exit=0`. (The machine is the environment of record: Fedora 44, Qt 6.11.2, KF6 6.30.0, plasma-activities 6.7.5.)

- [ ] **Step 6: Commit**

```bash
git add scripts/ci-run.sh .gitignore
git commit -m "Add CI gate script running all test suites"
```

---

### Task 2: Release assets script `scripts/release-assets.sh`

**Files:**
- Create: `scripts/release-assets.sh`
- Test: manual runs + `unzip -l` / `tar -tzf` inspections (verified below)

**Interfaces:**
- Consumes: a completed `scripts/ci-run.sh` build at `BUILD_DIR` (default `build/ci`), from Task 1.
- Produces: `dist/tlbstacks-<ver>-source.tar.gz`, `dist/tlbstacks-<ver>-fedora44.tar.gz`, `dist/com.mattphilmon.tlbstacks.plasmoid`, exit 0, last line `RELEASE ASSETS READY: ...`. Task 4's workflow calls this script as `scripts/release-assets.sh "${GITHUB_REF_NAME#v}"`.

- [ ] **Step 1: Write `scripts/release-assets.sh`**

Create `scripts/release-assets.sh` with exactly:

```bash
#!/usr/bin/env bash
# Assert version lockstep and build the release assets into dist/.
# Usage: scripts/release-assets.sh <VERSION> [BUILD_DIR] [SOURCE_REF]
#   VERSION    release version (tag without the leading 'v')
#   BUILD_DIR  completed ci-run.sh build (default: build/ci)
#   SOURCE_REF ref archived for the source tarball (default: v<VERSION>;
#              pass HEAD to test locally before tagging)
set -euo pipefail

VERSION="${1:?usage: scripts/release-assets.sh <VERSION> [BUILD_DIR] [SOURCE_REF]}"
BUILD_DIR="${2:-build/ci}"
REF="${3:-v${VERSION}}"
PLASMOID_ID='com.mattphilmon.tlbstacks'
MODULE_PATH='com/mattphilmon/tlbstacks'   # the import URI as a filesystem path

[[ -f CMakeLists.txt && -d package ]] || { echo "ERROR: run from the repo root" >&2; exit 1; }
[[ -f "${BUILD_DIR}/qml/${MODULE_PATH}/libtlbstacksplugin.so" ]] || {
    echo "ERROR: no built plugin in ${BUILD_DIR}; run scripts/ci-run.sh first" >&2
    exit 1
}

cmake_ver="$(sed -nE 's/^project\(TLBStacks VERSION ([0-9.]+)\).*/\1/p' CMakeLists.txt | head -n1)"
meta_ver="$(python3 -c 'import json; print(json.load(open("package/metadata.json"))["KPlugin"]["Version"])')"
if [[ "${VERSION}" != "${cmake_ver}" || "${VERSION}" != "${meta_ver}" ]]; then
    echo "ERROR: version mismatch: tag=${VERSION} cmake=${cmake_ver} metadata=${meta_ver}" >&2
    echo "Bump CMakeLists.txt:3 and package/metadata.json:13 to ${VERSION}, commit, then re-tag." >&2
    exit 1
fi

os_id="$(sed -nE 's/^ID=//p' /etc/os-release)"
os_ver="$(sed -nE 's/^VERSION_ID=//p' /etc/os-release)"
src_tarball="dist/tlbstacks-${VERSION}-source.tar.gz"
stage_tarball="dist/tlbstacks-${VERSION}-${os_id}${os_ver}.tar.gz"
plasmoid="dist/${PLASMOID_ID}.plasmoid"

rm -rf dist build/stage
mkdir -p dist

echo "== Source tarball (${REF}) =="
git archive --format=tar.gz --prefix="tlbstacks-${VERSION}/" -o "${src_tarball}" "${REF}"

echo '== Prebuilt staged tree (/usr prefix, DESTDIR staging) =='
cmake -S . -B "${BUILD_DIR}" -DCMAKE_INSTALL_PREFIX=/usr >/dev/null
DESTDIR="${PWD}/build/stage" cmake --install "${BUILD_DIR}"
[[ "$(find build/stage -name 'libtlbstacksplugin.so' | wc -l)" -eq 1 ]] || {
    echo "ERROR: expected exactly one staged libtlbstacksplugin.so" >&2; exit 1; }
[[ -f "build/stage/usr/share/plasma/plasmoids/${PLASMOID_ID}/metadata.json" ]] || {
    echo "ERROR: staged widget metadata.json missing" >&2; exit 1; }
tar -C build/stage -czf "${stage_tarball}" usr

echo '== Store-ready plasmoid payload =='
(cd package && zip -qr "../${plasmoid}" metadata.json contents -x '*__pycache__*' '*.pyc')

ls -l dist
echo "RELEASE ASSETS READY: ${src_tarball} ${stage_tarball} ${plasmoid}"
```

Then: `chmod +x scripts/release-assets.sh`

- [ ] **Step 2: Syntax-check the script**

Run: `bash -n scripts/release-assets.sh`
Expected: no output, exit 0.

- [ ] **Step 3: Verify a completed gate build exists**

Run: `scripts/ci-run.sh`
Expected: `ALL CHECKS PASSED`, exit 0 (fresh default `build/ci` for this task).

- [ ] **Step 4: Verify the version-mismatch guard fails and creates nothing**

Run: `scripts/release-assets.sh 9.9.9 build/ci HEAD; echo "exit=$?"`
Expected: `ERROR: version mismatch: tag=9.9.9 cmake=0.1.0 metadata=0.1.0`, `exit=1`, and no `dist/` directory created (`ls dist` → "No such file or directory") — the assert runs before any artifact work.

- [ ] **Step 5: Build the real assets locally and inspect them**

Run: `scripts/release-assets.sh 0.1.0 build/ci HEAD; echo "exit=$?"`
Expected: `RELEASE ASSETS READY: dist/tlbstacks-0.1.0-source.tar.gz dist/tlbstacks-0.1.0-fedora44.tar.gz dist/com.mattphilmon.tlbstacks.plasmoid`, `exit=0`.

Then verify each artifact:

```bash
unzip -l dist/com.mattphilmon.tlbstacks.plasmoid | grep -E 'metadata\.json|contents/ui/main\.qml'
unzip -l dist/com.mattphilmon.tlbstacks.plasmoid | grep -c '__pycache__\|\.pyc' || true
tar -tzf dist/tlbstacks-0.1.0-fedora44.tar.gz | grep -E 'libtlbstacksplugin\.so|plasma/plasmoids/com\.mattphilmon\.tlbstacks/metadata\.json'
tar -tzf dist/tlbstacks-0.1.0-source.tar.gz | head -n 2
```

Expected: the first grep shows both `metadata.json` and `contents/ui/main.qml`; the `__pycache__` count is `0`; the stage-tarball grep shows the staged `.so` and the staged widget `metadata.json`; the source tarball's first entries begin with `tlbstacks-0.1.0/`.

- [ ] **Step 6: Commit**

```bash
git add scripts/release-assets.sh
git commit -m "Add release asset packaging script"
```

---

### Task 3: Push/PR workflow `.github/workflows/ci.yml`

**Files:**
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: `scripts/ci-run.sh` (Task 1), called with no arguments (default `build/ci`).
- Produces: a GitHub Actions run named "CI" on every push to `main` and every PR.

- [ ] **Step 1: Confirm `gh` is authenticated**

Run: `gh auth status`
Expected: "Logged in to github.com account ..." — if not, stop and ask the user to authenticate (`gh auth login`) before proceeding.

- [ ] **Step 2: Write `.github/workflows/ci.yml`**

Create `.github/workflows/ci.yml` with exactly:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    container:
      image: fedora:44
    steps:
      - name: Install build dependencies
        run: |
          dnf -y --setopt=install_weak_deps=False install \
            git cmake extra-cmake-modules gcc-c++ \
            qt6-qtbase-devel qt6-qtdeclarative-devel \
            kf6-kio-devel kf6-kservice-devel \
            plasma-activities-devel plasma-activities-stats-devel \
            python3 zip
      - name: Checkout
        uses: actions/checkout@v4
      - name: Build and run all test suites
        run: scripts/ci-run.sh
```

Note: `git` is installed *before* `actions/checkout` — the minimal Fedora image does not include it (Review Focus #5).

- [ ] **Step 3: Sanity-check the YAML parses**

Run:

```bash
python3 -c 'import yaml' 2>/dev/null || python3 -m pip install --user --quiet pyyaml
python3 -c 'import yaml; yaml.safe_load(open(".github/workflows/ci.yml"))' && echo YAML-OK
```

Expected: `YAML-OK`.

- [ ] **Step 4: Open a PR and watch CI run on it**

```bash
git switch -c ci/pipeline
git add .github/workflows/ci.yml
git commit -m "Add CI workflow for pushes and pull requests"
git push -u origin ci/pipeline
gh pr create --fill
gh pr checks --watch
```

Expected: the "build-and-test" check goes green (the suites already passed locally in the same package set; the container adds only the checkout/dependency steps).

If it fails: `gh run view --log-failed` from the repo root, fix, push again. Do not merge until green.

- [ ] **Step 5: Merge and verify the main-push run**

```bash
gh pr merge --squash --delete-branch
gh run list --workflow=CI --limit 1
```

Expected: the newest run (trigger: push to `main`) completes successfully.

---

### Task 4: Tag workflow `.github/workflows/release.yml` + negative mismatch test

**Files:**
- Create: `.github/workflows/release.yml`

**Interfaces:**
- Consumes: `scripts/ci-run.sh` (Task 1) and `scripts/release-assets.sh` (Task 2, called with `"${GITHUB_REF_NAME#v}"`).
- Produces: a GitHub Release with the three `dist/` assets on every `v*` tag whose version matches the repo files; a hard failure and **no release** on mismatched tags.

- [ ] **Step 1: Write `.github/workflows/release.yml`**

Create `.github/workflows/release.yml` with exactly:

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    container:
      image: fedora:44
    steps:
      - name: Install build dependencies
        run: |
          dnf -y --setopt=install_weak_deps=False install \
            git cmake extra-cmake-modules gcc-c++ \
            qt6-qtbase-devel qt6-qtdeclarative-devel \
            kf6-kio-devel kf6-kservice-devel \
            plasma-activities-devel plasma-activities-stats-devel \
            python3 zip tar
      - name: Checkout
        uses: actions/checkout@v4
      - name: Build and run all test suites
        run: scripts/ci-run.sh
      - name: Assert versions and build release assets
        run: scripts/release-assets.sh "${GITHUB_REF_NAME#v}"
      - name: Publish GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: |
            dist/tlbstacks-*-source.tar.gz
            dist/tlbstacks-*-fedora*.tar.gz
            dist/com.mattphilmon.tlbstacks.plasmoid
          generate_release_notes: true
          body: |
            ## Install

            Build from the **source tarball** following
            [docs/DEPLOYMENT.md](https://github.com/mattisking/tlb-stacks/blob/main/docs/DEPLOYMENT.md).
            The **prebuilt tree** is built in CI on Fedora 44 (Qt 6.11, KF6 6.30,
            plasma-activities 6.7) and unpacks a `/usr` install tree — only use it on
            distributions with compatible Qt6/KF6 versions.

            Note: the `.plasmoid` payload alone will not run. TLBStacks includes a
            compiled C++ plugin (`libtlbstacksplugin.so`), so it cannot be installed
            through Plasma's "Get New Widgets" dialog.
```

- [ ] **Step 2: Sanity-check the YAML parses**

Same as Task 3 Step 3, against `.github/workflows/release.yml`.
Expected: `YAML-OK`.

- [ ] **Step 3: Land it via PR**

```bash
git switch -c ci/release-workflow
git add .github/workflows/release.yml
git commit -m "Add tag-triggered release workflow"
git push -u origin ci/release-workflow
gh pr create --fill
gh pr checks --watch
gh pr merge --squash --delete-branch
```

Expected: CI green (the release workflow itself only triggers on tags), PR merged to `main`.

- [ ] **Step 4: Negative test — a mismatched tag must fail and publish nothing**

```bash
git tag v0.1.1-mismatch
git push origin v0.1.1-mismatch
gh run watch "$(gh run list --workflow=Release --limit 1 --json databaseId --jq '.[0].databaseId')"
```

Expected: the Release run **fails** at the "Assert versions and build release assets" step with `ERROR: version mismatch: tag=0.1.1-mismatch cmake=0.1.0 metadata=0.1.0`, and:

```bash
gh release view v0.1.1-mismatch
```

reports the release does not exist.

- [ ] **Step 5: Clean up the scratch tag**

```bash
git tag -d v0.1.1-mismatch
git push origin :refs/tags/v0.1.1-mismatch
```

Expected: tag gone locally and on the remote (`git ls-remote --tags origin` shows nothing).

---

### Task 5: First real release `v0.1.0` (end-to-end)

**Files:**
- None created or modified — this task exercises the merged pipeline.

**Interfaces:**
- Consumes: merged `ci.yml`, `release.yml`, both scripts, repo files at version `0.1.0`.
- Produces: GitHub Release `v0.1.0` with three verified assets.

- [ ] **Step 1: Verify preconditions**

```bash
git status --short --branch
git log --oneline -1
grep -n 'VERSION' CMakeLists.txt | head -n 1
```

Expected: clean tree on `main`, and `project(TLBStacks VERSION 0.1.0)` — no version bump needed.

- [ ] **Step 2: Tag and push**

```bash
git tag -a v0.1.0 -m "TLBStacks 0.1.0"
git push origin v0.1.0
gh run watch "$(gh run list --workflow=Release --limit 1 --json databaseId --jq '.[0].databaseId')"
```

Expected: the Release run passes the gate, builds assets, and publishes; watch ends successfully.

- [ ] **Step 3: Verify the release and its assets**

```bash
gh release view v0.1.0 --json name,isDraft,assets
gh release download v0.1.0 -D /tmp/opencode/v0.1.0-check
unzip -l /tmp/opencode/v0.1.0-check/com.mattphilmon.tlbstacks.plasmoid | grep -E 'metadata\.json|contents/ui/main\.qml'
tar -tzf /tmp/opencode/v0.1.0-check/tlbstacks-0.1.0-fedora44.tar.gz | grep 'libtlbstacksplugin\.so'
tar -tzf /tmp/opencode/v0.1.0-check/tlbstacks-0.1.0-source.tar.gz | head -n 2
```

Expected: release is published (not draft) with exactly three assets; the `.plasmoid` contains `metadata.json` and `contents/ui/main.qml`; the prebuilt tree contains `libtlbstacksplugin.so`; the source tarball's entries begin with `tlbstacks-0.1.0/`.

- [ ] **Step 4: Record evidence**

Save the `gh release view` JSON output (asset names + sizes) into the task notes — this is the completion evidence for the spec's validation section. No commit is made in this task.

---

### Task 6: Documentation for releases

**Files:**
- Modify: `README.md:67-69` (project status paragraph)
- Modify: `docs/DEPLOYMENT.md:264-268` (staging section closing paragraph)

**Interfaces:**
- Consumes: the live `v0.1.0` release from Task 5 (links must point at real assets).
- Produces: docs that describe releases instead of claiming none exist.

- [ ] **Step 1: Update the README project-status paragraph**

In `README.md`, replace:

```
There is currently no packaged release or plugin SDK. Planned work is tracked in
[the feature tracker](docs/FEATURE_TRACKER.md); historical True Launch Bar features
are research material, not promises about this project.
```

with:

```
Releases are published on [the releases page](https://github.com/mattisking/tlb-stacks/releases):
each tag builds and tests the widget in CI and attaches a source tarball, a prebuilt
Fedora package tree, and the Plasma widget payload. TLBStacks includes a compiled
C++ plugin, so it cannot be installed through Plasma's "Get New Widgets" dialog —
build from the source tarball, or install a distribution package. Planned work is
tracked in [the feature tracker](docs/FEATURE_TRACKER.md); historical True Launch Bar
features are research material, not promises about this project.
```

- [ ] **Step 2: Update the DEPLOYMENT staging paragraph**

In `docs/DEPLOYMENT.md`, replace:

```
The staged tree contains the native plugin, qmldir and type metadata, widget
contents and metadata, and GPL license. It excludes the historical manual and
development tests. This is an install tree, not yet an RPM; it does not declare
package-manager dependencies or restart Plasma. CMake checks that widget metadata
and project versions agree (currently 0.1.0).
```

with:

```
The staged tree contains the native plugin, qmldir and type metadata, widget
contents and metadata, and GPL license. It excludes the historical manual and
development tests. This is an install tree, not an RPM; it does not declare
package-manager dependencies or restart Plasma. CMake checks that widget metadata
and project versions agree. `scripts/release-assets.sh` automates this staging for
tagged releases; its output is attached to each
[GitHub release](https://github.com/mattisking/tlb-stacks/releases).
```

- [ ] **Step 3: Verify the stale claims are gone**

```bash
grep -n 'no packaged release' README.md
grep -n 'not yet an RPM\|currently 0.1.0' docs/DEPLOYMENT.md
```

Expected: no matches from either grep.

- [ ] **Step 4: Commit**

```bash
git add README.md docs/DEPLOYMENT.md
git commit -m "Document release installation"
```

---

## Self-Review (completed)

- **Spec coverage:** gate script ✓ (Task 1), ci.yml ✓ (Task 3), release.yml with version assertion + 3 assets + softprops ✓ (Tasks 2/4), `.gitignore` `.venv/` ✓ (Task 1), validation incl. negative tag + `v0.1.0` e2e ✓ (Tasks 4/5), repo docs reflecting releases ✓ (Task 6). Follow-up (store/OBS) correctly absent.
- **Placeholders:** none — every step carries exact commands and expected output.
- **Consistency:** `PLASMOID_ID`/`com.mattphilmon.tlbstacks`, `build/ci`, `dist/` asset names, and the `fedora44` stamp match across Tasks 1–6 and the release.yml `files:` globs.
- **Review Focus:** each of the five failure modes is pinned by a test in its owning task.
- **One approved deviation from the spec:** container pinned to `fedora:44` instead of `fedora:latest` (matches the environment of record; avoids Fedora-45 breakage).
