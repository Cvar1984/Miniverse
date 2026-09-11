using Toybox.Graphics as Graphics;
using Toybox.Lang as Lang;

// Draws the horizon coordinate grid (circles of equal altitude and the vertical
// circles running between zenith and nadir) as seen looking out through the back
// of the watch.
//
// This is the frame you are standing in rather than the one the stars turn in, so
// it stays put as the night passes and reads directly: the horizon is the horizon,
// north is north, and straight up is the middle of the sky. Rest the watch flat on
// a table and the screen faces the zenith while the aim points at the nadir, so
// the vertical circles should all converge on the centre of the display.
//
// The mesh is built once and kept. Nothing in azimuth/altitude to East-North-Up
// depends on the clock, on where you stand, or on how the watch is held, so the
// same few hundred vectors come out every frame. Working them out ten times a
// second at a 15 degree spacing would take about sixteen thousand trig calls a
// second, against about a hundred for the whole 35-object catalogue, whose
// positions are cached. Only the rotation into the watch's axes is redone per
// frame, the same per-point work an object costs.
module HorizonGrid {
    const ALT_LIMIT = 60;       // highest and lowest circle of equal altitude drawn
    const AZ_SAMPLE = 20;       // plotted point spacing round a circle of equal altitude
    const ALT_SAMPLE = 20;      // plotted point spacing along a vertical circle

    // One entry per line of the grid: its colour, then a flat run of East-North-Up
    // triples. Held between frames, rebuilt only when the spacing changes.
    //
    // Colour travels with its own points rather than in a second array beside them,
    // so the two cannot fall out of step with each other.
    var _mesh as Lang.Array?;
    var _meshStep as Lang.Number = 0;

    // view is [cx, cy, focal], the same screen mapping the object dot uses, so the
    // grid and the object always agree. Points behind the watch come back null from
    // the projection and break the line there, rather than folding back
    // across the view.
    //
    // step is the spacing between lines in degrees, from the settings menu. The sky
    // turns 360 degrees in 24 hours, so a step of 15 makes every cell an hour
    // wide. Zero draws no lines.
    function draw(dc as Graphics.Dc, frame as Lang.Array<Lang.Float>, view as Lang.Array<Lang.Numeric>, step as Lang.Number) as Void {
        // The mesh is built from the view timer, not here, so a frame never pays
        // for a rebuild on top of its drawing. Until it is ready the lines wait.
        var mesh = _mesh;
        if (step > 0 && mesh != null && _meshStep == step) {
            var i = 0;
            while (i < mesh.size()) {
                var line = mesh[i];
                dc.setColor(line[0], Graphics.COLOR_TRANSPARENT);
                DeviceAim.drawRun(dc, frame, line[1], view);
                i += 1;
            }
        }

        // Drawn even with the grid switched off, because the letters say which way
        // you are facing.
        drawCardinals(dc, frame, view);
    }

    // Whether the mesh for this spacing is built and waiting.
    function ready(step as Lang.Number) as Lang.Boolean {
        return _mesh != null && _meshStep == step;
    }

    // The mesh for a given spacing, built on first use and kept until the spacing
    // changes, which only happens from the settings menu.
    function meshFor(step as Lang.Number) as Lang.Array {
        var held = _mesh;
        if (held != null && _meshStep == step) {
            return held;
        }

        // Let go of the old mesh before building the new one. Holding both at once
        // doubles the peak, and at the finest spacing that is the difference
        // between 14 KB and 28 KB on a device with 128 KB to spend on the lot.
        _mesh = null;

        var lines = [];

        // Counted outwards from the horizon rather than up from the bottom, so the
        // horizon itself is always one of the lines whatever the spacing is set to.
        var alt = 0;
        while (alt <= ALT_LIMIT) {
            lines.add([altitudeColor(alt), altitudeRun(alt)]);
            if (alt != 0) {
                lines.add([altitudeColor(-alt), altitudeRun(-alt)]);
            }
            alt += step;
        }

        var az = 0;
        while (az < 360) {
            lines.add([Graphics.COLOR_DK_BLUE, verticalRun(az)]);
            az += step;
        }

        _mesh = lines;
        _meshStep = step;
        return lines;
    }

    // A circle of equal altitude, running parallel to the horizon all the way round,
    // as a flat run of East-North-Up triples.
    //
    // Both runs below are sized up front and filled in place. The point count is
    // known before the loop starts, so growing the array a value at a time would
    // be wasted work.
    function altitudeRun(altDeg as Lang.Numeric) as Lang.Array<Lang.Float> {
        var run = new [(360 / AZ_SAMPLE + 1) * 3];
        var i = 0;
        var az = 0;
        while (az <= 360) {
            var enu = SkyMath.horizontalToEnu(az, altDeg);
            run[i] = enu[0];
            run[i + 1] = enu[1];
            run[i + 2] = enu[2];
            i += 3;
            az += AZ_SAMPLE;
        }
        return run;
    }

    // A vertical circle: straight up the sky from nadir to zenith on one bearing.
    // Sampled right to both poles, so they all meet at the point overhead and the
    // point underfoot.
    function verticalRun(azDeg as Lang.Numeric) as Lang.Array<Lang.Float> {
        var run = new [(180 / ALT_SAMPLE + 1) * 3];
        var i = 0;
        var alt = -90;
        while (alt <= 90) {
            var enu = SkyMath.horizontalToEnu(azDeg, alt);
            run[i] = enu[0];
            run[i + 1] = enu[1];
            run[i + 2] = enu[2];
            i += 3;
            alt += ALT_SAMPLE;
        }
        return run;
    }

    // The horizon is drawn brighter than the other circles. Below it the ground is
    // in the way, so those circles are drawn grey to read as underfoot.
    function altitudeColor(altDeg as Lang.Numeric) as Lang.Number {
        if (altDeg == 0) {
            return Graphics.COLOR_BLUE;
        }
        if (altDeg < 0) {
            return Graphics.COLOR_DK_GRAY;
        }
        return Graphics.COLOR_DK_BLUE;
    }

    // North, east, south and west, lettered where they meet the horizon. There are
    // only four points, so they are projected each frame instead of meshed.
    function drawCardinals(dc as Graphics.Dc, frame as Lang.Array<Lang.Float>, view as Lang.Array<Lang.Numeric>) as Void {
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        var az = 0;
        while (az < 360) {
            var point = screenPoint(frame, az, 0, view);
            if (point != null) {
                dc.drawText(point[0], point[1] - 8, Graphics.FONT_XTINY, cardinalName(az), Graphics.TEXT_JUSTIFY_CENTER);
            }
            az += 90;
        }
    }

    function cardinalName(azDeg as Lang.Numeric) as Lang.String {
        if (azDeg == 0) {
            return "N";
        }
        if (azDeg == 90) {
            return "E";
        }
        if (azDeg == 180) {
            return "S";
        }
        return "W";
    }

    // Where a point of sky lands on screen, or null if it is behind the watch.
    function screenPoint(frame as Lang.Array<Lang.Float>, azDeg as Lang.Numeric, altDeg as Lang.Numeric, view as Lang.Array<Lang.Numeric>) as Lang.Array<Lang.Number>? {
        var enu = SkyMath.horizontalToEnu(azDeg, altDeg);
        return DeviceAim.screenPoint(frame, enu[0], enu[1], enu[2], view);
    }
}
