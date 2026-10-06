# TLBStacks CI & Release Pipeline — Design

- **Date:** 2026-10-06
- **Status:** Phase 1 (CI + GitHub Releases) approved in chat. Store distribution ("Get New Widgets") is a separate follow-up design cycle; research in flight — see "Follow-up" below.
- **Scope owner:** release pipeline work only; no widget behavior changes.

## Goal

GitHub Actions CI that:

1. **Gates every push to `main` and every PR** with a full compile of the native QML plugin plus all three test suites (C++ QtTest, QML, Python).
2. **Turns a `v*` tag into a GitHub Release** whose assets include a canonical source tarball, a convenience prebuilt tree, and a store-ready `.plasmoid` payload — the exact artifact the KDE Store consumes, so a future store upload never needs a rebuild.

Success criteria: a green CI run on an ordinary PR; a real `v0.1.0` tag produces a release with all three assets and a green build+test gate before anything publishes.

## Non-goals

- Automated KDE Store uploads (no public API confirmed as of 2026-10; under research — follow-up cycle).
- Per-distro binary packages (COPR/AUR/OBS) — a later decision.
- Plasma 5 / KF5 / Qt5 support.
- Changes to widget behavior or packaging layout.

## Grounded facts (from repo recon, 2026-10-06)

- The plasmoid is **not pure QML**: `src/` builds `libtlbstacksplugin.so` via `qt_add_qml_module` (C++20, Qt6 Core/Qml/Quick/Widgets/Concurrent, KF6 KIO/Service, Plasma::Activities + ActivitiesStats) and the QML imports it at runtime. A bare `.plasmoid` installs but cannot run without the plugin.
- Version lockstep is **enforced at configure time**: `CMakeLists.txt:25-29` reads `package/metadata.json` and `FATAL_ERROR`s unless `KPlugin.Version` == `PROJECT_VERSION`. Both are `0.1.0` today (`CMakeLists.txt:3`, `package/metadata.json:13`). No git tags exist.
- Tests: `tests/native-menus/` (standalone CMake project, QtTest binary `folder-popup-test`), QML suites `tests/folder-source/`, `tests/categories/`, `tests/navigation/` via `qmltestrunner-qt6`, and `tests/test_profiles.py` via `python3 -m unittest`. Documented env: `QT_QPA_PLATFORM=offscreen`, `QT_QUICK_BACKEND=software`, `QML_IMPORT_PATH=build/qml` (`docs/TESTING_AND_STATUS.md:45-62`).
- Install target: `TLB_INSTALL_WIDGET` installs `package/` to `${KDE_INSTALL_DATADIR}/plasma/plasmoids/com.mattphilmon.tlbstacks`; plugin install goes to the Qt6 QML dir. `DESTDIR` staging recipe exists (`docs/DEPLOYMENT.md:244-268`).
- No `.github/`, no CI, no scripts dir. `.venv/` is untracked but not ignored.
- Dev/test environment of record: Fedora + Wayland (`README.md:62`).

## Design

### Build environment (shared by both workflows)

- Runner: `ubuntu-latest` with `container: fedora:latest` (matches the environment of record; KDE/Qt6/KF6 dev packages all available in Fedora repos).
- Deps installed via `dnf`: CMake ≥ 3.24, gcc-c++, Qt6 dev (qtbase, qtdeclarative), KF6 dev (kio, kservice), PlasmaActivities + PlasmaActivitiesStats devel, `extra-cmake-files`, `python3`, `zip`. Exact Fedora package names are resolved during implementation with a `dnf repoquery`/dry-run check and pinned in the workflow.

### `scripts/ci-run.sh` — single gate script

One script, called by both workflows, so the PR gate and the release gate can never drift apart:

1. `cmake -S . -B build/ci && cmake --build build/ci` — compiles the plugin (also exercises the version-lockstep check at configure time).
2. Native tests: `cmake -S tests/native-menus -B build-tests/native-menus && cmake --build`, then run `folder-popup-test`.
3. QML tests: run the three suites via `qmltestrunner-qt6` with `QT_QPA_PLATFORM=offscreen`, `QT_QUICK_BACKEND=software`, `QML_IMPORT_PATH=build/ci` (QML suites import the plugin, so they run after the main build).
4. Python tests: `python3 -m unittest discover -s tests -v`.

