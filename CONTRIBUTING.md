# Contributing to TLBStacks

[Project home](README.md) · [Documentation guide](docs/README.md)

## Report a problem

Use [GitHub Issues](https://github.com/mattisking/tlb-stacks/issues). Include:

- Distribution, Plasma and Qt versions, and whether the session uses Wayland or X11.
- The stack source (selected applications, categories, or Live Folder).
- Steps to reproduce, expected behavior, and what actually happened.
- Relevant logs or a screenshot, after removing private paths and other personal data.
- For placement problems, monitor arrangement and display scaling.

For a new feature, describe the workflow you want to improve and check the
[feature tracker](docs/FEATURE_TRACKER.md) for existing plans. Historical Windows
features are context, not an agreed implementation backlog.

## Prepare a change

Keep each change focused. Follow existing C++/QML conventions and preserve saved
configuration and profile compatibility. Explain any migration explicitly.
Use the [deployment guide](docs/DEPLOYMENT.md) for local setup and the
[testing guide](docs/TESTING_AND_STATUS.md#automated-checks) for relevant checks.
Do not run destructive file tests against personal folders.

Run checks relevant to the affected behavior. For menu changes, also verify the
actual Plasma session: offscreen tests cannot establish Wayland placement or
input correctness. State what you tested and what remains unverified.

Update the authoritative documentation alongside behavior changes, linking to
existing procedures instead of copying them. Submit a pull request with the
problem, resulting behavior, and validation. Do not include generated build
output, local machine settings, or unrelated edits.

## Licensing contributions

Contributions to original project code and documentation are provided under
GPL-3.0-or-later, as described in [the README](README.md#license-and-attribution)
and [LICENSE](LICENSE). Preserve third-party attribution and identify any external
code or assets you propose to add. Do not assume the project license covers the
historical Windows manual or application icons; see [third-party notices](THIRD_PARTY_NOTICES.md).
