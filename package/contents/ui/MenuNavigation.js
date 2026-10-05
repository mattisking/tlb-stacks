.pragma library

// Shared root-menu policy: start at the hovered row, then wrap at either end.
function nextIndex(count, selected, hovered, keyboard, step) {
    if (count <= 0) return -1
    const previous = keyboard ? selected : hovered
    if (previous < 0 || previous >= count) return step > 0 ? 0 : count - 1
    return (previous + step + count) % count
}
