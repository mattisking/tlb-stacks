<h1><img src="docs/images/logo.png" width="64" height="64" alt="TLBStacks logo" align="absmiddle">&nbsp;TLBStacks</h1>

**Application groups and live folder menus for KDE Plasma 6.**

Keep related tools together without filling your panel with individual launchers.
Add a TLBStacks widget for each group, give it a name and icon, and open its menu
by clicking or hovering over the panel button.

Prefer everything in one place? The experimental **TLBStacks Group** widget bundles
several stacks side by side with regular single-application launchers in one panel
widget — reorder them freely, edit them in one dialog, and back the whole group up
as a single portable profile.

Inspired by the original Windows True Launch Bar, TLBStacks is an independent
Linux project focused on individual Plasma widgets. It is not a task manager or
a replacement desktop panel.

<!-- IMAGE 1 (hero): docs/images/hero-panel.png
     Open Selected Applications menu with titled separators, attached to the panel. -->
<p align="center">
  <img src="docs/images/hero-panel.png" width="320" alt="TLBStacks in a Plasma panel with an open menu showing titled separators">
</p>

## What it does

**Single stacks** — one TLBStacks widget per group, each with its own panel button:

- **Selected Applications:** build an ordered group of installed applications,
  add visual separators with optional titles (e.g. `--- Office ---`), customize icons, and remove shortcuts without
  uninstalling applications.
- **Application Categories:** populate a stack from one or more desktop-entry
  categories, with a preview of matching applications in the editor.
- **Recent / Frequent Applications:** rank KDE-recorded app usage, optionally filtered
  by application categories and current Activity.
- **Live Folder:** browse a local folder and cascading subfolders, filter files
  with patterns, and move files to Trash from the context menu.
- **Your preferred presentation:** custom panel icons, configurable icon size,
  optional icons-only application menus, tooltips, and adjustable opening delay.
  Live Folder always displays filenames.
- **Mouse and keyboard navigation:** navigate menus with arrow keys, activate
  entries with Enter, and dismiss with Escape.
- **Portable menus:** export and import a stack, including custom icon images.

**TLBStacks Groups (experimental)** — one widget that holds all of the above:

- **Mix and match:** place direct application launchers next to stacks of any
  source type, in any order, in a single panel widget (up to 500 entries).
- **One editor for everything:** both widgets share the same stack editor —
  pick a stack type, edit its Contents (members, categories, folder, usage
  ranking) and Appearance (name, icon, sizes, delays) in tabbed pages, with
  the group's whole layout visible as a panel preview and item tree.
- **Group backup:** export the entire group — every stack, launcher, and
  custom icon — as one portable profile, or import one to replace or add to
  the current setup.

## Screenshots

<!-- IMAGE 2 (group hero): docs/images/group-panel.png
      The TLBStacks Group widget on a panel: two or three direct launcher icons
      (e.g. browser, terminal) sitting next to two stack buttons (e.g.
      Development, Games), with one stack's menu open showing its entries and a
      titled separator. Should read at a glance as "launchers and stacks living
      side by side in one widget". Similar crop/framing to hero-panel.png. -->
<p align="center">
  <img src="docs/images/group-panel.png" width="360" alt="TLBStacks Group widget on a Plasma panel mixing direct launchers and stacks, one stack menu open">
</p>

<!-- IMAGE 3: docs/images/live-folder.png
     Live Folder menu with a cascading subfolder open to the side, plus the
     right-click context menu (Move to Trash) if it fits. -->
<p align="center">
  <img src="docs/images/live-folder.png" width="700" alt="Live Folder menu with cascading subfolders">
</p>

<!-- IMAGE 4a/4b: docs/images/categories.png and docs/images/recent-frequent.png
     Application Categories with a category cascade open (left); Recent / Frequent,
     ideally icons-only (right). Taken separately, shown side by side. -->
