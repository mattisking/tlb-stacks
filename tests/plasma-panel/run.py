"""Exercise a real TLBStacks Group panel with the repository's KWin test rig."""
import json
import os
import subprocess
from pathlib import Path
import shutil
import signal
import sys
import time

# Run with a clean environment and a private XDG_RUNTIME_DIR. There is no
# connection to the desktop bus or socket, and no system D-Bus access.
from kwin_mcp.session import Session, SessionConfig
from kwin_mcp.input import InputBackend, MouseButton

SOURCE = Path(__file__).resolve().parents[2]
APPLET = "com.mattphilmon.tlbstacks.group"


def seed(home, items):
    packages = home / ".local/share/plasma/plasmoids"
    shutil.copytree(SOURCE / "package-group", packages / APPLET)
    config = home / ".config/plasma-org.kde.plasma.desktop-appletsrc"
    config.write_text(f"""[Containments][1]
formfactor=2
immutability=1
lastScreen=0
location=4
plugin=org.kde.panel
wallpaperplugin=org.kde.image

[Containments][1][Configuration][General]
AppletOrder=2

[Containments][1][Applets][2]
immutability=1
plugin={APPLET}

[Containments][1][Applets][2][Configuration][General]
items={json.dumps(dict(version=7, items=items), separators=(',', ':'))}
taskTrackingEnabled=false

[Containments][1][ActionPlugins]
RightButton;NoModifier=org.kde.contextmenu
""")
    applications = home / ".local/share/applications"
    applications.mkdir()
    desktop = """[Desktop Entry]
Type=Application
Name=Panel test launcher
Exec=/usr/bin/true
Icon=utilities-terminal
"""
    (applications / "tlb-panel-plain.desktop").write_text(desktop)
    (applications / "tlb-panel-fixture.desktop").write_text(desktop + """Actions=Probe;

[Desktop Action Probe]
Name=Fixture Action
Exec=/usr/bin/true
""")


def main():
    build = Path(sys.argv[1]).resolve()
    output = Path(sys.argv[2]).resolve()
    scenario = sys.argv[3]
    with output.open("x"):
        pass
    scenarios = {
        "empty": [],
        "plain": [dict(id="launcher", type="application", desktopId="tlb-panel-plain")],
        "launcher": [dict(id="launcher", type="application", desktopId="tlb-panel-fixture")],
        "stack": [dict(id="stack", type="stack", settings=dict(menuSource="applications", groupName="Fixture Stack",
                  groupIcon="applications-all", applications=["tlb-panel-fixture"], iconsOnly=False,
                  menuIconSize=22, hoverDelay=300))],
    }
    def interrupted(signum, _frame):
        raise TimeoutError(f"Isolated panel interrupted ({signum})")

    for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGALRM):
        signal.signal(sig, interrupted)
    signal.alarm(65)
    session = Session()
    try:
        info = session.start(SessionConfig(isolate_home=True, screen_width=1024, screen_height=768))
        seed(info.home_dir, scenarios[scenario])
        subprocess.run(["/usr/bin/kbuildsycoca6", "--noincremental"], check=True, timeout=15, env={
            **os.environ, "HOME": str(info.home_dir), "XDG_CONFIG_HOME": str(info.home_dir / ".config"),
            "XDG_DATA_HOME": str(info.home_dir / ".local/share"), "XDG_CACHE_HOME": str(info.home_dir / ".cache"),
            "DBUS_SESSION_BUS_ADDRESS": info.dbus_address,
        })
        app = session.launch_app(["/usr/bin/plasmashell"], {
            "QML_IMPORT_PATH": str(build / "qml"), "LD_PRELOAD": str(build / "observe.so"),
            "QT_QUICK_BACKEND": "software", "KDE_FULL_SESSION": "true",
        })
        driver = InputBackend(info.dbus_address)
        deadline = time.monotonic() + 15
        while not any(e.get("class") == "PanelView" and e.get("event") == "Show"
                      for e in events(app.log_path.read_text(errors="replace"))):
            if time.monotonic() >= deadline:
                raise RuntimeError("No real Plasma PanelView")
            time.sleep(0.05)
        # Allow the layer-shell mapping and delegate layout to settle.
        time.sleep(1)
        def step(name):
            with app.log_path.open("a") as log:
                log.write("TLB_PANEL_STEP " + name + "\n")

        step("hover-button")
        driver.mouse_move(20, 745)
        time.sleep(1)
        if scenario == "stack":
            step("enter-popup")
            driver.mouse_move(35, 710)
            time.sleep(0.7)
            step("away-from-both")
            driver.mouse_move(700, 450)
            time.sleep(1)
            step("reset-click-away")
            driver.mouse_click(700, 450)
            time.sleep(0.7)
            step("reopen")
            driver.mouse_move(20, 745)
            time.sleep(0.7)
            step("physical-edge")
            driver.mouse_move(20, 767)
            time.sleep(1)
            step("reset-click-away")
            driver.mouse_click(700, 450)
            time.sleep(0.7)
            step("reopen-for-child")
            driver.mouse_move(20, 745)
            time.sleep(0.7)
            step("enter-for-child")
            driver.mouse_move(35, 710)
            time.sleep(0.7)
            step("popup-child-right-click")
            driver.mouse_click(35, 710, MouseButton.RIGHT)
            time.sleep(0.7)
            step("dismiss-child-menu")
            driver.mouse_click(700, 450)
            time.sleep(0.3)
            driver.mouse_click(700, 450)
            time.sleep(0.7)
            step("right-click-during-hover-delay")
        else:
            step("button-right-click")
        driver.mouse_click(20, 745, MouseButton.RIGHT)
        time.sleep(1)
        step("end")
    finally:
        try:
            signal.alarm(0)
            if "app" in locals() and app.log_path.exists():
                shutil.copyfile(app.log_path, output)
        finally:
            session.stop()
    return report(output, scenario)


