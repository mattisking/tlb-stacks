# Stack widget: historical overlap and implementation review

[Project guide](README.md) · [Feature tracker](FEATURE_TRACKER.md)


**Original review:** October 3, 2026 · **Updated:** October 5, 2026 · **Scope:** functionality already implemented in individual TLBStacks stacks.

## Assessment

We are on course for the original product's core purpose: a compact launcher that opens a personally arranged or dynamically populated menu. The current implementation captures that purpose with selected applications, live folders, application-category menus, custom icons, hover opening, cascades, and portable menu configuration.

The meaningful differences are deliberate simplifications or consistency issues within existing behavior. They do not call for rebuilding the Windows application. Our most consequential decision is using different menu implementations at different depths: Plasma/QML at the root, native QMenu for folder cascades. That solved the pop-out problem, but it leaves presentation and update behavior uneven.

This review does not inventory unimplemented historical features or propose a plugin SDK or whole-panel replacement. Future plugins and a larger panel are considered only where today's stack boundaries could help or hinder reuse.

## Evidence and limits

The original review used the working tree, including uncommitted changes. This update incorporates the asynchronous-source refactor, context actions, keyboard fixes, and user-reported Plasma testing through October 5. Source inspection, automated tests, and desktop confirmation are different evidence; see [testing and status](TESTING_AND_STATUS.md) for what has and has not been checked.

Historical references point to [our historical inventory](TRUE_LAUNCH_BAR_WINDOWS_FEATURE_REFERENCE.md). **M** refers to the supplied manual's printed pages, as defined there. Its pictured build is v3.2.13 RC1; later historical features retain their separate release citations.

## Cross-reference: what our existing features cover

| Current stack feature | Historical overlap | What we implemented and how closely it matches |
|---|---|---|
| One named, configurable panel button | ORG-01–03; M pp. 6–11 | Each Plasma widget owns its name, icon, settings, and popup. Several instances give separate menu buttons; Plasma manages their placement. This is a sound translation of individual TLB menu buttons into Plasma widgets, not a complete TLB toolbar. |
| Selected-application stack | ORG-02, ORG-06; M pp. 7–9 | Stores ordered desktop application IDs. Search adds installed apps; the selected list removes and reorders them with Up/Down. This covers deliberate launcher organization. Using a settings editor instead of filesystem shortcuts is an intentional interaction/storage difference. |
| Application activation | ORG-01; M p. 7 | KDE resolves application IDs and launches through ApplicationLauncherJob. The application remains responsible for its desktop metadata. This is the Linux equivalent of launching the represented shortcut, without copying Windows shortcut files. |
| Live-folder stack | VF-01, VF-03–06; M pp. 10–11, 21 | Select a local directory, show files and subfolders, open files through KDE, and traverse folders as menus. Mounted locations can qualify as local paths; arbitrary remote URLs do not. This directly covers the core virtual-folder use case. |
| Dynamic category stack | Historical dynamic-menu purpose; VF-10 is an analogy, not the same feature | Reads installed applications' real categories, includes matches from any selected category, removes duplicates, and sorts by name. Refreshes on KDE application-database changes and popup opening. This is a Linux-specific way to obtain a live menu; we should not label it an exact recreation of Windows shell search. |
| File patterns | VF-07; M pp. 18–19 | Semicolon-separated inclusion patterns select files; directories remain navigable. This covers the useful recurring-filter behavior. Root and native submenus now share the asynchronous reader and filtering/sorting policy. Parity remains covered by tests. |
| Side-opening subfolders | INPUT-01–02, VIEW-06; M pp. 16, 35–36 | Hover/click on a root folder row opens an anchored native menu; deeper folders are native submenus. Native menus own placement and pointer traversal. This recovers the original cascading interaction, although root and child appearance differ. |
| Adjustable hover opening | INPUT-01–02; M pp. 35–36 | One saved 0–2000 ms value, default 250 ms, drives panel hover, first subfolder, and deeper submenu opening. This is a purposeful simpler policy than the original's separate timers. It opens menus, not applications. |
| Icons-only and icon-plus-label display | VIEW-01; M pp. 12–14 | Root menus switch between a single column of icons and icon/text rows. Labels elide and names appear in separate Plasma tooltips. This covers those presentation goals, but our icons-only view is not the original's configurable grid. Native child menus still display labels. |
| Icon sizing and bounded menus | VIEW-04–05; M pp. 39–41 | Root icons use 16–64 px settings and derived row sizes. Application menus cap height at 480 px and prevent horizontal scrolling; folder roots also consider available screen height. These meet the compact-menu objective. Size rules are not shared with native child menus. |
| Stack and application icon overrides | Section 8.1; M pp. 53–54 | Supports theme names and user image files, with reset to defaults. Per-application overrides use desktop IDs. Custom files use an image renderer preserving artwork, while theme names use the theme renderer. Overrides can be edited in the selected-app list; category rendering can reuse matching retained overrides. |
| Menu export/import with images | Section 9; M pp. 20, 22, 53–54 | Exports a ZIP containing versioned JSON and referenced image assets. Import stages settings in the editor until Apply. Missing application IDs remain stored; live-folder targets need relocation on another machine. This matches toolbar backup/asset portability more closely than historical named settings profiles. |

### Source map