<table align="center">
  <tr>
    <td align="center"><img src="docs/images/categories.png" width="210" alt="Application Categories menu"><br><sub>Application Categories</sub></td>
    <td align="center"><img src="docs/images/recent-frequent.png" width="220" alt="Recent / Frequent menu"><br><sub>Recent / Frequent</sub></td>
  </tr>
</table>

<!-- IMAGE 5 (group editor): docs/images/group-editor.png
      The group configuration dialog: panel-order preview strip across the top
      (gear + item icons + add button), the item tree on the left with one stack
      expanded showing its member summary, and the inspector on the right on the
      Contents tab — category chips with the selected ones visually set apart
      (accent + check), and the read-only matching-applications preview below.
      Window wide enough to show all three regions clearly. -->
<p align="center">
  <img src="docs/images/group-editor.png" width="700" alt="Group configuration dialog with panel preview strip, item tree, and the shared stack editor">
</p>

<!-- IMAGE 6 (single editor): docs/images/configuration.png — RE-TAKE.
      The single widget now opens the same shared stack editor directly (no
      preview strip/tree). Show the Selected Applications Contents page with the
      member list, a separator label being edited, and the kind segments
      (Selected / Live Folder / Categories / Recent) visible with their
      persistent borders — or the search-on-add application picker open over it. -->
<p align="center">
  <img src="docs/images/configuration.png" width="700" alt="The shared stack editor in the single widget: kind segments, Contents tab, member list with separators">
</p>

## Project status

Early development, tested primarily on Fedora with KDE Plasma and Wayland.
Other distributions may work, but installation paths and dependencies vary.
Screen-edge, scaling, and multi-monitor coverage is still incomplete; see
[testing and known verification gaps](docs/TESTING_AND_STATUS.md).

Releases are published on [the releases page](https://github.com/mattisking/tlb-stacks/releases):
each tag builds and tests the widget in CI and attaches a source tarball, a prebuilt
Fedora package tree, and the Plasma widget payload. TLBStacks includes a compiled
C++ plugin, so it cannot be installed through Plasma's "Get New Widgets" dialog —
build from the source tarball, or install a distribution package. The TLBStacks
Group widget is still experimental: it is installed only when you opt in during
the build (`-WithGroup`), and it is not part of the release payloads yet. Planned work is
tracked in [the feature tracker](docs/FEATURE_TRACKER.md); historical True Launch Bar
features are research material, not promises about this project.

## Getting started

You need KDE Plasma 6, a C++20 compiler, CMake, Qt 6 and KDE Frameworks 6 development
libraries, Python 3, and PowerShell for the supplied installer.

1. Clone this repository: `git clone https://github.com/mattisking/tlb-stacks.git`.
2. Follow [Build and install](docs/DEPLOYMENT.md), including its prerequisites.
   Pass `-WithGroup` to the installer to also deploy the experimental group widget.
3. Add **TLBStacks** (or **TLBStacks Group**) through Plasma's widget picker and
   configure its content source.

The installer builds a native QML module as well as installing the widget package.
By default it restarts Plasma; review the deployment instructions first. If you
used the earlier project name, follow the [one-time migration instructions](docs/DEPLOYMENT.md#renaming-existing-installations).

## Documentation and contributions

- [Project guide](docs/README.md): documentation index and maintenance conventions.
- [Entry model and navigation](docs/STACK_ENTRY_MODEL.md): current architecture.
- [Feature tracker](docs/FEATURE_TRACKER.md): requested and deferred work.
- [Contributing](CONTRIBUTING.md): bug reports, changes, and verification.
- [Issues](https://github.com/mattisking/tlb-stacks/issues): report a problem or propose an improvement.

## License and attribution

Copyright © 2026 Matt Philmon and contributors.

TLBStacks original source code and project-authored documentation are licensed
under the **GNU General Public License, version 3 or (at your option) any later
version** (`GPL-3.0-or-later`). See [LICENSE](LICENSE). The software is provided
without warranty.
See [third-party notices](THIRD_PARTY_NOTICES.md) for the historical manual and
dependencies. TLBStacks is not affiliated with TORDEX or the original True Launch Bar.
