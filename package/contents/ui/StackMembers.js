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

function parseArguments(text) {
    const args = []
    let word = "", quote = "", escaped = false, started = false
    for (const ch of text) {
        if (escaped) { word += ch; escaped = false; started = true }
        else if (ch === "\\" && quote !== "'") { escaped = true; started = true }
        else if (quote) { if (ch === quote) quote = ""; else word += ch }
        else if (ch === "'" || ch === '"') { quote = ch; started = true }
        else if (/\s/.test(ch)) { if (started) { args.push(word); word = ""; started = false } }
        else { word += ch; started = true }
    }
    if (quote || escaped) return {error: "Unfinished quote or escape", arguments: []}
    if (started) args.push(word)
    return {error: "", arguments: args}
}
function formatArguments(args) {
    return args.map(arg => '"' + arg.replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"').join(" ")
}

function parseCustomLaunchers(value) {
    try {
        const result = typeof value === "string" ? JSON.parse(value) : value
        return result && typeof result === "object" && !Array.isArray(result) ? result : {}
    } catch (error) { return {} }
}
