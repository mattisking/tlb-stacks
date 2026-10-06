.pragma library

// Each entry owns its identity independently of its application. This leaves room
// for stacks and distinct launch variants without changing existing entry IDs.
function decode(value) {
    try {
        const data = JSON.parse(value)
        if (!data || data.version !== 1 || !Array.isArray(data.items) || data.items.length > 500)
            throw new Error("Unsupported group format")
        const ids = new Set()
        for (const item of data.items) {
            if (!item || typeof item.id !== "string" || !item.id || ids.has(item.id)
                || item.type !== "application" || typeof item.desktopId !== "string" || !item.desktopId)
                throw new Error("Unsupported group entry")
            ids.add(item.id)
        }
        return {items: data.items, error: false}
    } catch (error) {
        return {items: [], error: true}
    }
}
function encode(items) { return JSON.stringify({version: 1, items: items}) }
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
