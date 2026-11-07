# OBS packaging for TLBStacks

Staging area for publishing TLBStacks to the openSUSE Build Service
(`build.opensuse.org`). Everything here is applied with `osc` from the CLI;
no web UI required.

## Contents

- `project-meta.xml` — project meta for `home:mattisking:tlbstacks`
  (Fedora 44/45, x86_64).
- `tlbstacks/_service` — `tar_scm` source service pinning the release tag of
  https://github.com/mattisking/tlb-stacks.
- `tlbstacks/tlbstacks.spec` — RPM spec (builds and installs both widgets:
  `com.mattphilmon.tlbstacks` and `com.mattphilmon.tlbstacks.group`, plus the
  `com.mattphilmon.tlbstacks` QML module).
- `tlbstacks/tlbstacks.dsc.template` — debtransform recipe for the xUbuntu
  targets, with `@VERSION@` placeholders. OBS-only: there is no `debian/`
  tree on the OBS package; instead flat `debian.changelog`, `debian.control`,
  and `debian.rules` files are uploaded alongside the rendered dsc. They are
  byte-for-byte copies of the repo's `debian/changelog`, `debian/control`,
  and `debian/rules` — never edit the OBS copies by hand; the renderer in
  `scripts/obs-release.sh` produces them from the repo.

## Release checklist (each version bump)

1. Bump `CMakeLists.txt` (`project(... VERSION ...)`) and the `KPlugin.Version`
   in **both** `package/metadata.json` and `package-group/metadata.json`.
2. Add a `debian/changelog` entry (repo copy).
3. Update `packaging/obs/tlbstacks/tlbstacks.spec`: `Version:` + `%changelog`.
4. Update `packaging/obs/tlbstacks/_service`: the `revision` param to the new
   tag. (obs-release.sh refuses to run against a pin lagging the release, and
   syncs the pin to OBS with the rest of the contract — the stale-pin failure
   mode of the 0.3.3/0.3.4 releases cannot recur as long as the script is the
   only path to OBS.)
5. Commit, tag `v<VERSION>`, push `main` + the tag. The GitHub Release
   workflow builds and publishes the assets.
6. Run `scripts/obs-release.sh <VERSION>` — it renders the flat debian files
   from the repo `debian/` tree, the dsc from
   `packaging/obs/tlbstacks/tlbstacks.dsc.template`, and the `_service` pin,
   commits them to the OBS package, and re-runs the source service so the
   Ubuntu targets rebuild.
   (Use `--dry-run` to preview without touching OBS. The dsc's
   `DEBTRANSFORM-TAR` reference and Version both come from the template —
   the stale-tarball-reference failure mode of the 0.3.2 release cannot
   recur as long as the script is the only path to OBS.)
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
osc -A https://api.opensuse.org buildlog home:mattisking:tlbstacks tlbstacks Fedora_45 x86_64
```

## Notes / open items

- **Fedora 45:** the `Fedora_45` repository (path `Fedora:45` / `standard`)
  was added on 2026-11-06 and the first build published successfully. It was
  added through the web UI's Meta editor (the "Add repository" wizard's
  distribution list did not list Fedora 45 yet) with:

  ```xml
  <repository name="Fedora_45">
    <path project="Fedora:45" repository="standard"/>
    <arch>x86_64</arch>
  </repository>
  ```

  `project-meta.xml` in this directory carries the same block; if the web UI
  and this file ever drift, re-apply the file with the `osc meta prj` command
  in the "Apply" section above.

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
