.pragma library

// Shared member-ID helpers for stacks. Both widget packages and the group
// schema use "tlbstacks-separator:<number>[:<label>]" entries inside the
// applications list. GroupItems.js keeps its own copies for its schema flow.
function isSeparator(id) {
    return typeof id === "string" && id.startsWith("tlbstacks-separator:")
}
function separatorNumber(id) {
    const rest = id.slice("tlbstacks-separator:".length)
    const colon = rest.indexOf(":")
    return colon < 0 ? rest : rest.slice(0, colon)
}
function separatorLabel(id) {
    const rest = id.slice("tlbstacks-separator:".length)
    const colon = rest.indexOf(":")
    return colon < 0 ? "" : rest.slice(colon + 1)
}
function appendSeparator(applications) {
    if (applications.length >= 2000) return applications
    const used = applications.filter(isSeparator).map(separatorNumber)
    let number = 1
    while (used.includes(String(number))) number++
    return applications.concat(["tlbstacks-separator:" + number])
}
function renameSeparator(applications, id, label) {
    if (!isSeparator(id)) return applications
    const base = "tlbstacks-separator:" + separatorNumber(id)
    const clean = label.trim().slice(0, 64)
    const updated = base + (clean ? ":" + clean : "")
    return applications.map(value => value === id ? updated : value)
}
