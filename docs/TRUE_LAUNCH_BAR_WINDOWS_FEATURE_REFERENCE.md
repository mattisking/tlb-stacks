# Original True Launch Bar for Windows — historical feature reference

[Project guide](README.md) · [Feature tracker](FEATURE_TRACKER.md)


**Draft:** 0.2 · **Research date:** October 2, 2026 · **Status:** for review, not an implementation specification

## 1. Purpose and boundaries

This document reconstructs the user-facing capabilities of **TORDEX True Launch Bar (TLB) for Windows**. It is a reference for remembering and discussing the original product before making decisions about our Linux project.

It does not propose a Linux architecture, promise feature parity, or prioritize implementation. A feature's inclusion means there is historical evidence for it, not that it should be recreated.

The two supplied AI drafts were used as research checklists, not as authoritative documentation:

- `true_launch_bar_spec.md` — “Core Feature & Architecture Specification.”
- `true_launch_bar_spec (1).md` — “Deep Functional & Architectural Specification.”

Both describe recognizable capabilities but blend them with unverified implementation explanations. Section 13 records the important corrections.

### Evidence labels

- **Confirmed:** explicitly described in an official product page, vendor FAQ, release note, or published repository.
- **Version-specific:** confirmed for the cited release or mode; not necessarily universal.
- **Secondary-confirmed:** described in a contemporary independent review; vendor corroboration remains desirable.
- **Unverified:** plausible, remembered, or present in an input draft, but not adequately established here.
- **Interpretation:** an explanation connecting documented facts, rather than a claim made by the source.

Unless marked otherwise, the feature inventories below are **confirmed**. Sources follow each small group. Dates attached to releases establish that a feature existed by then; they do not necessarily identify its first implementation.

### Source availability and limitations

Some official pages and search-indexed copies were accessible during this research. Others timed out or were unavailable. Consequently, “the whole site is gone” is too strong; dependable access is incomplete. Surviving pages also contain stale text and mixed-era information.

The user supplied the complete 68-page *True Launch Bar User’s Manual*. All pages were reviewed through text extraction, with visual checks of the filtering and version screenshots. Manual citations below use printed page numbers, which match PDF page numbers. The About screenshot on p. 49 shows **v3.2.13 RC1** and copyright **2000–06**. This identifies the pictured build, not a proven publication date or a guarantee that every screenshot uses that build. The PDF export timestamp is not the manual's historical publication date.

