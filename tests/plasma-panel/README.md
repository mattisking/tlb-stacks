# Isolated Plasma panel regression probe

This opt-in test uses the same virtual KWin and EIS mouse input as the
repository's KWin MCP rig. It starts a real plasmashell on a private Wayland
socket and session bus, seeds one bottom panel and one TLBStacks Group in a
temporary home, and observes Qt events in that shell only. It does not install
the applet or reload the desktop. Do not run it as root.

Prerequisites are Plasma 6, a working virtual KWin backend and EIS input,
the installed KWin MCP Python environment, the usual applet build
dependencies, and Qt 6 Widgets/Quick development files for the observer.
The environment must permit local Unix sockets. AT-SPI is unnecessary.

From the checkout being tested, use a fresh build and output directory.

```bash
work=$(mktemp -d /tmp/tlbstacks-panel.XXXXXX)
cmake -S . -B "$work/build" -G Ninja
cmake --build "$work/build" -j 4
c++ -std=c++17 -fPIC -shared tests/plasma-panel/observe.cpp \
    -o "$work/build/observe.so" $(pkg-config --cflags --libs Qt6Widgets Qt6Quick)

for scenario in empty plain launcher stack; do
    bash tests/plasma-panel/run.sh "$work/build" "$work/$scenario.trace" "$scenario"
    printf '%s exit=%s\n' "$scenario" "$?"
done
```

Set `KWIN_MCP_PYTHON` to the KWin MCP virtual environment's Python executable
if it is installed outside the default uv tools path. Each trace path must
be new. The process emits a JSON verdict on stdout. Exit 0 means the tested
expectations passed, 1 means an observed assertion failed, and 2 means the
fixture or observations could not qualify a verdict. A setup failure or
missing required pointer observation must never count as RED.

## Observations and limits

The observer records visible/enabled QMenu actions, pointer entry and leave
at the window boundary, mouse button delivery and delegate geometry,
popup visibility, and window activation with elapsed times. The runner
marks input steps and uses a fixed 300 ms hover delay. Internal QML timer
callbacks are not instrumented. The fixture targets the leftmost widget
on a 1024 × 768 virtual display. A launcher click must land inside the
known hovered delegate. The popup is identified by its existing
`openedAt` property. Changes to panel geometry or that probe point
may require requalifying the fixture. The observer needs Qt's widget-based
QMenu for action inspection.

The physical-edge probe moves to the last pixel of a single virtual output.
It reports whether the panel actually got a leave event. That movement
does not reproduce an exit from the surface if the pointer is still
inside it. A real floating-panel exit and physical pointer clamping need
separate qualification. The stack test records whether Configure appears
and whether the menu hides in the tested right-click sequence. It does
not assert the absence of flicker for all animation phases.

For TestFirstV1, build the candidate in isolated host-owned staging and
pin this runner, observer, fixture, toolchain and expected case outcomes
outside the editable workspace. Qualify the runner against the frozen
baseline and a reviewed reference candidate. Keep an independent final
panel acceptance check. The current Forge contract has one implementation
path and one editable test path. Keep the first ticket to group-panel
Configure access if it can be corrected in the group entrypoint alone.
Use a separate ticket for popup lifetime. If native menu composition needs
a shared C++ launcher change as well, extend the bounded path contract
before admitting that wider ticket.

## First qualified baseline

On Plasma 6.8.2 with Qt 6.11.2 at applet revision
`b5d1052c4fba2c82b3977b41b048c9ee60935148`:

- Empty group showed enabled native Configure and panel actions.
- The plain launcher and action-bearing launcher both received the right
  click over the expected delegate. Neither showed a QMenu in the probe
  window. The same action-bearing desktop fixture produced Fixture Action
  when used as a stack child, so that path is a positive control for the
  desktop action fixture.
- The popup opened on hover and stayed open when the pointer entered it.
  It received Leave when the pointer moved away, stayed visible for the
  one-second observation window, and closed on a separate outside click.
- The stack button exposed native Configure during the tested hover-delay
  sequence. Its menu did not dismiss in the observation window. The child
  menu exposed Fixture Action. The probe did not reproduce a premature
  dismissal or establish a physical or floating-edge exit.
