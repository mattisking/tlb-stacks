.pragma library

function parse(value) {
    try {
        const icons = JSON.parse(value || "{}")
        return icons && typeof icons === "object" && !Array.isArray(icons) ? icons : {}
    } catch (error) {
        return {}
    }
}

function get(icons, desktopId) {
    return Object.prototype.hasOwnProperty.call(icons, desktopId) &&
        typeof icons[desktopId] === "string" ? icons[desktopId] : ""
}

function isFile(icon) {
    return icon.startsWith("/") || icon.startsWith("file:")
}
