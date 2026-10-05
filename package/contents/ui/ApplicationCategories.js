.pragma library

function available(applications, selected) {
    const values = new Set(selected || [])
    for (const app of applications) {
        for (const category of app.categories || []) {
            if (category) values.add(category)
        }
    }
    return Array.from(values).sort((a, b) => a.localeCompare(b))
}

function matching(applications, selected) {
    const wanted = new Set(selected || [])
    const seen = new Set()
    return applications.filter(app => {
        if (seen.has(app.desktopId) || !(app.categories || []).some(value => wanted.has(value))) return false
        seen.add(app.desktopId)
        return true
    }).sort((a, b) => a.name.localeCompare(b.name) || a.desktopId.localeCompare(b.desktopId))
}
