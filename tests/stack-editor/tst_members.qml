import QtQuick
import QtTest
import com.mattphilmon.tlbstacks

TestCase {
    name: "StackMembers"
    function test_separator_detection() {
        verify(StackMembers.isSeparator("tlbstacks-separator:1"))
        verify(StackMembers.isSeparator("tlbstacks-separator:2:Games"))
        verify(StackMembers.isSeparator("tlbstacks-separator:3:with:colons"))
        verify(!StackMembers.isSeparator("org.kde.dolphin"))
        verify(!StackMembers.isSeparator(""))
        verify(!StackMembers.isSeparator(null))
    }
    function test_label_roundtrip_keeps_colons() {
        const id = "tlbstacks-separator:7:STALKER:Shadow"
        compare(StackMembers.separatorNumber(id), "7")
        compare(StackMembers.separatorLabel(id), "STALKER:Shadow")
        const renamed = StackMembers.renameSeparator(["a.desktop", id, "b.desktop"], id, " New : Label ")
        compare(renamed[1], "tlbstacks-separator:7:New : Label")
        compare(StackMembers.renameSeparator(renamed, renamed[1], "  ")[1], "tlbstacks-separator:7")
        // Non-separator ids pass through untouched.
        compare(StackMembers.renameSeparator(["a.desktop"], "a.desktop", "x")[0], "a.desktop")
    }
    function test_append_separator_finds_free_number() {
        const apps = ["tlbstacks-separator:1", "tlbstacks-separator:2:X", "app.desktop"]
        const next = StackMembers.appendSeparator(apps)
        compare(next.length, apps.length + 1)
        verify(next.includes("tlbstacks-separator:3"))
        // 2000-member cap holds.
        const full = new Array(2000).fill("app.desktop")
        compare(StackMembers.appendSeparator(full).length, 2000)
    }
}
