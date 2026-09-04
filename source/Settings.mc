using Toybox.Application as Application;
using Toybox.Lang as Lang;

// The choices the app keeps between runs.
//
// Each value is read from storage once and then held in memory, written through as
// it changes, so the draw loop can ask for one every frame at 10 Hz without going
// near flash.
//
// Three of these are about what is allowed to move. The screen is worth more when
// what is on it holds still, so the grids and the fix are all held by default and
// each is let loose on its own.
module Settings {
    // The horizon grid is on a new key. Its old one holds a spacing saved back when
    // it was the only grid and was on by default, and that stored value would
    // override the off-by-default below for anyone who had run an earlier build.
    const HORIZON_KEY = "horizonGrid";
    const EQUATORIAL_KEY = "eqGridStep";
    const DYNAMIC_EQUATORIAL_KEY = "dynEquatorial";
    const DYNAMIC_AZIMUTH_KEY = "dynAzimuth";
    const LOCATION_KEY = "locationMinutes";

    // The sky turns a full circle in 24 hours, so 15 degrees is one hour of it.
    const DEGREES_PER_HOUR = 15;

    // Both grids start off. The sky is what the screen is for, and a grid over it
    // is a reference you ask for rather than one you have to dismiss. Either is one
    // press away on the menu button.
    const DEFAULT_HORIZON = 0;
    const DEFAULT_EQUATORIAL = 0;

    // Held still by default. The equatorial grid turns with the sky when it is let
    // to, which is true to the sky but means a reference that never stops creeping.
    const DEFAULT_DYNAMIC_EQUATORIAL = false;
    const DEFAULT_DYNAMIC_AZIMUTH = false;

    // Minutes between position refreshes, 0 for one fix and no more.
    const DEFAULT_LOCATION_MINUTES = 0;

    var _cache = null;

    // Offered coarse to fine, wrapping, with Off in the ring so either grid can be
    // put away without leaving the item. Finer spacings cost real frame time -
    // halving the step roughly doubles the points plotted - so the list stops at 10
    // rather than running down to 5.
    function gridChoices() {
        return [0, 60, 45, 30, 15, 10];
    }

    function toggleChoices() {
        return [false, true];
    }

    // A fix costs battery, so the intervals are long. Anywhere you can walk to
    // inside half an hour is far below what a wrist compass can resolve, which is
    // why leaving this off is the sensible default rather than a compromise.
    function locationChoices() {
        return [0, 5, 15, 30, 60];
    }

    // Degrees between grid lines, or 0 for no grid.
    function horizonStep() {
        return value(HORIZON_KEY, DEFAULT_HORIZON);
    }

    function equatorialStep() {
        return value(EQUATORIAL_KEY, DEFAULT_EQUATORIAL);
    }

    // Whether the equatorial grid turns with the sky. Off, it is drawn from the
    // sidereal time it was last given and stays where it was put.
    function dynamicEquatorial() {
        return value(DYNAMIC_EQUATORIAL_KEY, DEFAULT_DYNAMIC_EQUATORIAL);
    }

    // Whether the horizon frame re-settles when the position refreshes. There is no
    // clock in that frame, so this only ever does anything while the position is
    // being refreshed - with location updates off it has nothing to follow.
    function dynamicAzimuth() {
        return value(DYNAMIC_AZIMUTH_KEY, DEFAULT_DYNAMIC_AZIMUTH);
    }

    function locationMinutes() {
        return value(LOCATION_KEY, DEFAULT_LOCATION_MINUTES);
    }

    function cycleHorizon() {
        cycle(HORIZON_KEY, gridChoices(), DEFAULT_HORIZON);
    }

    function cycleEquatorial() {
        cycle(EQUATORIAL_KEY, gridChoices(), DEFAULT_EQUATORIAL);
    }

    function cycleDynamicEquatorial() {
        cycle(DYNAMIC_EQUATORIAL_KEY, toggleChoices(), DEFAULT_DYNAMIC_EQUATORIAL);
    }

    function cycleDynamicAzimuth() {
        cycle(DYNAMIC_AZIMUTH_KEY, toggleChoices(), DEFAULT_DYNAMIC_AZIMUTH);
    }

    function cycleLocation() {
        cycle(LOCATION_KEY, locationChoices(), DEFAULT_LOCATION_MINUTES);
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

    function equatorialMotionLabel() {
        if (dynamicEquatorial()) {
            return "Turns with sky";
        }
        return "Held still";
    }

    // Says so when this is switched on with nothing to follow, rather than reading
    // as on and quietly doing nothing.
    function azimuthMotionLabel() {
        if (!dynamicAzimuth()) {
            return "Held still";
        }
        if (locationMinutes() <= 0) {
            return "On - no updates";
        }
        return "Follows position";
    }

    function locationLabel() {
        var minutes = locationMinutes();
        if (minutes <= 0) {
            return "One fix only";
        }
        return "Every " + minutes.toString() + " min";
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
