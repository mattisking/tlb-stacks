import QtQuick
import QtTest
import "../../package-group/contents/ui/BarLayout.js" as BarLayout

// The group bar's gaps between buttons. The panel spaces its applets with
// min(theme margin + smallSpacing, floor(max(1, thickness - iconSizes.smallMedium) / 2))
// (the panel view's own formula, contents/views/Panel.qml), so the bar takes the
// same cap on the same theme value: one gap for every button kind, following the
// panel's rhythm as it gets shorter or taller.
TestCase {
    name: "BarLayout"

    function test_gap_is_the_theme_spacing_on_a_normal_panel() {
        // Thickness 44, smallMedium 16 -> cap 14, so the theme's 4 wins.
        compare(BarLayout.barButtonSpacing(44, 4, 16), 6)
        // The cap only ever tightens, so a tall panel keeps the theme spacing.
        compare(BarLayout.barButtonSpacing(56, 4, 16), 6)
        compare(BarLayout.barButtonSpacing(80, 4, 16), 6)
    }

    function test_gap_tightens_on_a_short_panel_like_the_panel_does() {
        // Thickness 20: floor((20 - 16) / 2) = 2, so the gap follows it down.
        compare(BarLayout.barButtonSpacing(20, 4, 16), 2)
        // Thickness 18: floor(2 / 2) = 1.
        compare(BarLayout.barButtonSpacing(18, 4, 16), 1)
    }

    function test_gap_is_never_zero_or_negative() {
        compare(BarLayout.barButtonSpacing(0, 4, 16), 1)
        compare(BarLayout.barButtonSpacing(10, 0, 16), 1)
        compare(BarLayout.barButtonSpacing(44, -4, 16), 1)
        compare(BarLayout.barButtonSpacing(NaN, 4, 16), 1)
    }

    function test_bar_length_counts_the_gaps_between_buttons() {
        // One button: no gap at all.
        compare(BarLayout.barLength(1, 44, 4), 44)
        // Three buttons: two gaps between them.
        compare(BarLayout.barLength(3, 44, 4), 3 * 44 + 2 * 4)
        // Nothing to show (the empty bar passes its configure button as one).
        compare(BarLayout.barLength(0, 44, 4), 0)
        // A zero gap still yields the plain run of cells.
        compare(BarLayout.barLength(4, 44, 0), 4 * 44)
        // Unusable counts cannot produce a negative extent.
        compare(BarLayout.barLength(-3, 44, 4), 0)
        compare(BarLayout.barLength(NaN, 44, 4), 0)
    }
}