**Manual source (M):** [True Launch Bar User's Manual.pdf](<True Launch Bar User's Manual.pdf>) (retained with these docs; originally supplied from Downloads). References such as **[M, pp. 18–20]** refer to this supplied PDF. The online [Yumpu listing](https://www.yumpu.com/en/document/view/6132073/true-launch-bar-users-manual) remains a recovery lead; the local PDF is the source actually reviewed. It does not cover the full later history, so the release-note evidence below remains necessary. No historical Windows binary was executed.

**Changes in draft 0.2:** confirmed sorting fields, keyboard selection, profiles, filtering behavior, backup contents, drag/drop distinctions, appearance controls, and recent/frequent menus; added manual-specific limitations and inconsistencies. This revises the earlier draft's uncertainty rather than treating all earlier omissions as absent features.

## 2. Product identity and historical scope

TLB extended the Windows Quick Launch model into a configurable toolbar containing launchers, nested menus, and applets. Its integrated form lived on the taskbar; a separate standalone host supported independent screen-edge bars. Multiple toolbars were possible, with their own backing folders. The default toolbar reused Quick Launch's shortcut location. [Product overview](https://www.truelaunchbar.com/), [initial setup FAQ](https://www.truelaunchbar.com/faq/installation/i-just-installed-true-launch-bar.-what-do-i-do-next.html)

| Historical marker | What the evidence establishes |
|---|---|
| March 2001, 1.0.9/1.0.10 | Hover-open menus, hotkeys, separators, virtual folders, scrolling, and multiple-monitor support already existed. |
| June 2001, 1.1 betas | Plugin engine and early mail/shutdown buttons. |
| October 2014, 7.0 | Portable standalone mode and interactive tooltip improvements were promoted together. |
| February 2015, 7.1.1 beta | Release notes explicitly add portable use in the taskbar. |
| 2016–2021 | Jump Lists and progressive per-monitor/HiDPI improvements. |
| December 1, 2022, 8.0 | Vendor announces the product is free. |

Sources: [early history](https://www.truelaunchbar.com/history.html?page=15), [7.0 announcement](https://www.truelaunchbar.com/announces/true-launch-bar-v7.0.html), [2014–2015 history](https://www.truelaunchbar.com/history.html?page=2), [later history](https://www.truelaunchbar.com/history.html).

**Important distinction:** freeware distribution of the application and publication of SDK/plugin source are separate facts. Neither establishes publication of the main application's source code.

## 3. Toolbars, items, and organization

### 3.1 Basic user model

| ID | Capability | Historical behavior |
|---|---|---|
| ORG-01 | Direct launchers | Keep individual application/file shortcuts directly on a toolbar. |
| ORG-02 | Menu buttons | Put related launchers in popup menus, including nested submenus. |
| ORG-03 | Multiple toolbars | Create additional toolbars from new or existing folders. |
| ORG-04 | Toolbar switching | Switch between named shortcut collections. |
| ORG-05 | Optional toolbar title | Show or hide the toolbar's title. |
| ORG-06 | Drag-and-drop editing | Add and rearrange shortcuts through the toolbar/menu UI. |
| ORG-07 | Keyboard shortcuts | Assign hotkeys to launchers and menus. |

Sources: [overview](https://www.truelaunchbar.com/), [setup FAQ](https://www.truelaunchbar.com/faq/installation/i-just-installed-true-launch-bar.-what-do-i-do-next.html), [2001 history](https://www.truelaunchbar.com/history.html?page=14).

### 3.2 Groups within a menu

| ID | Capability | Historical behavior |
|---|---|---|
| ORG-08 | Separators and headings | Lines and titled separators divide a toolbar or menu into sections. |
| ORG-09 | Collapsible groups | Expand/collapse the items associated with a separator. |
| ORG-10 | Group launch | A separator's run-all control launches the group's items. |
| ORG-11 | Group-aware sorting | Sorting can operate between separators/titles. |
| ORG-12 | Expand/collapse all | Later releases provide a command and keyboard shortcuts for all separator groups. |
| ORG-13 | Spacers | Optional Spacer plugin inserts adjustable empty space or a picture separator. |

Sources: [2002 history](https://www.truelaunchbar.com/history.html?page=13), [5.6-era history](https://www.truelaunchbar.com/history.html?page=4), [Spacer plugin](https://www.truelaunchbar.com/plugins/spacer.html).

The vendor describes separator operations as applying to following items until the next separator or the menu's end. These are groups inside a menu, distinct from nested folders. [Feature reference](https://www.truelaunchbar.com/features.html)

### 3.3 Item management

- Hide/unhide buttons without deleting them; lock buttons against movement.
- Rename items in place, documented in the 4.4.11 beta.
- Manually reorder virtual-folder items, including inserting separators.
- Sort virtual-folder contents by name, type, or size; later releases add natural ordering for numbered names.
- Place folders after files where the relevant arrangement option is enabled.
- Selectively load virtual folders at startup instead of waiting for use.

Sources: [early releases](https://www.truelaunchbar.com/history.html?page=15), [2001 additions](https://www.truelaunchbar.com/history.html?page=14), [5.2 history](https://www.truelaunchbar.com/history.html?page=5), [5.5 history](https://www.truelaunchbar.com/history.html?page=4), [3.2 history](https://www.truelaunchbar.com/history.html?page=10).

**Manual clarification:** sorting supports name, type, size, creation date, modification date, last-run time, and run count. Name breaks ties. Folders sort alphabetically at the top by default; “Apply to Folders” extends the selected sorting rule to folders, and descending order reverses it. Auto-arrange applies the rule to new items and can prevent manual reordering. The hidden ordering-index algorithm remains unverified. [M, pp. 14–15, 51, 67]

## 4. Virtual folders and dynamic content

A virtual folder exposes an existing location as menu contents rather than requiring a separately created shortcut for every item. Local and network locations were supported, alongside Windows shell locations such as Control Panel, Printers, Computer, and network/dial-up connections. This was more than a conventional directory browser. [Overview](https://www.truelaunchbar.com/), [early virtual-folder release](https://www.truelaunchbar.com/history.html?page=15)

| ID | Capability | Scope or qualification |
|---|---|---|
| VF-01 | Directory-backed contents | Present the items in a selected existing folder. |
| VF-02 | Nested virtual folders | Create virtual folders inside other virtual folders. |
| VF-03 | Expanded folder shortcuts | A folder shortcut can expand into a menu. |
| VF-04 | Optional subfolder expansion | Control whether subfolders expand. |
| VF-05 | Change tracking | Contents can reflect filesystem changes; background loading was also documented. |
| VF-06 | Shell context actions | Operations on represented files/objects, rather than merely launching a copied shortcut. |
| VF-07 | File masks and dates | Include/exclude masks, recent creation/modification filters, and continuing versus one-time filtering; detailed grammar remains unverified. |
| VF-08 | Hidden items | Settings govern display of hidden files. |
| VF-09 | Combined Start Menu content | Merge user and common/all-users Start Menu items. |
| VF-10 | Explorer search results | Add Windows Explorer search results as a virtual folder, documented in 6.6.2 beta. |

Sources: [2004 history](https://www.truelaunchbar.com/history.html?page=10), [2001 change tracking/background loading](https://www.truelaunchbar.com/history.html?page=14), [5.6.3 Start Menu merging](https://www.truelaunchbar.com/history.html?page=4), [6.6.2 search-results support](https://www.truelaunchbar.com/history.html?page=3), [vendor feature reference](https://www.truelaunchbar.com/features.html), [contemporary feature listing](https://www.softpedia.com/get/System/OS-Enhancements/True-Launch-Bar.shtml).

**Interpretation:** this gives three distinct sources of “dynamic” content: a real folder, a Windows shell namespace, and a shell search-result view. It does not establish an independent TLB database query language or a user-defined tag engine.

**Boundary to investigate:** change notification behavior for remote shares, disconnected drives, and individual shell extensions. Historical fixes show these cases were not uniformly reliable. “Everything updates instantly in every circumstance” is not a defensible specification.

### 4.1 Filtering and loading details from the manual

- Include and exclude filename masks are separate controls. Date filters select files created or modified within a given number of days. The dialog includes a folder-processing control; its complete choice list and wildcard grammar are not documented in the retrieved text. [M, p. 18]
- **Continuing filtering** applies to newly arriving files/folders. **One-time filtering** hides current nonmatching entries and leaves future entries unfiltered. The manual calls this a “Hidden” attribute, but does not establish whether it means a Windows filesystem attribute or TLB's internal hidden state; that implementation detail remains unresolved. [M, pp. 18–19]
- Ordinary menus load at startup; virtual-folder contents normally load on first access. “Load on Startup” changes this, while background loading allows continued interaction during enumeration. Virtual-folder hotkeys may be unavailable until their items have loaded. [M, pp. 10, 21, 67]
- Shell-exposed archives, such as ZIP folders, can expand as menus. An extension list can force selected types to remain files instead; the manual illustrates semicolon-separated `.zip;.cab`. This syntax is for archive handling, not proof of the mask syntax above. [M, p. 30]
- Deleting the virtual-folder button leaves its target directory intact; deleting an item **inside** that menu removes the actual represented file/folder. Hiding is a separate operation. [M, pp. 9–10, 52]

## 5. Mouse, keyboard, drag-and-drop, and launch actions

### 5.1 Activation and dismissal

| ID | Capability | Historical behavior |
|---|---|---|
| INPUT-01 | Hover-open menus | Open a menu by pointing at its button; the feature could be disabled. |
| INPUT-02 | Adjustable timing | Configurable mouse-hover timing and a separate submenu-open delay existed. |
| INPUT-03 | Hover-to-run | Optionally execute a launcher by hovering, distinct from opening its menu. |
| INPUT-04 | Per-item hover execution | Later versions allow enabling/disabling hover execution for individual buttons. |
| INPUT-05 | Auto-close on leaving | Mouse-leave menu closure was an option. |
| INPUT-06 | First-level menu switching | Mouse options included automatically opening adjacent first-level menus. |
| INPUT-07 | Keyboard traversal | Navigate with keys; accelerators and adjacent-menu navigation were added over time. |
| INPUT-08 | Menu hotkey toggle | A second press can close an opened menu; focus restoration was documented. |
| INPUT-09 | Open the represented folder | Double-clicking a menu could open its folder. |

Sources: [early hover support](https://www.truelaunchbar.com/history.html?page=15), [2004 mouse/keyboard changes](https://www.truelaunchbar.com/history.html?page=10), [per-item hover execution](https://www.truelaunchbar.com/announces/true-launch-bar-v7.0.html), [contemporary review of mouse options](https://www.softpedia.com/reviews/windows/True-Launch-Bar-Review-466973.shtml).

**Modifier-key nuance:** the later feature page names Ctrl as a temporary blocker for hover execution. The 2001 history records a change from Ctrl to Shift. Therefore a suppression key is real, but one universal key, configurable Ctrl/Shift/Alt interception, or a single implementation across all versions is not established. The documented action is suppression of hover **execution**, not proof that every hover-opening mechanism was suppressed. [Features](https://www.truelaunchbar.com/features.html), [2001 history](https://www.truelaunchbar.com/history.html?page=14)

### 5.2 Drag-and-drop

- Add shortcuts and other shell objects through drag-and-drop.
- Right-button dragging offers a choice of operations on drop.
- Drag files out of virtual folders; manually rearrange their contents.
- Scroll menus during dragging. Later bug fixes corroborate opening submenus during an active drag.
- Drag browser URLs to a toolbar.
- Later releases allow a drag over an auto-hide tag to reveal its toolbar/menu.

Sources: [2001 history](https://www.truelaunchbar.com/history.html?page=14), [early right-drag support](https://www.truelaunchbar.com/history.html?page=15), [5.1 drag fixes](https://www.truelaunchbar.com/history.html?page=5), [7.5 tag behavior](https://www.truelaunchbar.com/history.html).

The manual supplies more precise drop semantics. For insertion into the toolbar, Shift moves the file/folder, Ctrl copies it, and Alt creates a shortcut. A right-drag menu offers those operations plus “Create Menu Here” for folders. Dropping onto an application button without an insertion marker passes the file to that application; dropping onto a folder target copies/moves it there. Thus placement and destination matter. Creating text scraps from arbitrary dragged text remains unverified. [M, pp. 6, 8]

### 5.3 Timing and keyboard details

The manual distinguishes timeout controls for initial hover opening, switching between first-level menus, hover execution, mouse-leave closing, and an optional custom submenu delay. Auto-close can treat either the menu alone or the menu plus toolbar as the safe pointer area. A separate setting controls what happens when the pointer moves to a non-menu toolbar button. These are distinct interactions, not one global delay. Numeric defaults remain unverified. [M, pp. 35–36]

Keyboard navigation includes Up/Down, Right to open a submenu, Enter to launch/open, Escape to close, and Ctrl+Left/Right to move between toolbar menus. Typing the first letters selects an item and opens it if it is a menu. Names can contain ampersand-defined Alt accelerators. Hotkeys accept the Windows key and can also omit modifiers. A central list edits/clears hotkeys or reveals their associated menu. [M, pp. 21, 46, 62]

Click and Enter can independently be configured to open a submenu's folder in Explorer while hover/Right still expands it. StartKiller integration redirects the Windows key to the first toolbar menu when configured. [M, pp. 21, 28–29]

### 5.4 More than a default launch

- Related links associate extra destinations or actions with a button.
- Later related links support shell verbs and command-line parameters, and can appear in interactive tooltips.
- A button's default shell command can be changed.
- Later releases offer middle-click opening of a file's location and Windows Jump List support.

Sources: [7.0 related-link details](https://www.truelaunchbar.com/announces/true-launch-bar-v7.0.html), [default commands](https://www.truelaunchbar.com/features.html), [later history](https://www.truelaunchbar.com/history.html).

## 6. Menu layouts, size, and positioning

| ID | Capability | Historical behavior |
|---|---|---|
| VIEW-01 | Text and icon presentations | Menus support icon-oriented layouts, labels, and a no-icons mode. |
| VIEW-02 | Mixed item presentation | Standard rows and icon-view items can coexist. |
| VIEW-03 | Multi-column layouts | Columns and separator-driven column breaks. |
| VIEW-04 | Size limits | Menu maximum dimensions; later minimum dimensions as well. |
| VIEW-05 | Scrolling | Long menus scroll rather than requiring unlimited height. |
| VIEW-06 | Alignment/anchor controls | Menu alignment and docking-point settings extend to submenus. |
| VIEW-07 | Caption controls | Optional captions and caption action buttons. |
| VIEW-08 | Label wrapping | Multiple-line names, with limits on text rows. |
| VIEW-09 | Overflow menu | Excess toolbar items are accessible through a “more” button/menu. |
| VIEW-10 | Image thumbnails | Browse image folders using miniature previews. |
| VIEW-11 | Multi-monitor behavior | Monitor-aware menus and later per-monitor DPI handling. |

Sources: [5.5–6.4 layout history](https://www.truelaunchbar.com/history.html?page=4), [4.4-era positioning and captions](https://www.truelaunchbar.com/history.html?page=6), [7.0 overflow/wrapping](https://www.truelaunchbar.com/announces/true-launch-bar-v7.0.html), [image previews](https://www.truelaunchbar.com/), [DPI history](https://www.truelaunchbar.com/history.html).

**Known limitation:** separator column breaks were documented for the default view, with scrolling able to disrupt that column arrangement. Do not translate the drafts' example of “20 items creates exactly three columns” into a confirmed universal layout algorithm. [Feature reference](https://www.truelaunchbar.com/features.html)

### 6.1 Four documented view modes

| Mode | Manual description |
|---|---|
| Default | Fill down a column before moving right; omit unnecessary columns; scroll when needed. |
| Icons only | Fill left-to-right, then downward, retaining the configured column count. |
| Icons with text | Same grid ordering, with labels beneath icons. |
| Multicolumn text | Prefer distributing entries across columns; one configured column behaves like Default. |

These describe mode-specific layout rules, not a universal fixed item-count formula. Menus can also use thumbnails or no icons. Custom square sizes are supported, with scaling quality dependent on source imagery. [M, pp. 12–14, 41]

Submenus initially inherit parent settings. Individual edits interrupt that default inheritance; an overwrite option can propagate settings again. Per-menu limits, captions, tips, docking points, and alignment are configurable. [M, pp. 15–16]

Scrolling can use edge scrollers, a scrollbar, or both, with step size and interval controls. Toolbar controls include equal-width text buttons, alignment, minimum button capacity, multiple rows, and sizing increments. Menu metrics include width/height limits, margins, label-width caps, and icon-grid margins. Captions can show counts including hidden items, change direction, and expand the menu to avoid truncation. [M, pp. 23–29, 39–40]

## 7. Persistent menus, docking, and contextual toolbars

### 7.1 Tear-off and docked menus

Tear-off menus could remain on the desktop instead of disappearing after ordinary popup use. Later controls include pinning, always-on-top behavior, restoring a standard position, caption visibility, and automatic opening at startup. Docked tear-off menus add edge placement, auto-hide, and adjustable activation hotspots. [5.5–6.0 history](https://www.truelaunchbar.com/history.html?page=4), [4.2.3 history](https://www.truelaunchbar.com/history.html?page=7), [6.5–6.6 history](https://www.truelaunchbar.com/history.html?page=3)

### 7.2 Standalone bars and tags

Standalone bars could dock to display edges. Later releases remembered size/position by edge and display, supported optional display over fullscreen applications, and exposed colored activation tags for hidden bars/menus. Tags could activate on hover. Here **tag means a visible activation tab**, not application metadata. [7.0 announcement](https://www.truelaunchbar.com/announces/true-launch-bar-v7.0.html)

### 7.3 Auto-sensing workspaces

A toolbar could select a different shortcut collection according to the active or running application. A common-program list avoided unwanted switching; unmatched applications fell back to the main collection. This was contextual toolbar switching, distinct from the Virtual Desktop plugin. [Feature reference](https://www.truelaunchbar.com/features.html)

### 7.4 Settings profiles

**Confirmed by the manual:** named profiles save or overwrite current settings, can be deleted, and apply immediately when selected. Their stated purpose is switching settings and transferring identical settings between toolbars. They are distinct from a toolbar's content folder and from a complete backup. The exhaustive list of fields captured by a profile is not given. [M, pp. 19–20]

Auto-sensing workspaces also support manual hotkey activation with a timeout to return to the regular toolbar. Each application rule can trigger on launch or on an active window, and common applications preserve the current workspace. [M, pp. 42–45]

## 8. Appearance and information display

### 8.1 Icons and imagery

- Custom icons, reusable icon libraries, and resetting an overridden icon.
- PNG icon support and storing custom icons/overlays with the toolbar.
- Three-state button images for normal, highlighted, and pressed appearances.
- JPEG/GIF icon support added in 4.2.1 beta.
- Per-item background colors; configurable fonts, margins, and menu overlays across releases.

Sources: [2003–2004 image changes](https://www.truelaunchbar.com/history.html?page=10), [JPEG/GIF support](https://www.truelaunchbar.com/history.html?page=7), [item backgrounds](https://www.truelaunchbar.com/history.html?page=2), [font/margin controls](https://www.truelaunchbar.com/history.html?page=4).

The older history mentions `.icl` libraries and icon problems involving `shell32.dll`. Those establish use of icon libraries and Windows resources, not the drafts' exact extraction pipeline. [2001 history](https://www.truelaunchbar.com/history.html?page=14), [2004 history](https://www.truelaunchbar.com/history.html?page=10)

The manual confirms selecting icons from files or folders in ICO, ICL, DLL, EXE, CPL, BMP, PNG, GIF, and JPEG formats. Frequently used sources can be bookmarked as icon libraries; a Saved Icons collection exposes bundled assets. The chooser's preview size does not determine the rendered button size. [M, pp. 53–54]

Button properties can be edited in groups and override labels, right-aligned supplementary text, icon size, icon/text visibility, alignment, bold/italic, text color, shell command, context menu, and hidden state. A custom three-state button image overrides ordinary styling and text labels; this is an optional appearance mode, not a requirement on every plugin. [M, pp. 56–58]

### 8.2 Skins, transparency, and animation

Skins and Windows visual-style integration changed the toolbar/menu appearance. Aero-style glass depended on the Windows version and environment; later standalone rendering offered transparent backgrounds with opaque content. Menu opening/closing effects and selectable animation speed versus duration were documented. [Overview](https://www.truelaunchbar.com/), [6.3 effects](https://www.truelaunchbar.com/history.html?page=4), [6.5–6.6 rendering changes](https://www.truelaunchbar.com/history.html?page=3)

The manual additionally documents separate menu, toolbar, and tooltip transparency; independently targeted toolbar/menu skins; colors and gradients for selection, captions, backgrounds, and separators; and distinct fonts for items, captions, and headings. Overlay images support positioning, stretching, aspect preservation, and toolbar tiling. [M, pp. 17–18, 24, 30–34]

### 8.3 Tooltips

Tooltips evolved from editable descriptions to HTML-rich, scrollable content. Later versions added CSS styling, interactive links, multiple style sheets, and HTML-file tooltip content. Shell-standard tooltips were also an option. These informational surfaces were not necessarily separate plugin dashboards. [Tooltip evolution](https://www.truelaunchbar.com/history.html?page=3), [interactive tooltip release notes](https://www.truelaunchbar.com/history.html?page=2)

The manual-era tooltip system has configurable shapes, appearance delay, lifetime, width, icons, last-run time, and run count. Caption and description can each be default, custom, or hidden. Its formatting vocabulary includes basic HTML-like tags plus custom alignment/color/tab commands; this should not be mistaken for an unrestricted browser engine. Related links can be imported/exported. [M, pp. 38–39, 54–56]

## 9. Saved state, transfer, and administrative controls

### 9.1 What is actually documented about storage

The toolbar folder is central, but it is not safe to equate the entire product with a directory of plain shortcuts. The transfer FAQ separately identifies global settings, default/custom toolbar directories, and installed skins. Plugin instances have their own saved files. [Transfer FAQ](https://www.truelaunchbar.com/faq/installation/how-can-i-transfer-my-true-launch-bar-settings-to-a-new-computer.html), [plugin storage FAQ](https://www.truelaunchbar.com/faq/true-launch-bar-technical/where-plugins-save-the-data.html)

| Component | Confirmed historical storage/transfer behavior |
|---|---|
| Global settings | Vendor identifies an AppData/Roaming/Tordex/True Launch Bar directory. |
| Default toolbar | Vendor identifies the user's Microsoft/Internet Explorer/Quick Launch directory. |
| Additional toolbars | Their chosen folders must also be transferred. |
| Skins | Installed skins may live under the application installation folder. |
| Plugin instances | `.tlbplugin` files in toolbar folders can be copied/moved to reproduce settings. |
| Backup/restore | A wizard transfers a toolbar using a saved backup file. TLB and required plugins must be installed on the destination. |

Sources: [transfer instructions](https://www.truelaunchbar.com/faq/installation/how-can-i-transfer-my-true-launch-bar-settings-to-a-new-computer.html), [plugin-instance files](https://www.truelaunchbar.com/faq/true-launch-bar-technical/where-plugins-save-the-data.html).

The vendor also documents specific metadata files. These describe the FAQ's historical implementation, without establishing that every release used identical formats:

| File | Documented role |
|---|---|
| `tlbdata.xml` | Item positions, separators, and menu options in toolbar subfolders. |
| `setup.ini` | Toolbar settings at the root; menu icon locations in subfolders. Refresh rereads these files. |
| `namespace.fld` | A Windows shortcut representing the target of a virtual folder. |

Sources: [layout metadata FAQ](https://www.truelaunchbar.com/faq/true-launch-bar-technical/what-is-the-tlbdata.xml-files.html), [settings metadata FAQ](https://www.truelaunchbar.com/faq/true-launch-bar-technical/what-is-the-setup.ini-files.html), [virtual-folder metadata FAQ](https://www.truelaunchbar.com/faq/true-launch-bar-technical/what-is-the-namespace.fld-file.html).

Ordinary folders and shortcuts could also be added through a file manager: TLB displayed them as menus and launchers. Choosing a shared toolbar directory was explicitly supported. The backup FAQ describes saving the toolbar folder's contents, while the configuration-location FAQ cautions that hidden files are part of the configuration. [Toolbar folder FAQ](https://www.truelaunchbar.com/faq/true-launch-bar-technical/what-is-the-toolbar-folder.html), [backup FAQ](https://www.truelaunchbar.com/faq/true-launch-bar-technical/what-is-the-toolbar-backup-file.html), [configuration locations](https://www.truelaunchbar.com/faq/true-launch-bar-technical/location-of-tlb-configurations.html).

Your memory of carrying a configured toolbar and its custom icons between computers is consistent with the documentation. **The exact ZIP internals, registry payload, and `%TLB_DRIVE%` macro described by the AI drafts are not verified.** File formats also changed over time. [Image bundling and backup-format change](https://www.truelaunchbar.com/history.html?page=10)

The manual identifies **`.tlbbackup`** as the backup extension. It includes toolbar objects and settings **but excludes the contents of virtual folders**. Custom icons/overlays enter the backup when saved with the toolbar; restoring replaces current toolbar contents rather than merging. The extension does not establish a ZIP container or registry payload. [M, p. 20]

Saving an icon with the toolbar copies its file into the toolbar folder, with rename/overwrite handling on filename collisions. A global setting makes bundling the default. This directly corroborates the remembered transportable icon collection. Removing a toolbar from the configured toolbar list, by contrast, leaves its backing files intact. [M, pp. 22, 45–46, 53–54]

### 9.2 Protection and maintenance

Button passwords, locking, and hiding existed; setup protection was also advertised. These were application controls, not a claim of strong file encryption. A Components Manager handled updates/components, and a reset/cleanup utility was documented. Context-menu templates could differ for buttons, virtual folders, plugins, and empty menu space. [Protection](https://www.truelaunchbar.com/history.html?page=14), [setup protection and templates](https://www.truelaunchbar.com/features.html), [maintenance tools](https://www.truelaunchbar.com/history.html?page=10)

The manual distinguishes protection against execution, hide/unhide, deletion/renaming, and property changes, and explicitly describes it as weak protection. Locking can be scoped to a menu or the entire toolbar hierarchy and can require the settings password. [M, pp. 20–21, 58–59]

Components Manager could install/remove components, select stable or latest updates, ignore individual components, configure proxy access, and manage downloaded files. A system-information page listed plugin versions and prepared a support email. The manual also documents the then-commercial registration interface; this predates the later freeware release. [M, pp. 47–48, 62–66]

## 10. Plugins: the recoverable catalog

Plugins extended the product beyond launchers. The vendor catalog and download page list the following **43 named plugins**. Descriptions here are deliberately compact; availability in a catalog does not mean an old online service or binary still works. [Plugin catalog](https://www.truelaunchbar.com/plugins/index.html), [download inventory](https://www.truelaunchbar.com/download.html)

| Plugin | Function |
|---|---|
| Add or Remove Programs | Installed-program menu |
| Address Book | Contacts |
| Batch Run | Multi-item launch |
| Battery Monitor | Battery status |
| Calculator | Calculation |
| Calendar | Events/reminders |
| CD Control | Disc eject/load |
| Clipboard Manager | Clipboard history |
| Color Picker | Cursor color sampling |
| Command Line | Commands/aliases/search |
| Core Temp | External sensor readouts |
| Delicious Menu | Service bookmarks |
| Device Manager | Hardware controls |
| Display Mode | Resolution switching |
| Drive Space | Storage monitoring |
| Key State | Lock-key indicators |
| Mail Monitor | Mail checks |
| Make Screenshot | Screen capture |
| Media Control | Player controls |
| Moon Monitor | Moon phases |
| Net Monitor | Network statistics |
| News Reader | Feed menus |
| Port Monitor | TCP/UDP connections |
| Process Viewer | Process management |
| Real IP | External address |
| Select Color Tool | Color selection |
| Service Manager | Service controls |
| Slide Show | Photo slideshow |
| Spacer | Adjustable spacing |
| Startup Manager | Startup entries |
| System Monitor | Resource monitoring |
| Timer | Timers |
| TLB Clock | Clock/time zones |
| ToDo List | Tasks/notes |
| Turn Off Computer | Shutdown |
| UpTime | Uptime |
| Virtual Desktop | Desktop switching |
| Voice Notes | Audio notes |
| Volume Control | Audio levels |
| Web Scraper | Webpage fragment display |
| Windows List | Window switching |
| Windows Messenger | Messenger contacts |
| Wireless Monitor | Wireless status |

**Additional historical plugin:** Weather Forecast is explicitly mentioned in the vendor's news, including version 6.7 in January 2019, although absent from the retrieved 43-entry catalog. Its existence is confirmed; a universal seven-day dashboard specification is not. [Vendor news](https://www.truelaunchbar.com/)

### Selected details that distinguish the plugin system

- **Net Monitor:** per-connection traffic totals/rates, connection information, graphs, sounds, and skins. The retrieved documentation does not establish the drafts' claimed per-process bandwidth map. [Net Monitor](https://www.truelaunchbar.com/plugins/netmon.php)
- **System Monitor:** resource displays could incorporate data from CoreTemp, GPU-Z, or Open Hardware Monitor. Sensor data did not necessarily originate inside TLB. [System Monitor](https://www.truelaunchbar.com/plugins/sysmon.php)
- **Mail Monitor:** beyond a mail indicator, its history describes message lists, filtering, reply-related controls, and account-specific checks. Exact supported providers/protocols need version-specific checking. [Mail Monitor](https://www.truelaunchbar.com/plugins/mailmon.html)
- **Make Screenshot:** multiple capture modes, cursor options, clipboard output, and a simple markup tool are documented. [Make Screenshot](https://www.truelaunchbar.com/plugins/screenshot.php)
- **Spacer:** adjustable empty space and picture separators were delivered as a plugin. Do not silently classify them as a mandatory built-in item type. [Spacer](https://www.truelaunchbar.com/plugins/spacer.html)

## 11. Published source, SDK, and application boundary

The inspected [True Launch Bar GitHub organization](https://github.com/truelaunchbar) lists two public repositories:

1. [tlb-pdk-public](https://github.com/truelaunchbar/tlb-pdk-public): Plugins Development Kit.
2. [abook](https://github.com/truelaunchbar/abook): Address Book plugin source.

No main-application repository was found in that organization. This is a scoped observation, not proof that no copy exists elsewhere. The author's reason for publishing these components but not the core is unknown.

The PDK README describes a low-level API, a C++ wrapper, and optional helpers for drawing, images, networking, skins, and UI construction. It identifies Visual Studio 2013 as the build environment. The Address Book README explicitly depends on the PDK. These are useful implementation references for **plugins**, not evidence for the closed application's complete storage or event-handling architecture. [PDK README](https://github.com/truelaunchbar/tlb-pdk-public), [Address Book README](https://github.com/truelaunchbar/abook)

**Licensing qualification:** the organization describes its repositories as open source, but this pass has not completed a file-by-file license audit. Public source visibility alone is not a sufficient basis for deciding what code can be incorporated into another project.

**Plugin presentation qualification:** evidence supports applet-like buttons, generated menus, custom displays, and dialogs. It does not establish the drafts' mandatory “two-view state matrix” in which every plugin must have both an inline readout and an expanded dashboard.

## 12. Easily confused features and names

| Term | Meaning to preserve in later discussions |
|---|---|
| Ordinary menu | User-organized collection of entries. |
| Virtual folder | View of an existing folder or shell-backed location. |
| Search-results virtual folder | Documented Explorer-search integration; not proof of TLB's own query language. |
| Recently accessed | Vendor-described history of shortcuts launched through TLB, not necessarily system-wide recency. |
| Auto-sensing workspace | Toolbar selection based on applications. |
| Virtual Desktop | Separate plugin for desktop management. |
| Toolbar/menu tag | Activation tab for hidden bars/menus, not semantic metadata. |
| Related links | Additional actions/destinations associated with an item. |
| Tear-off menu | A persistent menu surface detached from ordinary popup lifetime. |
| Portable mode | A deployment mode whose capabilities changed between versions. |

The “Recently accessed” scope is explicitly described by the [feature page](https://www.truelaunchbar.com/features.html). Other distinctions summarize the cited sections above.

### 12.1 Recent/frequent menus and separator behavior

The manual describes a single Recently Accessed menu for items launched through TLB. It can sort by last-run time **or run count**, has a configurable item limit, accepts appearance changes, and permits removing entries. This confirms a frequency-based presentation as well as recency. The one-menu restriction is manual-era evidence, not a claim about every later version. [M, pp. 22, 62]

Separator groups support automatic collapse when another group expands or when the menu closes. They span icon-oriented layouts too. A documented advanced technique selectively unhides items from a collapsed group so the shown/hidden sets toggle when expanded. Menu-level Run All executes visible shortcuts, distinct from a separator's group-level Run All. [M, pp. 51, 59–61]

## 13. Audit of the supplied AI drafts

This table evaluates claims, not the intentions of their author. “Unverified” means evidence was not obtained; it is not a claim that the feature never existed.

| Draft claim | Assessment | Treatment in this reference |
|---|---|---|
| All state is a filesystem mirror with no independent database | Overstated | Retain the folder-based user model; leave internal indexing/storage unspecified. |
| Uses `FindFirstChangeNotification` or `ReadDirectoryChangesW` | Unverified internals | Remove named APIs until core source or authoritative developer material establishes them. |
| Shortcut parsing is asynchronous | Partly related evidence only | Background folder/icon loading is documented; exact shortcut parsing implementation is not. |
| Hidden `tlb.ini` in every directory | Unsupported filename | Vendor documents `tlbdata.xml` and `setup.ini`; see section 9. |
| NTFS virtual streams hold layout metadata | Unverified | Remove. |
| All ordering uses hidden metadata tracking indices | Partly confirmed | `tlbdata.xml` stores item positions; exact schema/index algorithm is not established. |
| Registry globals plus a specific INI fallback | Unverified/version-sensitive | Use the vendor's documented transfer locations instead. |
| Backup is a ZIP containing `.reg` and INI payloads | Unverified format | Keep single-file backup/restore and image transport; do not specify archive internals. |
| `%TLB_DRIVE%` guarantees cross-machine portability | Unverified macro | Exclude pending documentation. |
| Hover defaults are exactly 200/300/400 ms | Unverified defaults | State adjustable delays; distinguish menu open, launch, close, and drag timing. |
| Ctrl/Shift/Alt universally suspend all hover behavior | Overgeneralized | Record historically documented suppression and key/version differences. |
| Every item supports the same three-state presentation contract | Overgeneralized | Record actual view modes and mixed layouts without inventing universal per-node rules. |
| Column layout always follows a fixed item-count formula | Unverified algorithm | Retain multi-column support and known restrictions. |
| Blank spacers are necessarily a built-in primitive | Misclassified | Identify the separately documented Spacer plugin. |
| Every plugin has an inline readout plus a dashboard | Unsupported architectural rule | Describe varied plugin presentations. |
| Network plugin exposes per-process bandwidth maps | Unsupported by retrieved plugin documentation | Keep verified per-connection statistics; investigate separately if remembered. |
| Hover always transfers keyboard focus immediately | Unverified universal behavior | Record keyboard support and documented focus restoration only. |
| All dropped files become shortcuts | Contradicted as a universal rule | Manual documents move, copy, shortcut, virtual-menu creation, and application-target drops. |
| Arbitrary dragged text becomes a text scrap | Unverified | Exclude pending evidence. |
| TLB used a general metadata-query/tag engine | Not established | Explorer-search integration is confirmed; an independent query language is not. |
| QML is inherently faster than the old rendering engine | Unsupported comparison and out of scope | Remove performance and Linux implementation advice entirely. |

### Manual inconsistencies retained for review

- Page 6 names Ctrl+Shift+right-click for the full context menu; p. 49 names Shift+right-click. Both support a bypass feature, but the exact chord needs version testing.
- Page 30 describes a smaller scrolling interval as slower movement, which conflicts with the ordinary interpretation of a pause between steps. Record the configurable interval without adopting that direction claim.
- Page 58 orders custom image states as normal, pressed, active. Later history reports state-order changes; image packing must be tied to a release.
- Page 36 places Shift suppression under hover execution. That supports the older behavior without resolving the later Ctrl description or proving suppression of every hover action.

## 14. Open questions for historical review

These are research questions, not a future-feature backlog.

- [x] Review the supplied complete 68-page manual; identify the pictured v3.2.13 RC1 build. Exact publication date remains unknown.
- [ ] Date the documented metadata formats and establish the backup container format by version.
- [ ] Verify relative paths, supported environment substitutions, and drive-letter changes.
- [x] Recover four manual-era menu view modes and seven sort fields.
- [ ] Establish exact mask syntax, folder-processing choices, and hidden-state implementation.
- [x] Confirm keyboard type-to-select and menu opening from the manual.
- [x] Confirm manual-era recent/frequent sorting and TLB-only launch scope; later changes remain a research lead.
- [x] Confirm profile saving, deletion, and immediate switching.
- [ ] Establish the exhaustive fields captured by a profile.
- [ ] Recover complete weather, command-line, media, and Windows List plugin documentation.
- [ ] Inspect PDK interfaces/examples and licenses beyond the README-level inventory.
- [x] Recover documented toolbar insertion modifiers and application/folder-target drops.
- [ ] Verify remaining text/URL/shell-object edge cases through contemporary help or testing.
- [ ] Identify exact hover defaults by version, if preserving historical timing matters.
- [ ] Collect screenshots or recordings for mixed views, tear-off menus, and collapsible groups.

Review comments can refer to the stable feature IDs (for example, `VF-10` or `INPUT-03`). Missing memories should be added as unverified items until corroborated. Decisions about the Linux application's direction belong in a separate document after this historical inventory is reviewed.