EVENT = "TLB_PANEL_EVENT "
STEP = "TLB_PANEL_STEP "


def events(log):
    return [json.loads(line[len(EVENT):]) for line in log.splitlines() if line.startswith(EVENT)]


def report(output, scenario):
    sections = {}
    section = []
    for line in output.read_text(errors="replace").splitlines():
        if line.startswith(STEP):
            section = []
            sections.setdefault(line[len(STEP):], []).append(section)
        elif line.startswith(EVENT):
            section.append(json.loads(line[len(EVENT):]))

    def phase(name):
        return sections[name][0]

    def observed(rows, event, cls=None, popup=False):
        return any(e["event"] == event and (cls is None or e["class"] == cls)
                   and (not popup or e.get("stackPopup")) for e in rows)

    def actions(rows):
        return sorted({a["text"].replace("&", "") for e in rows if e["event"] == "Show"
                       for a in e.get("actions", []) if a["enabled"]})

    def configure(items):
        return any(item.startswith("Configure TLBStacks Group") for item in items)

    def launcher_hit(rows):
        return any(e["class"] == "PanelView" and e["event"] == "MouseButtonRelease"
                   and e.get("button") == 2 and any(b["id"] == "launcher"
                       and b["hovered"] and inside(e["position"], b["geometry"]) for b in e.get("buttons", []))
                   for e in rows)

    def inside(position, rect):
        x, y = position
        left, top, width, height = rect
        return left <= x < left + width and top <= y < top + height

    def need(condition, detail):
        if not condition:
            raise RuntimeError("Unqualified observation: " + detail)

    need("end" in sections, "input sequence did not complete")
    if scenario != "stack":
        click = phase("button-right-click")
        items = actions(click)
        if scenario != "empty":
            need(launcher_hit(click), "right click did not reach the expected launcher")
        else:
            need(configure(items), "empty-group native Configure control absent")
        results = {"configure": configure(items), "actions": items}
        if scenario == "launcher":
            results["fixture_action"] = "Fixture Action" in items
    else:
        hover = phase("hover-button")
        enter = phase("enter-popup")
        child = phase("popup-child-right-click")
        away = phase("away-from-both")
        edge = phase("physical-edge")
        right = phase("right-click-during-hover-delay")
        need(observed(hover, "Show", popup=True), "hover did not show the stack popup")
        need(observed(enter, "Enter", popup=True), "pointer did not enter the stack popup")
        need(observed(away, "Leave", popup=True), "popup did not receive pointer leave")
        need(observed(phase("reopen"), "Show", popup=True), "popup did not reopen for the edge probe")
        need(configure(actions(right)), "stack-button native menu control absent")
        results = {
            "enter_kept_popup_open": not observed(enter, "Hide", popup=True),
            "child_actions": actions(child),
            "away_collapsed": observed(away, "Hide", popup=True),
            "edge_pixel_collapsed": observed(edge, "Hide", popup=True),
            "edge_pixel_left_panel": observed(edge, "Leave", "PanelView"),
            "stack_button_actions": actions(right),
            "stack_button_menu_dismissed": observed(right, "Hide", "QMenu"),
        }
    checks = {"configuration_available": results["configure"]} if scenario != "stack" else {
        "hover_transfer_keeps_popup_open": results["enter_kept_popup_open"],
        "outside_pointer_collapses_popup": results["away_collapsed"],
        "stack_child_action_preserved": "Fixture Action" in results["child_actions"],
        "stack_button_menu_stays_visible": not results["stack_button_menu_dismissed"],
    }
    if scenario == "launcher":
        checks["launcher_action_available"] = results["fixture_action"]
    verdict = "PASS" if all(checks.values()) else "RED"
    print(json.dumps({"scenario": scenario, "status": verdict, "checks": checks,
                      "observed": results, "trace": str(output)}, sort_keys=True))
    return int(verdict == "RED")


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, KeyError, ValueError, subprocess.SubprocessError) as exc:
        print(f"BLOCKED: {exc}", file=sys.stderr)
        sys.exit(2)
