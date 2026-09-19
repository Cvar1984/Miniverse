using Toybox.Graphics as Graphics;
using Toybox.Lang as Lang;

// The one colour decision that depends on the screen. The black-and-white
// watches (see monkey.jungle) turn each colour into black or white on their own,
// and measured on the Instinct 2 the dark grid colours, the grey of the labels,
// red, green and orange all come out black: the grids, the constellations, Mars,
// Saturn and the on-target ring would vanish. So on those watches everything
// that is not black is drawn white, and on every other watch a colour passes
// through untouched.
module Palette {
    (:mono)
    function shown(color as Lang.Number) as Lang.Number {
        if (color == Graphics.COLOR_BLACK) {
            return color;
        }
        return Graphics.COLOR_WHITE;
    }

    (:colour)
    function shown(color as Lang.Number) as Lang.Number {
        return color;
    }
}
