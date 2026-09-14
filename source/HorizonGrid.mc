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
// frame, the same per-point work an object costs. The equatorial grid draws from
// these meshes too (see EquatorialGrid).
module HorizonGrid {
    const ALT_LIMIT = 60;       // highest and lowest circle of equal altitude drawn
    const AZ_SAMPLE = 20;       // plotted point spacing round a circle of equal altitude
    const ALT_SAMPLE = 20;      // plotted point spacing along a vertical circle

    // Green, so this tells apart at a glance from the blue EquatorialGrid draws.
    // The compass letters take the brighter green, so they read over the lines.
    const LINE_COLOR = Graphics.COLOR_DK_GREEN;

    // Meshes by spacing, each a list of flat runs of East-North-Up triples, one run
    // a line. Both grids draw from here, so up to two are held at once, and only
    // one when both grids use the same spacing.
    var _meshes = {};

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
        var mesh = _meshes[step];
        if (step > 0 && mesh != null) {
            dc.setColor(LINE_COLOR, Graphics.COLOR_TRANSPARENT);
            var i = 0;
            while (i < mesh.size()) {
                DeviceAim.drawRun(dc, frame, mesh[i], view, 0);
                i += 1;
            }
        }

        // Drawn even with the grid switched off, because the letters say which way
        // you are facing.
        drawCardinals(dc, frame, view);
    }

    // Whether the mesh for this spacing is built and waiting.
    function ready(step as Lang.Number) as Lang.Boolean {
        return _meshes[step] != null;
    }

    // Lets go of every mesh neither grid is using, before anything new is built.
    // Holding an old mesh and its replacement together doubles the peak, and at
    // the finest spacing that is the difference between 14 KB and 28 KB on a
    // device with 128 KB to spend on the lot.
    function keepOnly(a as Lang.Number, b as Lang.Number) as Void {
        var keys = _meshes.keys();
        var i = 0;
        while (i < keys.size()) {
            if (keys[i] != a && keys[i] != b) {
                _meshes.remove(keys[i]);
            }
            i += 1;
        }
    }

    // The mesh for a given spacing, built on first use and kept until neither grid
    // uses that spacing any more (see keepOnly).
    function meshFor(step as Lang.Number) as Lang.Array {
        var held = _meshes[step];
        if (held != null) {
            return held;
        }

        var lines = [];

        // Counted outwards from the horizon rather than up from the bottom, so the
        // horizon itself is always one of the lines whatever the spacing is set to.
        var alt = 0;
        while (alt <= ALT_LIMIT) {
            lines.add(altitudeRun(alt));
            if (alt != 0) {
                lines.add(altitudeRun(-alt));
            }
            alt += step;
        }

        var az = 0;
        while (az < 360) {
            lines.add(verticalRun(az));
            az += step;
        }

        _meshes[step] = lines;
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

    // North, east, south and west, lettered where they meet the horizon. There are
    // only four points, so they are projected each frame instead of meshed.
    function drawCardinals(dc as Graphics.Dc, frame as Lang.Array<Lang.Float>, view as Lang.Array<Lang.Numeric>) as Void {
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        var az = 0;
        while (az < 360) {
            var enu = SkyMath.horizontalToEnu(az, 0);
            var point = DeviceAim.screenPoint(frame, enu[0], enu[1], enu[2], view);
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
}
