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

**Step 6 panel sizing/highlighting accepted; configure-selected-item access is next.**

The user reported “looks good. Works. icons all work.” after installing step 2.
This confirms the reported launcher/icon behavior; it does not independently
certify every optional orientation and keyboard check below.

- Package: `package-group`, ID `com.mattphilmon.tlbstacks.group`.
- Settings: `General/groupName` and `General/items`. Each instance has independent
  Plasma configuration. `items` is JSON `{version, items: [...]}`. Launcher-only groups retain version 1;
  Selected Applications stacks use version 2, and groups with Categories, Activity
  or Live Folder use version 3. Versions 1–3 read here; older widgets reject
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
- The list/detail editor adds stacks, names/icons, icons-only mode, size, hover delay,
  application membership and ordering. Separators can be appended, labeled, reordered and removed with stack members.
  Per-application custom icon editing is not yet exposed in this group editor.
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

Whole-group archives use `TLBStacksGroup` format version 1, independently of the
version 1–3 configuration schema. Selected-stack exports remain ordinary version-5
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
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QML_IMPORT_PATH="$PWD/build/qml" qmltestrunner-qt6 -input tests/stack-group-runtime -o -,txt
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
