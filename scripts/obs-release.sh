#!/usr/bin/env bash
# Sync the OBS debtransform contract for a release, so the flat files on OBS
# never have to be edited by hand.
#
# Usage: scripts/obs-release.sh <VERSION> [--dry-run] [--stagedir DIR]
#   VERSION    release version (tag without the leading 'v')
#   --dry-run  render the files into --stagedir (default: a temp dir) and
#              print them; never touches osc
#   --stagedir where --dry-run writes (real runs stage into a temp dir)
#
# What it does (real run):
#   1. renders the OBS flat files from the repo (the single source of truth):
#        debian/changelog -> debian.changelog
#        debian/control   -> debian.control
#        debian/rules     -> debian.rules
#        packaging/obs/tlbstacks/tlbstacks.dsc.template -> tlbstacks.dsc
#      (the template's @VERSION@ placeholders carry the two bits set_version
#      does not fix at build time: the dsc Version and the DEBTRANSFORM-TAR
#      tarball reference — a stale reference fails every Ubuntu target)
#   2. commits them to the OBS package checkout and re-runs the source
#      service so the Ubuntu targets rebuild from the new release tag.
#
# Environment:
#   OBS_API      OBS API endpoint (default https://api.opensuse.org)
#   OBS_PROJECT  (default home:mattisking:tlbstacks)
#   OBS_CHECKOUT existing osc working copy to reuse; created if missing
set -euo pipefail

usage() { echo "usage: scripts/obs-release.sh <VERSION> [--dry-run] [--stagedir DIR]" >&2; exit 2; }

[[ $# -ge 1 ]] || usage
VERSION="$1"; shift
DRY_RUN=0
STAGEDIR=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --stagedir) STAGEDIR="${2:?}"; shift ;;
        *) usage ;;
    esac
    shift
done

[[ -f CMakeLists.txt && -f debian/changelog && -f packaging/obs/tlbstacks/tlbstacks.dsc.template ]] || {
    echo "ERROR: run from the repo root" >&2; exit 1;
}

# Version lockstep: CMakeLists is the source of truth.
cmake_ver="$(sed -nE 's/^project\(TLBStacks VERSION ([0-9.]+)\).*/\1/p' CMakeLists.txt)"
meta_ver="$(python3 -c 'import json; print(json.load(open("package/metadata.json"))["KPlugin"]["Version"])')"
group_meta_ver="$(python3 -c 'import json; print(json.load(open("package-group/metadata.json"))["KPlugin"]["Version"])')"
if [[ "${VERSION}" != "${cmake_ver}" || "${VERSION}" != "${meta_ver}" || "${VERSION}" != "${group_meta_ver}" ]]; then
    echo "ERROR: version mismatch: arg=${VERSION} cmake=${cmake_ver} widget=${meta_ver} group=${group_meta_ver}" >&2
    echo "Bump CMakeLists.txt, both metadata.json files, and debian/changelog first (see packaging/obs/README.md)." >&2
    exit 1
fi

# The changelog's top entry must describe this release.
head -1 debian/changelog | grep -q "(${VERSION}-" || {
    echo "ERROR: debian/changelog's newest entry is not ${VERSION}; add it first." >&2
    exit 1
}

# A real run publishes against the tag: it must exist and match HEAD.
if [[ $DRY_RUN -eq 0 ]]; then
    tag_commit="$(git rev-parse "v${VERSION}^{commit}" 2>/dev/null)" || {
        echo "ERROR: tag v${VERSION} does not exist; tag and push it first." >&2; exit 1;
    }
    [[ "${tag_commit}" == "$(git rev-parse HEAD)" ]] || {
        echo "ERROR: tag v${VERSION} does not point at the checked-out commit; re-tag." >&2; exit 1;
    }
fi

render() {
    local dir="$1"
    cp debian/changelog "${dir}/debian.changelog"
    cp debian/control   "${dir}/debian.control"
    cp debian/rules     "${dir}/debian.rules"
    sed "s/@VERSION@/${VERSION}/g" packaging/obs/tlbstacks/tlbstacks.dsc.template > "${dir}/tlbstacks.dsc"
}

if [[ -n "${STAGEDIR}" ]]; then
    STAGE="${STAGEDIR}"
else
    STAGE="$(mktemp -d)"
fi
rm -rf "${STAGE}"
mkdir -p "${STAGE}"
render "${STAGE}"

echo "Rendered OBS contract for ${VERSION}:"
ls -1 "${STAGE}"
echo "--- tlbstacks.dsc ---"
cat "${STAGE}/tlbstacks.dsc"

if [[ $DRY_RUN -eq 1 ]]; then
    echo "dry run: nothing was committed to OBS"
    exit 0
fi

API="${OBS_API:-https://api.opensuse.org}"
PROJECT="${OBS_PROJECT:-home:mattisking:tlbstacks}"
PKG="tlbstacks"
CHECKOUT="${OBS_CHECKOUT:-${XDG_CACHE_HOME:-$HOME/.cache}/obs-tlbstacks}"

if [[ -d "${CHECKOUT}/.osc" ]]; then
    (cd "${CHECKOUT}" && osc -A "${API}" update)
else
    rm -rf "${CHECKOUT}"
    osc -A "${API}" co "${PROJECT}" "${PKG}" -o "${CHECKOUT}"
fi

cp "${STAGE}/debian.changelog" "${STAGE}/debian.control" "${STAGE}/debian.rules" "${STAGE}/tlbstacks.dsc" "${CHECKOUT}/"
(cd "${CHECKOUT}" && osc -A "${API}" add -- tlbstacks.dsc debian.changelog debian.control debian.rules 2>/dev/null || true)
(cd "${CHECKOUT}" && osc -A "${API}" ci -m "TLBStacks ${VERSION} — sync the debtransform contract from the repo")
(cd "${CHECKOUT}" && osc -A "${API}" service remoterun "${PROJECT}" "${PKG}")

echo "OBS contract committed; watch: osc -A ${API} results -w ${PROJECT} ${PKG}"
