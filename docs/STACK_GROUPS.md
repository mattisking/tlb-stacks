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

**Steps 1–2 accepted for progression; step 3 is next.**

The user reported “looks good. Works. icons all work.” after installing step 2.
This confirms the reported launcher/icon behavior; it does not independently
certify every optional orientation and keyboard check below.

- Package: `package-group`, ID `com.mattphilmon.tlbstacks.group`.
- Settings: `General/groupName` and `General/items`. Each instance has independent
  Plasma configuration. `items` is JSON `{version: 1, items: [...]}`; each current
  entry has `id`, `type: "application"`, and `desktopId`. IDs survive reordering.
- The editor stages all edits in cfg properties. The panel only reads saved
  settings; Apply/Cancel remains managed by Plasma. Future/invalid item formats
  are reported and not replaced with an empty list by the editor.
- Search/add uses the existing Launcher catalog; direct activation uses its KDE
  launch API. Missing installed apps keep their entry and report launch failure.
- Panel orientation determines row/column layout. Arrow keys wrap between buttons;
  Home/End select endpoints; Enter/Space activate. Tooltips delay 700 ms.
- Duplicate application selection is blocked for now. IDs are separate from desktop
  IDs so F-009 can introduce distinct launch variants later without replacing identity.
- No contained stacks, custom commands or group import/export yet. Next is step 3:
  reuse Selected Applications rendering inside a group, with list/detail editing.
- Developer installation stays opt-in via `-WithGroup`; normal releases exclude it.

Validation: group entry tests run in the existing CI navigation suite. Static QML
checks cannot resolve the manually registered Launcher type or Plasma's `i18n`.
The user has accepted the launcher checkpoint. Keep the detailed checks below for
regression testing; orientation, restart persistence and individual keyboard cases
were not separately reported.

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
