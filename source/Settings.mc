using Toybox.Application as Application;
using Toybox.Lang as Lang;

// The choices the app keeps between runs.
//
// Each value is read from storage once and then held in memory, written through as
// it changes, so the draw loop can ask for one every frame at 10 Hz without going
// near flash.
module Settings {
    // The horizon grid is on a new key. Its old one holds a spacing saved back when
    // it was the only grid and was on by default, and that stored value would
    // override the off-by-default below for anyone who had run an earlier build.
    const HORIZON_KEY = "horizonGrid";
    const EQUATORIAL_KEY = "eqGridStep";

    // The sky turns a full circle in 24 hours, so 15 degrees is one hour of it.
    const DEGREES_PER_HOUR = 15;

    // Both grids start off. The sky is what the screen is for, and a grid over it
    // is a reference you ask for rather than one you have to dismiss. Either is one
    // press away on the menu button.
    const DEFAULT_HORIZON = 0;
    const DEFAULT_EQUATORIAL = 0;

    var _cache = null;

    // Offered coarse to fine, wrapping, with Off in the ring so either grid can be
    // put away without leaving the item. Finer spacings cost real frame time -
    // halving the step roughly doubles the points plotted - so the list stops at 10
    // rather than running down to 5.
    function gridChoices() {
        return [0, 60, 45, 30, 15, 10];
    }

    // Degrees between grid lines, or 0 for no grid.
    function horizonStep() {
        return value(HORIZON_KEY, DEFAULT_HORIZON);
    }

    function equatorialStep() {
        return value(EQUATORIAL_KEY, DEFAULT_EQUATORIAL);
    }

    function cycleHorizon() {
        cycle(HORIZON_KEY, gridChoices(), DEFAULT_HORIZON);
    }

    function cycleEquatorial() {
        cycle(EQUATORIAL_KEY, gridChoices(), DEFAULT_EQUATORIAL);
    }

    // Spacings that come to a whole number of hours say so, since that is what a
    // grid stepped in 15s divides the sky into.
    function gridLabel(step) {
        if (step <= 0) {
            return "Off";
        }
        var text = step.toString() + " deg";
        if (step % DEGREES_PER_HOUR == 0) {
            text += " - " + (step / DEGREES_PER_HOUR).toString() + " h";
        }
        return text;
    }

    function value(key, fallback) {
        if (_cache == null) {
            _cache = {};
        }
        var held = _cache[key];
        if (held != null) {
            return held;
        }
        var stored = Application.Storage.getValue(key);
        if (stored == null) {
            stored = fallback;
        }
        _cache[key] = stored;
        return stored;
    }

    function setValue(key, v) {
        if (_cache == null) {
            _cache = {};
        }
        _cache[key] = v;
        Application.Storage.setValue(key, v);
    }

    // Steps a setting to the next value in its list and round to the start again. A
    // short list is quicker to thumb through in place than to open a submenu for,
    // and it cannot go stale behind the menu that shows it.
    function cycle(key, choices, fallback) {
        var current = value(key, fallback);
        var i = 0;
        while (i < choices.size()) {
            if (choices[i] == current) {
                setValue(key, choices[(i + 1) % choices.size()]);
                return;
            }
            i += 1;
        }
        setValue(key, fallback);
    }
}
