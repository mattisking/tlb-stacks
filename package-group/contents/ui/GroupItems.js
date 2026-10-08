.pragma library

// Each entry owns its identity independently of its application. This leaves room
// for stacks and distinct launch variants without changing existing entry IDs.
function decode(value) {
    try {
        const data = JSON.parse(value)
        if (!data || ![1, 2, 3, 4, 5, 6].includes(data.version) || !Array.isArray(data.items) || data.items.length > 500)
            throw new Error("Unsupported group format")
        const ids = new Set()
        for (const item of data.items) {
            if (!item || typeof item.id !== "string" || !item.id || ids.has(item.id))
                throw new Error("Invalid entry identity")
            if (["application", "command", "stack"].includes(item.type) && item.panelIconSize !== undefined
                && (!Number.isInteger(item.panelIconSize) || (item.panelIconSize !== 0 && (item.panelIconSize < 16 || item.panelIconSize > 64))))
                throw new Error("Invalid panel icon size")
            if (item.type === "command") {
                if (data.version < 6 || !validCommand(item.command)
                    || (item.icon !== undefined && typeof item.icon !== "string")
                    || (item.label !== undefined && (typeof item.label !== "string" || item.label.length > 256)))
                    throw new Error("Invalid custom launcher")
            } else if (item.type === "application") {
                if ((item.label !== undefined && (typeof item.label !== "string" || item.label.length > 256))
                    || (item.icon !== undefined && typeof item.icon !== "string")) throw new Error("Invalid launcher appearance")
                if (typeof item.desktopId !== "string" || !item.desktopId) throw new Error("Invalid application")
            } else if (item.type === "stack" && data.version >= 2) {
                const cfg = item.settings
                if (!cfg || !(data.version === 2 ? ["applications"] : ["applications", "categories", "activity", "folder"]).includes(cfg.menuSource) || typeof cfg.groupName !== "string"
                    || typeof cfg.groupIcon !== "string" || !Array.isArray(cfg.applications)
                    || cfg.applications.some(id => typeof id !== "string" || !id)
                    || new Set(cfg.applications).size !== cfg.applications.length
                    || cfg.applications.length > 2000 || typeof cfg.iconsOnly !== "boolean"
                    || !Number.isInteger(cfg.menuIconSize) || cfg.menuIconSize < 16 || cfg.menuIconSize > 64
                    || !Number.isInteger(cfg.hoverDelay) || cfg.hoverDelay < 0 || cfg.hoverDelay > 2000)
                    throw new Error("Invalid stack")
                const settings = sourceDefaults(cfg)
                const commands = settings.customLaunchers
                if (!commands || typeof commands !== "object" || Array.isArray(commands)
                    || Object.keys(commands).length > 2000
                    || Object.entries(commands).some(([id, c]) => !id.startsWith("tlbstacks-command:")
                        || !c || typeof c.name !== "string" || !c.name.trim() || c.name.length > 256 || c.name.includes("\0")
                        || typeof c.executable !== "string" || !c.executable.startsWith("/") || c.executable.length > 4096 || c.executable.includes("\0")
                        || !Array.isArray(c.arguments) || c.arguments.length > 256
                        || c.arguments.some(a => typeof a !== "string" || a.length > 4096 || a.includes("\0"))))
                    throw new Error("Invalid custom launcher")
                if (!settings.applicationIcons || typeof settings.applicationIcons !== "object"
                    || Array.isArray(settings.applicationIcons)
                    || Object.values(settings.applicationIcons).some(value => typeof value !== "string")
                    || !Array.isArray(settings.applicationCategories)
                    || settings.applicationCategories.some(value => typeof value !== "string" || !value)
                    || new Set(settings.applicationCategories).size !== settings.applicationCategories.length
                    || !["recent", "frequent"].includes(settings.activityOrder)
                    || !Number.isInteger(settings.activityLimit) || settings.activityLimit < 1 || settings.activityLimit > 50
                    || typeof settings.activityCurrent !== "boolean"
                    || typeof settings.folderUrl !== "string" || typeof settings.folderFilters !== "string"
                    || (settings.folderUrl && !settings.folderUrl.startsWith("file:///") && !settings.folderUrl.startsWith("/")))
                    throw new Error("Invalid source settings")
            } else throw new Error("Unsupported entry type")
            ids.add(item.id)
        }
        return {items: data.items.map(item => item.type === "stack"
            ? Object.assign({}, item, {settings: sourceDefaults(item.settings)}) : item), error: false}
    } catch (error) {
        return {items: [], error: true}
    }
}
function sourceDefaults(settings) {
    return Object.assign({applicationCategories: [], activityOrder: "recent", activityLimit: 10,
        activityCurrent: false, applicationIcons: {}, customLaunchers: {}, folderUrl: "", folderFilters: "*"}, settings)
}
function encode(items) {
    const version = items.some(item => item.type === "command" || item.panelIconSize) ? 6
        : items.some(item => item.type === "stack" && Object.keys(item.settings.customLaunchers || {}).length) ? 5
        : items.some(item => item.type === "application" && (item.label || item.icon)) ? 4
        : items.some(item => item.type === "stack" && item.settings.menuSource !== "applications") ? 3
        : items.some(item => item.type === "stack") ? 2 : 1
    return JSON.stringify({version: version, items: items})
}
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

function appendImportedStack(items, settings) {
    const next = addStack(items)
    if (next.length === items.length) return items
    return updateStack(next, next[next.length - 1].id, sourceDefaults(settings))
}
function replaceLauncher(items, id, desktopId) {
    if (!desktopId || !items.some(item => item.id === id && item.type === "application")) return items
    if (items.some(item => item.type === "application" && item.desktopId === desktopId && item.id !== id)) return items
    return items.map(item => item.id === id ? Object.assign({}, item, {desktopId: desktopId}) : item)
}

function updateLauncherAppearance(items, id, changes) {
    return items.map(item => item.id === id && (item.type === "application" || item.type === "command" || item.type === "stack")
        ? Object.assign({}, item, changes) : item)
}

function validCommand(c) {
    return c && typeof c.name === "string" && c.name.trim().length > 0 && c.name.length <= 256 && !c.name.includes("\0")
        && typeof c.executable === "string" && c.executable.startsWith("/") && c.executable.length <= 4096 && !c.executable.includes("\0")
        && Array.isArray(c.arguments) && c.arguments.length <= 256
        && c.arguments.every(a => typeof a === "string" && a.length <= 4096 && !a.includes("\0"))
}
function saveCommand(items, id, command) {
    if (!validCommand(command)) return items
    if (id) return items.map(item => item.id === id && item.type === "command" ? Object.assign({}, item, {command: command}) : item)
    if (items.length >= 500) return items
    let number = 1
    while (items.some(item => item.id === "item-" + number)) ++number
    return items.concat([{id: "item-" + number, type: "command", command: command}])
}

function panelSize(item, groupSize) {
    return item.panelIconSize || groupSize || 0
}
