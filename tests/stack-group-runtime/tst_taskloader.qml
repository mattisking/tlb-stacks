import QtQuick
import QtTest
import com.mattphilmon.tlbstacks

// The group root's task bridge. main.qml is a PlasmoidItem and cannot be
// instantiated offscreen: PlasmaQuick requires the PlasmoidItem to be the
// engine's root QML item, and qmltestrunner's root is always the TestCase (a
// Loader-loaded or directory-imported copy is rejected with "not the root QML
// item"). So this suite drives the group root's ACTUAL taskLoader declaration
// instead of a hand-written stand-in: it reads the `Loader { id: taskLoader }`
// block out of package-group/contents/ui/main.qml, instantiates it verbatim
// under the root's own URL, and asserts the loader reaches Ready with the REAL
// TaskArea.qml (no mock taskArea).
//
// That URL matters. A relative `source: "TaskArea.qml"` resolves against the
// loading file's directory, and package-group/contents/ui/ contains no
// TaskArea.qml — the type lives in the com.mattphilmon.tlbstacks module. The
// single widget (package/contents/ui/main.qml) gets away with the URL because
// TaskArea.qml sits next to it; the group root does not, and every task surface
// in the group bar (running dots, the unclaimed-task append zone, the click
// matrix, hover tiles, Close) dies with Loader.Error. Executing the block here
// pins the mechanism: the same text that ships in the root is loaded with the
// same base URL, so a mechanism that only works because TaskArea.qml is a
// sibling cannot pass.
//
// Reading the root's source needs QML_XHR_ALLOW_FILE_READ=1, which
// scripts/ci-run.sh exports for the QML suites.
TestCase {
    id: test
    name: "GroupTaskAreaLoader"
    when: windowShown
    visible: true
    width: 200
    height: 200

    // The group root's URL: the base a relative loader source resolves against.
    readonly property url rootUrl: Qt.resolvedUrl("../../package-group/contents/ui/main.qml")

    // The widget's claimed desktop ids. The root's loader must receive this
    // value through the binding it creates, and follow later changes.
    Item {
        id: probeHost
        property var desktopIds: ["org.kde.konsole.desktop"]
    }

    // The instantiated loader block; rebuilt per test so each case starts from
    // a fresh component (a stale Loader.Error would otherwise be reused).
    property var probe: null

    function init() {
        if (probe) {
            probe.destroy()
            probe = null
        }
        probeHost.desktopIds = ["org.kde.konsole.desktop"]
    }

    function rootSource() {
        const xhr = new XMLHttpRequest()
        xhr.open("GET", rootUrl, false)
        xhr.send()
        return xhr.responseText
    }

    // The `Loader { ... }` block carrying `id: taskLoader`, brace-balanced so
    // the block's nested Component braces stay intact.
    function taskLoaderBlock() {
        const source = rootSource()
        const idIndex = source.indexOf("id: taskLoader")
        if (idIndex < 0) return ""
        const start = source.lastIndexOf("Loader {", idIndex)
        if (start < 0) return ""
        let depth = 0
        for (let i = start; i < source.length; ++i) {
            if (source[i] === "{") depth++
            else if (source[i] === "}") {
                depth--
                if (depth === 0) return source.substring(start, i + 1)
            }
        }
        return ""
    }

    // Runs the root's own loader declaration. `active` is stripped (the test
    // drives activation; offscreen there is no applet configuration to read)
    // and `root` is bound to the harness item, so the block's `root.desktopIds`
    // reaches probeHost. Everything else — the loading mechanism and the
    // desktopIds handoff — is the root's verbatim text.
    function taskLoader() {
        const block = taskLoaderBlock()
        if (!block) return null
        const mechanism = block.split("\n").filter(line => !/^\s*active:/.test(line)).join("\n")
        try {
            probe = Qt.createQmlObject(
                "import QtQuick\nimport com.mattphilmon.tlbstacks\n"
                + "Item { id: probeRoot; property var root: probeHost; " + mechanism + " }",
                probeHost, rootUrl.toString())
        } catch (error) {
            probe = null
            return null
        }
        for (let i = 0; i < probe.children.length; ++i)
            if (probe.children[i] instanceof Loader) return probe.children[i]
        return null
    }

    function readyTaskLoader() {
        const loader = taskLoader()
        verify(loader !== null, "no taskLoader block in package-group/contents/ui/main.qml")
        tryVerify(() => loader.status !== Loader.Loading, 5000)
        return loader
    }

    function test_task_loader_reaches_ready_with_the_real_task_area() {
        const loader = readyTaskLoader()
        compare(loader.status, Loader.Ready, "taskLoader failed to load: " + loader.errorString)
        verify(loader.item !== null, "taskLoader.item is null")
        // The root's claimed ids arrive through the binding created with the
        // item — null here means the loader degraded and the group bar lost
        // its task bridge.
        verify(loader.item.desktopIds !== null, "desktopIds was not delivered")
        compare(loader.item.desktopIds, probeHost.desktopIds)
    }

    function test_desktop_ids_binding_follows_the_root() {
        const loader = readyTaskLoader()
        compare(loader.item.desktopIds, ["org.kde.konsole.desktop"])
        probeHost.desktopIds = ["org.kde.dolphin.desktop", "org.kde.konsole.desktop"]
        tryCompare(loader.item, "desktopIds", ["org.kde.dolphin.desktop", "org.kde.konsole.desktop"])
    }

    function test_real_task_area_surface_is_usable() {
        const loader = readyTaskLoader()
        const area = loader.item
        compare(area.available, true)
        compare(typeof area.stateFor, "function")
        // Idle apps answer with safe defaults, so the panel's click matrix and
        // running dots have a working bridge.
        compare(area.stateFor("never-running.desktop").running, false)
        compare(area.stateFor("never-running.desktop").count, 0)
        compare(Array.isArray(area.unclaimed), true)
        // The hover tiles read the same empty window list.
        compare(area.windows("never-running.desktop").length, 0)
    }
}
