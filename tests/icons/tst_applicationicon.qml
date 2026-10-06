import QtQuick
import QtTest
import "../../package/contents/ui" as TLB
TestCase {
    name: "ApplicationIconFallback"
    // Simulate theme availability; the native caller uses QIcon::hasThemeIcon.
    TLB.ApplicationIcon { id: icon; sourceAvailable: !source.startsWith("tlbstacks-missing-") }
    function test_chain_data() {
        return [
            {tag: "missing-theme", source: "tlbstacks-missing-81379", fallback: "folder", app: true},
            {tag: "missing-file", source: "/tmp/tlbstacks-missing-81379.png", fallback: "folder", app: true},
            {tag: "valid-override", source: "folder", fallback: "application-x-executable", app: false},
            {tag: "both-missing", source: "tlbstacks-missing-81379", fallback: "tlbstacks-missing-81380", app: true},
            {tag: "same-missing", source: "tlbstacks-missing-81379", fallback: "tlbstacks-missing-81379", app: false}
        ]
    }
    function test_chain(data) {
        icon.fallbackSource = data.fallback
        icon.source = data.source
        tryCompare(icon, "useAppFallback", data.app)
        if (data.app) {
            const loader = icon.children[2]
            tryVerify(() => loader.item !== null)
            compare(loader.item.source, data.fallback)
            tryCompare(loader.item.children[1], "valid", true)
        } else {
            tryCompare(icon.children[1], "valid", true)
        }
    }
}
