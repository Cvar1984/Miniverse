using Toybox.Application as Application;
using Toybox.Lang as Lang;

// The choices the app keeps between runs.
//
// Each value is read from storage once and then held in memory, written through as
// it changes, so the draw loop can ask for one every frame at 10 Hz without going
// near flash.
//
// Three of these decide what is allowed to move. A still screen is easier to read
// against, so the grids and the fix are held by default and each can be released
// on its own.
module Settings {
    // The sky turns a full circle in 24 hours, so 15 degrees is one hour of it.
    const DEGREES_PER_HOUR = 15;

    var _cache = null;
    var _specs = null;

    // Every setting by the id its menu item uses: [storage key, the values it steps
    // through, default].
    //
    // The horizon grid's key is horizonGrid, not the one earlier builds used. That
    // key can still hold a spacing saved while the grid was on by default, which
    // would override the off default here.
    //
    // Both grids start off, since the sky is what the screen is for. Grid spacings
    // run coarse to fine, wrapping, with Off in the ring. Finer spacings cost frame
    // time (halving the step roughly doubles the points plotted), so the list stops
    // at 10 rather than running down to 5.
    //
    // Both motions are held still by default. When allowed to, the equatorial grid
    // turns with the sky, which is accurate but leaves a reference that keeps
    // creeping. The azimuth one only has an effect while the position is being
    // refreshed: there is no clock in the horizon frame.
    //
    // Location is minutes between refreshes, 0 for one fix and no more. A fix costs
    // battery, so the intervals are long. Anywhere you can walk to inside half an
    // hour is far below what a wrist compass can resolve.
    function specs() as Lang.Dictionary {
        if (_specs == null) {
            var grid = [0, 60, 45, 30, 15, 10];
            var toggle = [false, true];
            _specs = {
                "horizon" => ["horizonGrid", grid, 0],
                "equatorial" => ["eqGridStep", grid, 0],
                "constellations" => ["constellations", toggle, false],
                "dynEquatorial" => ["dynEquatorial", toggle, false],
                "dynAzimuth" => ["dynAzimuth", toggle, false],
                "location" => ["locationMinutes", [0, 5, 15, 30, 60], 0]
            };
        }
        return _specs;
    }

    function get(id) {
        var spec = specs()[id];
        if (_cache == null) {
            _cache = {};
        }
        var held = _cache[spec[0]];
        if (held != null) {
            return held;
        }
        var stored = Application.Storage.getValue(spec[0]);
        if (stored == null) {
            stored = spec[2];
        }
        _cache[spec[0]] = stored;
        return stored;
    }

    // Steps a setting to the next value in its list and round to the start again. A
    // short list is quicker to thumb through in place than to open a submenu for,
    // and it cannot go stale behind the menu that shows it.
    function cycle(id) {
        var spec = specs()[id];
        var choices = spec[1];
        var current = get(id);
        var next = spec[2];
        var i = 0;
        while (i < choices.size()) {
            if (choices[i] == current) {
                next = choices[(i + 1) % choices.size()];
                break;
            }
            i += 1;
        }
        _cache[spec[0]] = next;
        Application.Storage.setValue(spec[0], next);
    }

    // What the menu shows under each item.
    function label(id) {
        var v = get(id);
        if (id.equals("horizon") || id.equals("equatorial")) {
            return gridLabel(v);
        }
        if (id.equals("location")) {
            if (v <= 0) {
                return "One fix only";
            }
            return "Every " + v.toString() + " min";
        }
        if (id.equals("dynEquatorial")) {
            if (v) {
                return "Turns with sky";
            }
            return "Held still";
        }
        if (id.equals("dynAzimuth")) {
            // Says so when this is switched on with nothing to follow, instead of
            // reading as on and doing nothing.
            if (!v) {
                return "Held still";
            }
            if (get("location") <= 0) {
                return "On - no updates";
            }
            return "Follows position";
        }
        if (v) {
            return "On";
        }
        return "Off";
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
}
