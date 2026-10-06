.pragma library

// Shared root-menu policy: start at the hovered row, then wrap at either end.
function nextIndex(count, selected, hovered, keyboard, step, selectable) {
    if (count <= 0) return -1
    const previous = keyboard ? selected : hovered
    let index = previous < 0 || previous >= count
        ? (step > 0 ? 0 : count - 1)
        : (previous + step + count) % count
    for (let visited = 0; visited < count; visited++) {
        if (!selectable || selectable[index]) return index
        index = (index + step + count) % count
    }
    return -1
}
