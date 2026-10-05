# TrueLaunchBar — living project guide

[Project home](../README.md) · [Feature tracker](FEATURE_TRACKER.md) · [Testing status](TESTING_AND_STATUS.md)

**Updated:** October 5, 2026. This is the entry point for current project work.
Individual Plasma stack widgets remain the focus. Selected Applications, Categories,
and Live Folder share navigation rules, with source-specific content and actions.

## Find the authoritative topic

| Need | Read |
|---|---|
| Build, install, or diagnose a stale plugin | [Deployment](DEPLOYMENT.md) and [import-path troubleshooting](DEPLOYMENT.md#import-path-and-restart-troubleshooting) |
| Understand entries and source-specific actions | [Entry model](STACK_ENTRY_MODEL.md#item-description) |
| Understand keyboard and pointer behavior | [Navigation contract](STACK_ENTRY_MODEL.md#navigation-contract) |
| Run regression checks | [Automated checks](TESTING_AND_STATUS.md#automated-checks) |
| See what actually passed on the desktop | [Desktop results](TESTING_AND_STATUS.md#desktop-checks-reported-by-the-user) |
| Find unverified combinations | [Remaining verification](TESTING_AND_STATUS.md#still-to-verify) |
| Review planned features or add a request | [Feature tracker](FEATURE_TRACKER.md) |
| Compare current Linux behavior with the Windows app | [Historical overlap table](STACK_IMPLEMENTATION_CROSS_REFERENCE.md#cross-reference-what-our-existing-features-cover) |

## Historical reference, by topic

The research reference describes the original Windows product, not a commitment
to implement everything it did. The cross-reference is a comparison, not this
project's README or roadmap.

- [Toolbar organization](TRUE_LAUNCH_BAR_WINDOWS_FEATURE_REFERENCE.md#3-toolbars-items-and-organization)
- [Virtual folders and dynamic content](TRUE_LAUNCH_BAR_WINDOWS_FEATURE_REFERENCE.md#4-virtual-folders-and-dynamic-content)
- [Mouse, keyboard, and launch actions](TRUE_LAUNCH_BAR_WINDOWS_FEATURE_REFERENCE.md#5-mouse-keyboard-drag-and-drop-and-launch-actions)
- [Menu layouts and positioning](TRUE_LAUNCH_BAR_WINDOWS_FEATURE_REFERENCE.md#6-menu-layouts-size-and-positioning)
- [Appearance and information display](TRUE_LAUNCH_BAR_WINDOWS_FEATURE_REFERENCE.md#8-appearance-and-information-display)
- [Saved state and transfer](TRUE_LAUNCH_BAR_WINDOWS_FEATURE_REFERENCE.md#9-saved-state-transfer-and-administrative-controls)
- [Published source and SDK boundary](TRUE_LAUNCH_BAR_WINDOWS_FEATURE_REFERENCE.md#11-published-source-sdk-and-application-boundary)
- [Original user's manual](<True Launch Bar User's Manual.pdf>) — unchanged source PDF

## How we maintain these docs

Each topic has one authoritative home. Link to it rather than copy its procedure,
requirements, or status into several documents. Other pages may provide a short
contextual summary, but should direct readers to the owning section for details.

Capture new user requests in the feature tracker as they arrive, with a stable ID,
status, acceptance criteria, and unresolved questions. An idea is not automatically
a scheduled commitment. When implementation changes, update the owning behavior
doc and tracker in the same work; record automated evidence and user verification
in Testing and status. Keep done entries with links rather than deleting their history.

Extract a small procedure into its own page when multiple workflows need it, or
when it has a distinct maintenance reason. Give it prerequisites, the steps, the
expected result, and links back to its callers. Until then, link to a section in
an existing page; do not create files merely to make the document tree larger.
Keep the deployment command in Deployment and test commands in Testing and status.

Use repository-relative links and stable headings/explicit anchors for recurring
references. Keep the index current when adding/moving a page and check inbound
links. Historical evidence stays in the Windows reference; current architecture
stays in the entry model; planned work stays in the tracker. A successful build is
not a desktop verification result. Preserve the PDF unchanged.
