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
