# Stack Groups — delivery checkpoints

[Project guide](README.md) · [Feature F-015](FEATURE_TRACKER.md#f-015) · [Deployment](DEPLOYMENT.md#experimental-stack-group)

## Agreed scope

An optional **TLBStacks Group** widget holds an ordered collection of stacks and
direct application launchers. Existing individual TLBStacks widgets remain available.
No task management, nested groups, drag sorting, or command customization is required
for the first release. F-009 can supply custom launch behavior later.

Configuration will show the ordered items on the left and the selected item's
settings on the right. Apply/Cancel covers the whole editing session. Reuse stack
behavior rather than creating an independent implementation for grouped stacks.

## Checkpoints

| Step | Deliverable | Desktop acceptance |
|---|---|---|
| 1 | Separate empty shell, editable name and opt-in installation | Add/move/remove; configure name; Apply/Cancel; restart persistence; horizontal/vertical panels |
| 2 | Search/add direct application launchers, Remove and Up/Down | Launching, ordering, tooltips, keyboard access, persistence and Apply/Cancel |
| 3 | Selected Applications stacks alongside launchers; list/detail editor | Existing popup/actions/navigation; switching between two stacks; focus return |
| 4 | Categories, Recent/Frequent and Live Folder sources | Source settings; cascades, keyboard navigation and dismissal |
| 5 | Import individual stacks; export a selected stack or entire group | Ordered round trips, icons, portable paths; compatibility with standalone stacks |
| 6 | Panel polish and configure-selected-item access | Spacing, orientation, screen edges and daily-use regression checks |

Each checkpoint ends in a user test before the next implementation step. Commit/push
a completed checkpoint after acceptance. No automatic migration of existing widgets.

## Current checkpoint and resume notes

**Group configuration is rebuilt around a shared stack editor (October 7, 2026,
branch `shared-stack-editor`); desktop verification of that rebuild is pending.
Panel sizing/highlighting stays accepted from the step-6 first pass, and the
group-button right-click/hover fix remains uncommitted in the main checkout.**

The user reported “looks good. Works. icons all work.” after installing step 2.
This confirms the reported launcher/icon behavior; it does not independently
certify every optional orientation and keyboard check below.

- Package: `package-group`, ID `com.mattphilmon.tlbstacks.group`.
- Settings: `General/groupName` and `General/items`. Each instance has independent
  Plasma configuration. `items` is JSON `{version, items: [...]}`. Launcher-only groups without appearance overrides retain version 1;
  Selected Applications stacks use version 2, and groups with Categories, Activity
  or Live Folder use version 3. Direct-launcher appearance overrides use version 4.
  Versions 1–4 read here; older widgets reject
  newer formats rather than dropping unsupported stacks. Application entries have `id`,
  `type: "application"`, and `desktopId`; stacks have `id`, `type: "stack"`, and
  a `settings` object. IDs survive reordering.
- The editor stages all edits in cfg properties. The panel only reads saved
  settings; Apply/Cancel remains managed by Plasma. Future/invalid item formats
  are reported and not replaced with an empty list by the editor.
- Search/add uses the existing Launcher catalog; direct activation uses its KDE
  launch API. Missing installed apps keep their entry and report launch failure.
- Panel orientation determines row/column layout. Arrow keys wrap between buttons;
  Home/End select endpoints; Enter/Space activate. Tooltips delay 700 ms.
- Duplicate application selection is blocked for now. IDs are separate from desktop
  IDs so F-009 can introduce distinct launch variants later without replacing identity.
- Selected Applications stacks now use the same `ApplicationMenu.qml` as the
  standalone widget, exposed through the native QML module. It owns rows, icons,
  tooltips, selection/navigation, activation and context actions. Group hosts one
  anchored Plasma dialog and restores focus to its stack button on dismissal.
- Group configuration shows the panel order as a preview strip above a resizable
  split view: an expandable item tree on the left, settings on the right. The
  shared stack editor (see the [shared editor section](#shared-stack-editor-rebuild-branch-shared-stack-editor))
  covers stack names/icons, icons-only mode, size, hover delay, application
  membership and ordering, separators (appended, labeled, reordered, removed) and
  per-application icon overrides through Choose…/Image…/Reset. Tree child rows are
  plain summary labels; selecting them for editing is a deferred increment.
- Categories, Recent/Frequent and local Live Folder are now selectable. Category
  matching reuses the shared helper; each activity button owns its own ActivitySource
  cache and refreshes on opening. Folder rendering reuses FolderMenu, including its
  native cascades, filtering, Trash actions and keyboard behavior.
- Switching sources preserves inactive settings. Live Folder always displays labels.
  Folder heights are remembered in memory per stack/path/filter/size; a new session
  can show a loading size until its first listing completes.
- Group import/export now reuses the standalone profile helper. Individual stack
  imports append a new item; whole-group imports replace staged editor contents.
  Apply saves either change; Cancel preserves the saved group. Custom commands
  remain future work. Imported per-application icon overrides are retained and rendered.
- Developer installation stays opt-in via `-WithGroup`; normal releases exclude it.

Validation: group entry tests run in the existing CI navigation suite. Static QML
checks cannot resolve the manually registered Launcher type or Plasma's `i18n`.
The user has accepted the launcher checkpoint. Keep the detailed checks below for
regression testing; orientation, restart persistence and individual keyboard cases
were not separately reported.

Step-3 desktop feedback: a populated stack opened with only a sliver visible.
The group dialog main item had a width but no explicit height. `GroupStackContent`
now supplies actual content-driven height (capped at 480 px for the scrolling list),
computed from entries before delegates settle. Runtime tests cover long-to-short
switching and icons-only sizing. The user confirmed the sizing fix and expected Selected Applications behavior.
The user subsequently confirmed that the separator controls work.

Step-4 feedback: category search was restored in the group editor, preserving
hidden selections. Recent hover lag was traced to refresh work occurring before
the popup was shown. The group now displays cached results first and schedules a
refresh afterward; ActivitySource caches application eligibility until categories
or the installed catalog change and only notifies entry bindings when results
actually change. Each activity stack retains its independent query/results.
The user reports that Recent responsiveness now works well. Grouped Live Folder
cascades/dismissal have not been explicitly confirmed; keep those checks pending.

## Shared stack editor rebuild (branch `shared-stack-editor`)

October 7, 2026: group configuration is rebuilt around one stack editor shared
with the standalone widget. This delivers step 2 of the
[configuration design](CONFIGURATION_DESIGN.md#delivery-order--resume-point)
(introduce the editor structure over existing settings) in code. Desktop
verification is still pending, and nothing is merged: the main checkout still
holds the uncommitted right-click/hover work, and the user decides merge order
after reviewing that WIP.

What shipped on this branch:

- `package/contents/ui/StackSettingsEditor.qml` — one editor for a stack's
  settings: a kind-segment row (Selected / Live folder / Categories / Recent),
  Contents and Appearance tabs, and one Contents page per source. It edits plain
  data and emits partial `{field: value}` changes; it never touches `cfg_*`
  properties or the group's stored JSON, so each host persists through its own
  storage. Per-application icon Image… and member Reset run through the
  launcher's `manageIcon` operation (Choose… opens the theme icon dialog and
  applies the picked name directly), so the same flows work from both widgets.
  Members are added through the shared search-on-add dialog.
- `package/contents/ui/AppPickerDialog.qml` — the search-on-add picker; search
  takes space only while adding, and `exclude` hides applications already in the
  target list.
- `package/contents/ui/CategoryChipBar.qml` — a filterable chip cloud whose
  selection state is host-owned: chips are not checkable, and the highlighted
  look derives from the host's array so the visuals cannot desync from the data.
- `package/contents/ui/StackMembers.js` — shared separator member-ID helpers
  (`tlbstacks-separator:<number>[:<label>]`) for the editor; `GroupItems.js`
  keeps its own copies for the group schema flow.
- The standalone host (`package/contents/ui/ConfigGeneral.qml`) synthesizes a
  `stackSettings` object from its `cfg_*` keys, feeds it to the editor, and
  writes partial changes back into the same `cfg_*` keys Plasma commits on
  Apply/OK. Import/export and the unavailable-applications report are unchanged.
- The group host (`package-group/contents/ui/ConfigGeneral.qml`) shows a preview
  strip of the panel in order (group-gear header, add footer, one cell per item),
  an expandable item tree (stack rows expand to plain summary labels, not
  selectable rows), a breadcrumb linking back to the group page, a resizable
  `SplitView`, and a group page / launcher page / stack page per selection. The
  stack page embeds the shared editor; the launcher page swaps its application
  through `GroupItems.replaceLauncher`; the add menu offers "Application
  launcher…" (shared picker) and "Stack" (added and auto-expanded).
- Persistence is unchanged: the standalone widget keeps every `cfg_*` key it had,
  the group keeps `General/groupName` plus `General/items` (versions 1–3), and no
  schema or migration changed. Apply/Cancel staging and the import/export flows
  are preserved.

Explicitly deferred (not built here): inherited group defaults (the prototype's
`-1` values), a group-level panel icon config key, launcher custom label/icon
overrides, selectable tree child rows, and drag-and-drop reordering.

Merge-time note: the groupSelection per-item configuration handoff exists only in
the main checkout's uncommitted WIP and was deliberately not ported. When that
WIP lands, its consumption block and its test must be re-wired into the new group
host layout (preview strip / tree / inspector). Expect textual overlap in
`package-group/contents/ui/ConfigGeneral.qml` and `src/CMakeLists.txt`. The
right-click/hover fix (design step 1) is part of that uncommitted WIP and
remains pending desktop verification.

Manual desktop verification (not automatable here). Install both widgets
(`cmake --build build/ci --target install` configured with `-DTLB_INSTALL_GROUP=ON`,
or `kpackagetool6 -t Plasma/Applet -u package` and `-u package-group`), open each
config dialog, and check:

1. Preview strip selection sync (strip ↔ tree ↔ inspector, both directions).
2. Tree expand/collapse per stack.
3. Add menu: "Application launcher…" through the picker; "Stack" appears and
   auto-expands in the tree.
4. Launcher page: swap the Application combo and confirm the launcher follows.
5. Breadcrumb link returns to the group page.
6. Contents/Appearance tabs on all four kinds in both widgets.
7. Icon Choose…/Image…/Reset round-trips, including the `manageIcon`-backed
   flows (Image…, member Reset) driven from the group widget.
8. Separator label editing plus the tree's separator summary lines.
9. Apply/Cancel staging: Cancel restores the saved group; Apply persists.
10. Import/export round trips: whole group, single stack into a standalone
    widget, and selected-stack export from the group.

Offscreen suites (run from the repo root; the QML module lands in `build/ci/qml`
per the CMake `OUTPUT_DIRECTORY` and `scripts/ci-run.sh`):

```sh
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QML_IMPORT_PATH="$PWD/build/ci/qml" \
    qmltestrunner-qt6 -input tests/stack-group-runtime -o -,txt
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QML_IMPORT_PATH="$PWD/build/ci/qml" \
    qmltestrunner-qt6 -input tests/stack-editor -o -,txt
```

## Step 6 panel polish — first pass

The user reported “looks good” after this increment. Panel sizing/highlighting is
accepted; vertical-panel and screen-edge cases were not separately reported.

Group buttons now follow panel thickness without imposing a minimum thickness.
Icons scale with their buttons up to the theme's large icon size, leaving a small
inset. Surplus layout space no longer stretches individual buttons. The currently
open stack stays highlighted. Popup placement remains owned by Plasma's anchored
dialog; no manual screen coordinates are introduced.

Install with `./install.ps1 -WithGroup`, then check:

1. On your normal panel, compare launcher and stack icon sizes and spacing.
2. Open a stack and switch to another: only the open stack should stay highlighted.
   Dismiss it and confirm the highlight clears (ordinary hover/focus may remain).
3. If convenient, change panel thickness and try a vertical panel. Buttons should
   remain square, with no forced enlargement of the panel or stretched gaps.
4. Open stacks near each screen edge and check popup placement and scrolling.

Configure-selected-item access and any adjustments from this desktop feedback
remain in step 6. These layout changes do not add new saved settings.

## Step 5 desktop test

The user reported that import/export worked well after installing this checkpoint.
This accepts step 5; individual checklist cases were not separately reported.

Install with `./install.ps1 -WithGroup`. Group configuration now offers **Import…**,
**Export group…**, and **Export selected stack…**. Exports include current editor
settings, including unapplied changes.

1. Import an existing standalone Development ZIP. It should append one stack,
   preserving applications, separators, icon overrides and menu settings. Apply
   and compare its popup with the original standalone widget.
2. Export that selected stack and import it into a spare standalone widget.
   Confirm its settings and icons survive; Cancel if you do not want to save it.
3. Export a group containing direct launchers and several source types. Import it
   into a second test group. Check group name, order, stack names, source settings,
   custom images and folder locations. Group import replaces the editor contents.
4. Cancel an import and confirm the previously saved group remains. Repeat and
   Apply, then reopen configuration to check persistence.
5. Check imported folder filters/cascades and Recent results. Folder contents and
   activity history are not in the archive; each source reads the destination machine.

Whole-group archives originally used `TLBStacksGroup` version 1; launcher
appearance overrides now require archive version 2 (configuration version 4). Selected-stack exports remain ordinary version-5
`TLBStacks` archives. A standalone widget rejects whole-group archives. Standard
folder locations relocate through the destination's XDG directories; other absolute
paths remain machine-specific. Managed images and validation limits follow the
[portable profile rules](DEPLOYMENT.md#portable-menu-profiles), including retention
of shared image assets after Cancel. Import does not migrate existing widgets.

Automated checks passed: 38 Python profile tests, 16 navigation/schema checks and
20 offscreen runtime checks. Coverage includes all-source group round trips,
ordering, separators, image deduplication, folder relocation, invalid archive
rejection before image writes, and staged editor updates. The automated checks do not establish real Plasma Apply/Cancel,
file dialogs or popup behavior; retain the checklist above for regression testing. Step-4 Live
Folder cascade/dismissal checks remain pending as well.

## Step 4 desktop test

Install with `./install.ps1 -WithGroup`, then select a stack in group configuration.
The type selector now offers Selected Applications, Application Categories,
Recent / Frequent Applications, and Live Folder.

1. Categories: select one or more categories, Apply, and compare membership with a
   standalone category stack. Desktop actions should appear where applications
   provide them; computed entries must not offer Remove from stack.
2. Activity: create Recent and Frequent stacks with different limits/category
   filters. Switch between them; each should keep its own query/results. Check
   current/all Activities and empty/unavailable history messages.
3. Folder: choose a local test folder, set patterns, and open nested subfolders.
   Check root sizing, Right/Left, Escape, pointer return and outside-click dismissal.
   Only use disposable files to verify root/submenu Move to Trash; confirm in Trash.
4. Change a stack's source and change it back. Its applications, categories, query
   settings and folder selection should survive. Check Cancel versus Apply.
5. Restart Plasma and check all source settings. Verify direct launchers and
   existing Selected Applications stacks still work alongside the new types.

Automated checks passed: native build, 15 navigation/schema checks and 15 offscreen
runtime checks including source-setting retention and real local-folder enumeration.
These do not establish desktop placement, native popup grab behavior, or Activities
service results; the checks above remain pending.

## Step 3 desktop test

Install with `./install.ps1 -WithGroup` (including the rebuilt native module).

1. Keep one direct launcher. Add two stacks, give them distinct names/icons, and
   add different applications to each. Apply and confirm each opens the correct menu.
2. Switch between the stacks by hovering/clicking their panel buttons. Check placement
   beside the clicked button, no clipped contents, and only one group popup at a time.
3. Test Up/Down wrapping, Enter, Escape, outside-click dismissal and focus return.
4. Right-click an app: test an available desktop action and Remove. Remove must affect
   only that stack, not the other stack or a direct launcher for the same app.
5. Reorder group items and stack members. Check Cancel preserves saved state and Apply
   persists it. Restart Plasma; verify both stacks and the launcher survive.
6. Check icons-only mode and hover timing. Empty a stack and confirm its message.
7. Regression-check an existing standalone stack's menu, keyboard controls, tooltips,
   desktop actions and separators: it now uses the shared renderer too.

Runtime smoke tests (requires installed Plasma/Kirigami runtime, separate from minimal CI):

```sh
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QML_IMPORT_PATH="$PWD/build/ci/qml" qmltestrunner-qt6 -input tests/stack-group-runtime -o -,txt
```

These exercise both local and packaged shared-menu navigation and real editor changes,
with simulated application entries. They cannot prove Wayland placement or mouse grabs.
Group schema/migration/isolation tests remain in the CI navigation suite.

## Step 2 desktop test

Install using `./install.ps1 -WithGroup` again. On the existing test group:

1. Search and add three applications. Apply and check the icon order and launching.
2. Reorder and remove an entry. Cancel: panel contents should remain unchanged.
   Repeat and Apply: changes should appear. Search should offer removed apps again.
3. Tab to the group and use arrow keys, Home/End, Enter and Space. Hover should show
   the application name after a pause. Right-click should retain Plasma configuration.
4. Test a second group for independent settings, then restart Plasma and verify order.
5. Remove all entries and Apply. The configurable empty-group button should return.
6. If available, test a vertical panel for column layout and spacing.

No blocking issues were reported for this checkpoint. Step 3 can now begin.

## Step 1 desktop test

Install using the [opt-in command](DEPLOYMENT.md#experimental-stack-group), then:

1. Add **TLBStacks Group** from Plasma's widget chooser. Existing **TLBStacks**
   widgets should behave as before.
2. Click the empty group. Its configuration should open with a name field and an
   explanation that adding items comes in the next steps.
3. Enter a name and Apply. Hover over the panel icon and check the name. Change it
   again and Cancel; the saved name should remain.
4. Add a second group and give it a different name. Check the names are independent.
5. Move the group using Plasma's panel editor. If available, test a vertical panel
   and a desktop instance; check sizing and the empty button's usability.
6. Restart Plasma using your normal install loop. Both names should survive.
7. Remove a test group; existing stacks and the other group should remain intact.

This was the step-1 baseline; step 2 adds applications as described above.

## Current editor polish checkpoint — October 7, 2026

The shared editor is merged on main. Panel right-click editing is dropped for now;
leave its stash untouched. The accepted editor polish supersedes earlier
resume instructions to restore the right-click handoff. See
[Configuration design](CONFIGURATION_DESIGN.md#current-status--october-7-2026).

Desktop checks: shrink the window on Categories/Recent/Live Folder and scroll to
the last controls; type 50 into hover delay and check Apply immediately; choose a
custom image through both Choose/Browse and Image; verify errors appear on Contents;
check tree icons, chip contrast, and both Export menu choices. Regression checks
cover live typing, scroll reachability and member-icon error visibility.

Desktop feedback confirmed that category scrolling reaches the final chips and
matching applications, with tabs and dialog actions remaining visible. The user
reports the editor is working well. The remaining Recent-options polish now uses
a compact left-aligned grid (stacked labels only at narrow widths), replacing the
centered form. The user confirmed this last visual adjustment looks good. The editor-polish
checkpoint is accepted; individual optional checks above were not all separately
reported. Validation: native build, 46 editor checks, 25 group runtime checks, and
38 profile tests passed. Direct-launcher Appearance remains the next separate
feature; panel right-click editing remains dropped.

## Direct-launcher Appearance

Select a direct launcher in group settings to set its Label, Choose an icon, or
select an Image. Empty label/icon values follow the application's defaults; Reset
appearance clears both overrides. Replacing the application preserves explicit
overrides. Image selections use shared managed storage. The panel uses the normal
application icon if an override is unavailable. Application activation still uses
the desktop ID, with no command or argument changes.

Overrides require group configuration version 4 and group ZIP version 2. Older
versions are still accepted; groups without overrides retain their older versions.
Individual-stack exports remain unchanged. Icons share the existing archive limits,
checksum validation and deduplication.

Test a custom label and image on a launcher; Apply, reopen settings, and inspect the
panel tooltip. Check Cancel and Reset, then export/import the entire group into a
second widget. Existing stacks and launchers without overrides should retain their
appearance. These checks remain a regression checklist.

Launcher Appearance validation: 41 profile tests, 26 group runtime checks, 18
navigation/schema checks and 7 icon fallback checks passed. The user accepted
the feature and explicitly confirmed Reset on October 7, 2026. Individual archive
and Cancel checks were not separately reported. Related-icon search is not planned;
the user prefers the current Choose / Image / Reset controls.
