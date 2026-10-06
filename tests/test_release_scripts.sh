#!/usr/bin/env bash
# Regression tests for the release pipeline scripts (post-review fix pass).
# Usage: tests/test_release_scripts.sh — run from the repo root after a green
# scripts/ci-run.sh build exists in build/ci.
set -uo pipefail

pass=0; fail=0
ok()  { echo "PASS: $1"; pass=$((pass+1)); }
bad() { echo "FAIL: $1"; fail=$((fail+1)); }

MODULE_PATH='com/mattphilmon/tlbstacks'

[[ -f "build/ci/qml/${MODULE_PATH}/libtlbstacksplugin.so" ]] || {
    echo 'precondition failed: no build/ci plugin; run scripts/ci-run.sh first' >&2
    exit 2
}

echo '== T0: clean local packaging still succeeds =='
if scripts/release-assets.sh 0.1.0 build/ci HEAD >/dev/null 2>&1 \
    && tar -tzf dist/tlbstacks-0.1.0-fedora44.tar.gz | grep 'libtlbstacksplugin.so' >/dev/null; then
    ok 'T0 clean run builds assets with the staged plugin'
else
    bad 'T0 clean run builds assets with the staged plugin'
fi
rm -rf dist

echo '== T1: version mismatch is rejected and creates nothing =='
if scripts/release-assets.sh 9.9.9 build/ci HEAD >/dev/null 2>&1; then
    bad 'T1 mismatched version rejected'
else
    ok 'T1 mismatched version rejected'
fi
if [[ -e dist ]]; then bad 'T1 dist absent after failure'; else ok 'T1 dist absent after failure'; fi

echo '== T2: a SOURCE_REF that is not the checked-out commit is rejected =='
if scripts/release-assets.sh 0.1.0 build/ci cb65ab1 >/dev/null 2>&1; then
    bad 'T2 non-HEAD SOURCE_REF rejected'
else
    ok 'T2 non-HEAD SOURCE_REF rejected'
fi
rm -rf dist

echo '== T3: uncommitted release inputs are rejected =='
printf '\n' >> CMakeLists.txt
if scripts/release-assets.sh 0.1.0 build/ci HEAD >/dev/null 2>&1; then
    bad 'T3 dirty release inputs rejected'
else
    ok 'T3 dirty release inputs rejected'
fi
git checkout -- CMakeLists.txt
rm -rf dist

echo '== T4: cached absolute TLB_QML_INSTALL_DIR override cannot yield a plugin-less tarball =='
if [[ ! -f "build/ci-override/qml/${MODULE_PATH}/libtlbstacksplugin.so" ]]; then
    cmake -S . -B build/ci-override -DTLB_QML_INSTALL_DIR=/tmp/opencode/tlb-override-qml >/dev/null 2>&1
    cmake --build build/ci-override -j "$(nproc)" >/dev/null 2>&1
fi
if scripts/release-assets.sh 0.1.0 build/ci-override HEAD >/dev/null 2>&1; then
    if tar -tzf dist/tlbstacks-0.1.0-fedora44.tar.gz | grep 'libtlbstacksplugin.so' >/dev/null; then
        ok 'T4 override build: tarball contains the plugin'
    else
        bad 'T4 override build: tarball contains the plugin'
    fi
else
    ok 'T4 override build: packaging fails loudly'
fi
rm -rf dist

echo '== T5: release notes carry no hardcoded toolchain versions =='
if grep -qE 'Qt 6\.[0-9]+, KF6 6\.[0-9]+' .github/workflows/release.yml; then
    bad 'T5 no hardcoded Qt/KF6 versions in release body'
else
    ok 'T5 no hardcoded Qt/KF6 versions in release body'
fi

echo
echo "result: ${pass} passed, ${fail} failed"
[[ "${fail}" -eq 0 ]]
