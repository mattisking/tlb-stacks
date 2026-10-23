# Security notes

TLBStacks ships a compiled C++ backend, so it is fair to ask what that code
can and cannot do. This page states the security posture; each claim points
at the code that backs it.

## What the backend is

The native part is a small QML plugin (`src/`) — `taskindex`, `launcher`,
`plugin`, `stackentry` — loaded by plasmashell for the widgets. It runs as
your user, inside the desktop session. There is no daemon, no root/setuid
component, no background service, no telemetry, and no network client: the
plugin opens no sockets, and the only `http://` strings in the tree are XML
namespace declarations.

## What it can execute, and how

- **Desktop applications** are launched through
  `KIO::ApplicationLauncherJob` from the installed `.desktop` entry — the
  standard KDE launch path, with no reinterpretation of the Exec line.
- **Custom launchers** run via `QProcess::startDetached(executable,
  arguments)` (`src/launcher.cpp`, `activateEntry`): a direct exec with an
  argument vector — **no shell is ever involved**, so configuration strings
  cannot inject commands. Before anything runs, the target is verified to be
  an absolute path, a regular file, and executable.
- **Task actions** (activate/minimize/close a window) go through Plasma's
  taskmanager model — the same requests the stock task manager makes.

## Configuration and profiles

- Importing a profile executes nothing: it only fills configuration
  fields. Profiles never bundle executables (documented invariant in
  `docs/DEPLOYMENT.md`); an imported launcher can only reference an
  installed application or an absolute executable path, and every custom
  command is visible in the editor before it can be used. Importing a
  profile from someone else means trusting their launcher definitions —
  the same trust model as importing a `.desktop` file — so review the
  Contents page after importing anything you did not export yourself.
- User-controlled names (groups, stacks, launchers, windows) are
  HTML-escaped at every rendered binding (`package/contents/ui/StackMembers.js`)
  and rendered as plain text elsewhere; there is no rich-text injection path.
  This is regression-tested in the suites.

## Package integrity

- RPMs and debs are built by the [openSUSE Build
  Service](https://build.opensuse.org/project/show/home:mattisking:tlbstacks)
  from a release **tag** of this repository (never a branch), served over
  HTTPS, and signed with the project's OBS signing key.
- When adding the repository, verify the key fingerprint shown by the OBS
  project page against the key you import — the standard OBS step — and
  prefer the repo URLs printed in this README.
- The GitHub Release assets are checksum-published by the CI workflow, whose
  actions are SHA-pinned with scoped permissions.

## Reporting

Found something? Open an issue at
https://github.com/mattisking/tlb-stacks/issues — or email the maintainer
address in `debian/control` / the RPM changelog for anything you would
rather not file publicly.
