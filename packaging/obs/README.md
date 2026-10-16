# OBS packaging for TLBStacks

Staging area for publishing TLBStacks to the openSUSE Build Service
(`build.opensuse.org`). Everything here is applied with `osc` from the CLI;
no web UI required.

## Contents

- `project-meta.xml` — project meta for `home:mattisking:tlbstacks`
  (Fedora 44, x86_64).
- `tlbstacks/_service` — `tar_scm` source service pinning the release tag of
  https://github.com/mattisking/tlb-stacks.
- `tlbstacks/tlbstacks.spec` — RPM spec (builds and installs both widgets:
  `com.mattphilmon.tlbstacks` and `com.mattphilmon.tlbstacks.group`, plus the
  `com.mattphilmon.tlbstacks` QML module).
- `tlbstacks/tlbstacks.dsc` — debtransform recipe for the xUbuntu targets.
  OBS-only: there is no `debian/` tree on the OBS package; instead flat
  `debian.changelog`, `debian.control`, and `debian.rules` files are uploaded
  alongside it. They are byte-for-byte copies of the repo's
  `debian/changelog`, `debian/control`, and `debian/rules` (flat names — the
  repo `debian/` directory is the source of truth; do not edit the OBS
  copies independently).

## Release checklist (each version bump)

1. Bump `CMakeLists.txt` (`project(... VERSION ...)`) and the `KPlugin.Version`
   in **both** `package/metadata.json` and `package-group/metadata.json`.
2. Add a `debian/changelog` entry (repo copy).
3. Update `packaging/obs/tlbstacks/tlbstacks.spec`: `Version:` + `%changelog`.
4. Update `packaging/obs/tlbstacks/_service`: the `revision` param to the new
   tag.
5. Commit, tag `v<VERSION>`, push `main` + the tag. The GitHub Release
   workflow builds and publishes the assets.
6. Update the OBS package (`osc co home:mattisking:tlbstacks/tlbstacks`):
   - copy the repo `debian/changelog` → `debian.changelog`,
   - **bump `tlbstacks.dsc`**: its `Version:` field AND the
     `DEBTRANSFORM-TAR:` / `Files:` tarball reference
     (`tlbstacks-<VERSION>.tar.gz`). `set_version` rewrites the dsc Version
     at build time but NOT the tarball reference — a stale reference makes
     debtransform fail ("debian transforming failed") on every Ubuntu target
     while Fedora (spec-only) still succeeds.
   - `osc ci`, then `osc service remoterun` if the Ubuntu targets do not
     pick up the rebuild.
7. Watch: `osc -A https://api.opensuse.org results -w home:mattisking:tlbstacks tlbstacks`.

## Preconditions

1. The release tag exists and is pushed:
   `git tag -a v<VERSION> && git push origin v<VERSION>`
   (versions in `CMakeLists.txt` and both `metadata.json` files are already
   at `<VERSION>`; run `scripts/ci-run.sh` + `scripts/release-assets.sh` as the gate
   before tagging).
2. `osc` is authenticated (the account password works with
   `osc -A https://api.opensuse.org api /person/mattisking`).

## Apply (once the account works)

```sh
# 1. Create the project
osc -A https://api.opensuse.org meta prj home:mattisking:tlbstacks \
  --file packaging/obs/project-meta.xml

# 2. Create the package and commit the sources
osc -A https://api.opensuse.org co home:mattisking:tlbstacks
cd home:mattisking:tlbstacks
osc mkpac tlbstacks
cp ../../packaging/obs/tlbstacks/_service ../../packaging/obs/tlbstacks/tlbstacks.spec tlbstacks/
cd tlbstacks
osc add _service tlbstacks.spec
osc ci -m "Initial import of TLBStacks 0.2.0"
```

## Watch the build

```sh
osc -A https://api.opensuse.org results -w home:mattisking:tlbstacks
osc -A https://api.opensuse.org buildlog home:mattisking:tlbstacks tlbstacks Fedora_44 x86_64
```

## Notes / open items

- **Fedora 45:** add a `Fedora_45` repository (path `Fedora:45` / `standard`) once the
  target exists on the OBS instance — it does not exist yet (checked Oct 15; Fedora 45
  not yet GA / not yet mirrored on build.opensuse.org). Probe `osc api /build/Fedora:45`
  and add the repository block to `project-meta.xml` when it appears.

- The `Fedora:44` repository name in `project-meta.xml` is assumed to be
  `standard` (the OBS convention for the Fedora build projects). If the
  project meta is rejected, check the live repo names with
  `osc api /about` → the distributions listing, or
  `osc meta prj Fedora:44`, and adjust the `<path>` accordingly.
- The spec's runtime `Requires` (`plasma-workspace`, `kf6-kirigami`,
  `kf6-kiconthemes`, `python3`) cover the QML imports
  (`org.kde.plasma.*`, `org.kde.kirigami`, `org.kde.iconthemes`,
  `org.kde.taskmanager`) and the `profile.py` helper (stdlib only). Expect a
  first-build iteration on OBS for any missed `-devel` packages — the
  buildlog will name them exactly.
- No AppStream metainfo exists upstream yet; when one is added, it belongs
  in `%{_metainfodir}` and this spec needs a matching `%files` entry.