Exit non-zero on any failure. The script is also runnable locally, replacing hand-copied command sequences.

### `.github/workflows/ci.yml` — push to `main` + PRs

Checkout → Fedora container → dnf deps → `scripts/ci-run.sh`. Nothing else. Fast feedback on compile/test health.

### `.github/workflows/release.yml` — tags `v*` only

Checkout → Fedora container → dnf deps → `scripts/ci-run.sh` (hard gate; failure aborts before any release work), then:

1. **Version assertion:** extract tag, `PROJECT_VERSION`, and `metadata.json` `KPlugin.Version`; fail unless all three match. (Protects against tagging without bumping, or bumping without tagging.)
2. **Source tarball:** `git archive` from the tag → `tlbstacks-<ver>-source.tar.gz` (canonical asset).
3. **Prebuilt staged tree:** `DESTDIR=$PWD/stage cmake --install build/ci` → tar → `tlbstacks-<ver>-<distro><ver>.tar.gz` (distro stamped from `/etc/os-release` at build time). Contains `libtlbstacksplugin.so`, qmldir/qmltypes, and the plasmoid package tree.
4. **Store-ready payload:** zip `package/` → `com.mattphilmon.tlbstacks.plasmoid`.
5. **Publish:** `softprops/action-gh-release@v2` with `generate_release_notes: true` and a body template stating the exact build environment and that the `.plasmoid` requires the native plugin — where to get it (source tarball / staged tree) and how.

### Version discipline (process, not code)

Bump `CMakeLists.txt:3` and `package/metadata.json:13` in the same commit, then tag `vx.y.z` matching. CMake already enforces file lockstep; the release workflow enforces tag lockstep.

### Repo hygiene

Add `.venv/` to `.gitignore`.

## Artifacts per release

| Asset | Purpose | Works where |
|---|---|---|
| `tlbstacks-<ver>-source.tar.gz` | Canonical; build anywhere with Qt6/KF6/PlasmaActivities | Any Plasma 6 distro |
| `tlbstacks-<ver>-<distro><ver>.tar.gz` | Convenience prebuilt plugin + package tree | Distros with compatible Qt6/KF6 (stated in notes) |
| `com.mattphilmon.tlbstacks.plasmoid` | KDE Store payload ("Get New Widgets" installs this) | Installs anywhere; requires the plugin from the other assets |

## Validation

1. Land the workflows on a branch → `ci.yml` runs green on the PR itself.
2. After merge, cut tag `v0.1.0` (version is already `0.1.0`, no bump needed) → `release.yml` must run the full gate, then publish the release.
3. Verify by inspection: all three assets downloadable; staged tree layout matches `docs/DEPLOYMENT.md` staging recipe; `.plasmoid` unpacks to `metadata.json + contents/`.
4. Negative check: a deliberate tag/version mismatch (on a scratch tag, e.g. `v0.1.1-test`) must fail the assertion and publish nothing. Tag deleted after.

No release ships unless the build + all three test suites pass.

## Follow-up (separate design cycle, not this spec)

Store distribution via "Get New Widgets" — research concluded 2026-10-06:

- **No automated store uploads are possible.** The OpenDesktop/OCS platform has no public write/upload API (POST/PUT content attempts return `999 unknown request`); API keys only serve read endpoints. KDE Store updates are manual web-UI uploads.
- **Get New Widgets cannot serve compiled plugins.** Official KDE developer guidance: a widget with a C++ plugin "cannot be distributed via Get Hot New Stuff" and needs distro packaging (PPA / AUR / COPR / OBS). The `.plasmoid` payload is QML/JS/images only; it unpacks into `~/.local/share/plasma/plasmoids/` with no mechanism to install a system-level `.so`.

The follow-up cycle will decide: a store listing page for discovery/ratings linking to distro packages, a graceful missing-plugin UX in the widget, and which distro channels to target first (COPR for Fedora — the environment of record; AUR). The `.plasmoid` asset produced by this pipeline remains the store payload input.
