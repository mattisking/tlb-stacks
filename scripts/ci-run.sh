#!/usr/bin/env bash
# TLBStacks CI gate: build the native QML plugin and run every test suite.
# Bash form of the "Automated checks" sequence in docs/TESTING_AND_STATUS.md.
# Usage: scripts/ci-run.sh [BUILD_DIR]  (default: build/ci; absolute paths OK)
set -euo pipefail

[[ -f CMakeLists.txt && -d package ]] || { echo "ERROR: run from the repo root" >&2; exit 1; }

# Resolve a Qt6 QML test runner: Fedora names it qmltestrunner-qt6; Debian/Ubuntu
# install it as qmltestrunner (often only under /usr/lib/qt6/bin). Set
# QML_TEST_RUNNER to override the search (command name or absolute path).
resolve_qml_runner() {
    local candidate
    for candidate in qmltestrunner-qt6 qmltestrunner \
            /usr/lib/qt6/bin/qmltestrunner /usr/lib64/qt6/bin/qmltestrunner; do
        if command -v "${candidate}" >/dev/null 2>&1; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    done
    return 1
}
QML_RUNNER="${QML_TEST_RUNNER:-}"
if [[ -z "${QML_RUNNER}" ]]; then
    QML_RUNNER="$(resolve_qml_runner)" || {
        echo "ERROR: no Qt6 qmltestrunner found — tried qmltestrunner-qt6, qmltestrunner, /usr/lib/qt6/bin/qmltestrunner, /usr/lib64/qt6/bin/qmltestrunner. Install the Qt6 declarative development packages (Fedora: qt6-qtdeclarative-devel; Debian/Ubuntu: qt6-declarative-dev) or set QML_TEST_RUNNER." >&2
        exit 1
    }
elif ! command -v "${QML_RUNNER}" >/dev/null 2>&1; then
    echo "ERROR: QML_TEST_RUNNER=${QML_RUNNER} is not an executable command or path" >&2
    exit 1
fi

BUILD_DIR="$(realpath -m -- "${1:-build/ci}")"
QML_IMPORT_DIR="${BUILD_DIR}/qml"
MODULE_DIR="${QML_IMPORT_DIR}/com/mattphilmon/tlbstacks"

echo '== Configure + build plugin (also runs the CMake version-lockstep check) =='
cmake -S . -B "${BUILD_DIR}"
cmake --build "${BUILD_DIR}" -j "$(nproc)"

echo '== Native QtTest suite (tests/native-menus) =='
cmake -S tests/native-menus -B build-tests/native-menus
cmake --build build-tests/native-menus -j "$(nproc)"
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    ./build-tests/native-menus/folder-popup-test

echo '== QML suites (folder-source, categories, navigation, stack-editor, stack-group-runtime) =='
if [[ ! -f "${MODULE_DIR}/libtlbstacksplugin.so" ]]; then
    echo "ERROR: expected ${MODULE_DIR}/libtlbstacksplugin.so after the build" >&2
    exit 1
fi
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QML_IMPORT_PATH="${QML_IMPORT_DIR}"
"${QML_RUNNER}" -input tests/folder-source -o -,txt
"${QML_RUNNER}" -input tests/categories -o -,txt
"${QML_RUNNER}" -input tests/navigation -o -,txt
"${QML_RUNNER}" -input tests/stack-editor -o -,txt
"${QML_RUNNER}" -input tests/stack-group-runtime -o -,txt

echo '== Python profile tests =='
python3 -m unittest discover -s tests -v

echo 'ALL CHECKS PASSED'
