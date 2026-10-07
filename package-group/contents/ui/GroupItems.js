.pragma library

// Each entry owns its identity independently of its application. This leaves room
// for stacks and distinct launch variants without changing existing entry IDs.
function decode(value) {
    try {
        const data = JSON.parse(value)
        if (!data || ![1, 2].includes(data.version) || !Array.isArray(data.items) || data.items.length > 500)
            throw new Error("Unsupported group format")
        const ids = new Set()
        for (const item of data.items) {
            if (!item || typeof item.id !== "string" || !item.id || ids.has(item.id))
                throw new Error("Invalid entry identity")
            if (item.type === "application") {
                if (typeof item.desktopId !== "string" || !item.desktopId) throw new Error("Invalid application")
            } else if (item.type === "stack" && data.version === 2) {
                const cfg = item.settings
                if (!cfg || cfg.menuSource !== "applications" || typeof cfg.groupName !== "string"
                    || typeof cfg.groupIcon !== "string" || !Array.isArray(cfg.applications)
                    || cfg.applications.some(id => typeof id !== "string" || !id)
                    || new Set(cfg.applications).size !== cfg.applications.length
                    || cfg.applications.length > 2000 || typeof cfg.iconsOnly !== "boolean"
                    || !Number.isInteger(cfg.menuIconSize) || cfg.menuIconSize < 16 || cfg.menuIconSize > 64
                    || !Number.isInteger(cfg.hoverDelay) || cfg.hoverDelay < 0 || cfg.hoverDelay > 2000)
                    throw new Error("Invalid stack")
            } else throw new Error("Unsupported entry type")
            ids.add(item.id)
        }
        return {items: data.items, error: false}
    } catch (error) {
        return {items: [], error: true}
    }
}
function encode(items) { return JSON.stringify({version: items.some(item => item.type === "stack") ? 2 : 1, items: items}) }
function add(items, desktopId) {
    if (!desktopId || items.length >= 500 || items.some(item => item.desktopId === desktopId)) return items
    let number = 1
    while (items.some(item => item.id === "item-" + number)) number++
    return items.concat([{id: "item-" + number, type: "application", desktopId: desktopId}])
}
function move(items, index, step) {
    const target = index + step
    if (index < 0 || index >= items.length || target < 0 || target >= items.length) return items
    const next = items.slice()
    next.splice(target, 0, next.splice(index, 1)[0])
    return next
}
function remove(items, index) { return items.filter((item, i) => i !== index) }

function addStack(items) {
    if (items.length >= 500) return items
    let number = 1
    while (items.some(item => item.id === "item-" + number)) number++
    return items.concat([{id: "item-" + number, type: "stack", settings: {
        menuSource: "applications", groupName: "", groupIcon: "applications-all",
        applications: [], iconsOnly: false, menuIconSize: 22, hoverDelay: 250
    }}])
}
function updateStack(items, id, changes) {
    return items.map(item => item.id === id && item.type === "stack"
        ? Object.assign({}, item, {settings: Object.assign({}, item.settings, changes)}) : item)
}

function isSeparator(id) { return typeof id === "string" && id.startsWith("tlbstacks-separator:") }
function separatorLabel(id) {
    const parts = id.split(":")
    return parts.slice(2).join(":")
}
function appendSeparator(applications) {
    if (applications.length >= 2000) return applications
    const used = applications.filter(isSeparator).map(id => id.split(":")[1])
    let number = 1
    while (used.includes(String(number))) number++
    return applications.concat(["tlbstacks-separator:" + number])
}
function renameSeparator(applications, id, label) {
    if (!isSeparator(id)) return applications
    const base = id.split(":").slice(0, 2).join(":")
    return applications.map(value => value === id ? base + (label.trim() ? ":" + label.trim() : "") : value)
}
