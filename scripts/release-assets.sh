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

head_commit="$(git rev-parse HEAD)"
ref_commit="$(git rev-parse "${REF}^{commit}")"
if [[ "${ref_commit}" != "${head_commit}" ]]; then
    echo "ERROR: SOURCE_REF ${REF} resolves to ${ref_commit}, not the checked-out commit ${head_commit}; archive from a clean checkout of the tag (or HEAD)" >&2
    exit 1
fi
dirty="$(git status --porcelain -- CMakeLists.txt package src | grep -v '__pycache__' || true)"
if [[ -n "${dirty}" ]]; then
    echo "ERROR: uncommitted or untracked release inputs (CMakeLists.txt, package/, src/ — __pycache__ ignored):" >&2
    printf '%s\n' "${dirty}" >&2
    echo "Commit or remove them so the source tarball, plugin, and widget payload describe the same tree." >&2
    exit 1
fi

cmake_ver="$(sed -nE 's/^project\(TLBStacks VERSION ([0-9.]+)\).*/\1/p' CMakeLists.txt)"
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
[[ "$(find build/stage/usr -name 'libtlbstacksplugin.so' | wc -l)" -eq 1 ]] || {
    echo "ERROR: expected exactly one staged libtlbstacksplugin.so inside the archived usr/ tree. A cached TLB_QML_INSTALL_DIR override can stage the module elsewhere — package from a build directory configured without install overrides." >&2; exit 1; }
staged_module_dir="$(dirname "$(find build/stage/usr -name 'libtlbstacksplugin.so')")"
[[ -f "${staged_module_dir}/qmldir" && -f "${staged_module_dir}/tlbstacksplugin.qmltypes" ]] || {
    echo "ERROR: staged module metadata (qmldir/qmltypes) missing inside usr/" >&2; exit 1; }
[[ -f "build/stage/usr/share/plasma/plasmoids/${PLASMOID_ID}/metadata.json" ]] || {
    echo "ERROR: staged widget metadata.json missing inside usr/" >&2; exit 1; }
tar -C build/stage -czf "${stage_tarball}" usr

echo '== Store-ready plasmoid payload =='
(cd package && zip -qr "../${plasmoid}" metadata.json contents -x '*__pycache__*' '*.pyc')

ls -l dist
echo "RELEASE ASSETS READY: ${src_tarball} ${stage_tarball} ${plasmoid}"