- [Configuration schema](../package/contents/config/main.xml): per-instance persisted settings.
- [Configuration editor](../package/contents/ui/ConfigGeneral.qml): selection/order, source choice, icons, timing, import/export.
- [Main widget](../package/contents/ui/main.qml): panel integration, app/category display, sizing, hover and activation.
- [Category matching](../package/contents/ui/ApplicationCategories.js): any-category matching, deduplication, sorting.
- [Folder root](../package/contents/ui/FolderMenu.qml): asynchronous polling source, patterns, availability, first cascade.
- [Native folder menus](../src/folderpopup.cpp): child enumeration, ordering, submenu creation and delay.
- [KDE bridge](../src/launcher.cpp): app discovery/launching, file opening, native anchoring, profile helper calls.
- [Icon rendering](../package/contents/ui/ApplicationIcon.qml) and [override lookup](../package/contents/ui/IconOverrides.js).
- [Portable menu helper](../package/contents/code/profile.py): managed images, validation, archive versions and asset references.

## Existing behavior worth reviewing

### 1. Define one presentation policy across folder depths

**Observed:** FolderMenu passes hover delay and file filters into the native cascade. It does not pass iconsOnly, icon size, row height, or width. FolderPopup always creates normal labeled QMenu actions with style-defined sizing. Root custom images use ApplicationIcon; native folder actions use QIcon.

**Effect:** a narrow icon-only root can open a labeled, differently sized child. The user-visible settings currently sound broader than their actual reach. This is the largest departure within functionality we already expose.

**Suggested direction:** keep the successful native cascade behavior. Decide whether display settings apply to the root only or the entire stack, then make labels and implementation agree. If consistency is desired, pass a small presentation policy through the existing bridge before adding more display controls. Do not return to the QML popup approach merely to unify code; earlier user testing exposed placement and stability problems there.

### 2. Live-folder refresh now has an explicit policy

**Implemented:** root and child enumeration share asynchronous `folderreader` and
entry descriptions. The root polls at one-second intervals while open; a native
child is a snapshot until reopened. Filtering, hidden-file exclusion, and sorting
are shared. Two workers, bounded queued work, shared in-flight reads, and cooperative
abandonment limit unnecessary work. A blocked kernel filesystem call remains a limit.

This resolves the earlier synchronous-read finding, but does not mean continuous
updates at every depth. Root file changes can appear before an already-open child
is refreshed. Keep that distinction in user guidance and tests.

### 3. Shared entries and navigation now separate source policy from rendering

**Implemented:** application and file descriptions use `StackEntry` fields for
identity, name, icon, action/target, availability, children, and context capabilities.
Selected apps preserve order; categories compute membership; folders enumerate.
See [the entry model](STACK_ENTRY_MODEL.md).

Root selection/wrapping uses `MenuNavigation.js` across all three sources. Renderers
retain focus and presentation responsibilities; native descendants still use QMenu.
Keyboard previews open without taking selection, Right enters, and Left restores
the parent. Mouse-to-keyboard and return-to-parent cases received desktop testing.
This is reuse for today's stacks, not a plugin SDK or support for mixed items yet.

Context actions remain source-specific: selected applications can be removed from
the stack, whereas local files can be moved to Trash. Categories have computed
membership, and folders themselves do not currently expose Trash. This preserves
the distinction between removing a shortcut and modifying a filesystem item.

### 4. Preserve the strong portability decisions and clarify terminology

**Observed:** custom images are copied into managed storage by content hash. Export includes referenced assets and theme names; it does not bundle applications or folder contents. Manifest version 3 is written, with versions 1–3 accepted and defaults filled for older settings. Import validates archive entries and checksums before restoring referenced images.

**Effect:** this is faithful to the original's portable-custom-icon goal. Theme names remain dependent on the destination theme; IDs and folder paths may not resolve on another machine. That is an environment dependency, not lost configuration.

**Suggested direction:** retain stable identities and versioned transport. Call the user-facing operation menu export/import; the code's “profile” name should not imply historical named settings presets. If settings expand, consolidate defaults and migrations: currently related definitions appear in XML, QML, and Python. A full widget export should also remain distinct from any future appearance-only preset.

Managed images are written while editing or importing, even if the user later cancels the settings dialog. Configuration cancellation still works, but unused assets can remain. Any eventual cleanup must account for references from every widget instance because the image store is shared.

### 5. Profile work no longer blocks the desktop while waiting

**Implemented:** the helper runs through asynchronous QProcess signals, request
identities, a busy editor state, overlap rejection, and a nonblocking timeout.
Imports remain staged until Apply. The former synchronous wait finding is resolved
in code; stalled-storage and full real-editor round-trip checks remain separate
validation work.

### 6. Catalog updates and activation errors have explicit context

**Implemented:** catalog changes refresh selected descriptors, category results,
and missing-application warnings. Missing IDs stay saved. Application/file launch
jobs report errors; obsolete activation generations are ignored and failures do
not force a dismissed popup back open.

Application roots close when a launch starts; file-root activation can leave the
menu open. That behavioral difference remains an explicit design consideration,
not a claim that all activation outcomes are now identical.

## What to preserve as we think forward

The individual Plasma widget is a sensible unit: it owns one stack's configuration and relies on Plasma for panel placement. Keep that boundary. A future larger panel could host the same stack definitions; it should not require each stack to learn task management now.

Likewise, our category source is a useful adaptation, and managed custom assets are already stronger than relying on the original image's location. Neither choice takes us off course. The work to consider first is consistency across menu levels, responsive existing operations, and explicit source/item boundaries—not a broad historical feature catch-up.

**Next consistency work:** see [the feature tracker](FEATURE_TRACKER.md) for
requested changes and acceptance criteria. This comparison owns historical overlap,
not a second roadmap. [Testing and status](TESTING_AND_STATUS.md) records validation.
