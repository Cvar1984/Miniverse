using Toybox.Graphics as Graphics;
using Toybox.Lang as Lang;

// Draws the equatorial coordinate grid (circles of equal declination, and the
// hour circles running between the celestial poles) as seen looking out through
// the back of the watch.
//
// This is the frame the stars are fixed in rather than the one you are standing
// in. It turns with the sky through the night and carries the objects round with
// it, so a star sits at the same place on this grid at every hour, which is why a
// catalogue gives positions in it. Where HorizonGrid answers "how high, and which
// way", this answers "where among the stars".
//
// Like the HorizonGrid mesh, the points are worked out once per spacing and kept.
// They are held in the equatorial frame, where they never move, and each frame
// turns the whole grid with one matrix folded into the watch axes: nine
// multiplications a point. Working every point out from its RA and Dec each
// frame costs four trig calls a point, which at the finer spacings is more than a
// watch allows in one frame. Refraction is not applied: it is a fraction of a
// degree at the horizon and nothing higher up, under the width of these lines.
module EquatorialGrid {
    const DEC_LIMIT = 60;       // highest and lowest circle of equal declination drawn
    const RA_SAMPLE = 20;       // plotted point spacing round a circle of equal declination
    const DEC_SAMPLE = 20;      // plotted point spacing along an hour circle

    // Reds, so this tells apart at a glance from the blues HorizonGrid draws, and
    // kept dimmer than those: the horizon frame is the one you steer by, and this
    // sits behind it. There is no named red darker than DK_RED, so the ordinary
    // lines take a literal one.
    const EQUATOR_COLOR = Graphics.COLOR_DK_RED;
    const LINE_COLOR = 0x550000;

    // One entry per line: its colour, then a flat run of equatorial unit vectors.
    // Held between frames, rebuilt only when the spacing changes.
    var _mesh as Lang.Array?;
    var _meshStep as Lang.Number = 0;

    // view is [cx, cy, focal], the same screen mapping everything else uses. step
    // is the spacing between lines in degrees, and 0 draws nothing: right ascension
    // runs round the same 360 degrees as azimuth does, so a step of 15 puts the
    // hour circles one hour of right ascension apart.
    //
    // lat and lstDeg tie this frame to the sky overhead, and a changing lstDeg is
    // what makes this grid move.
    function draw(dc as Graphics.Dc, frame as Lang.Array<Lang.Float>, view as Lang.Array<Lang.Numeric>, step as Lang.Number, lat as Lang.Float, lstDeg as Lang.Double) as Void {
        if (step <= 0) {
            return;
        }
        // Built from the view timer, not here, so a frame never pays for a
        // rebuild on top of its drawing. Until it is ready the lines wait.
        var mesh = _mesh;
        if (mesh == null || _meshStep != step) {
            return;
        }
        var sky = DeviceAim.rotateFrame(frame, SkyMath.equatorialToEnu(lat, lstDeg));
        var i = 0;
        while (i < mesh.size()) {
            var line = mesh[i];
            dc.setColor(line[0], Graphics.COLOR_TRANSPARENT);
            DeviceAim.drawRun(dc, sky, line[1], view);
            i += 1;
        }
    }

    // Whether the mesh for this spacing is built and waiting.
    function ready(step as Lang.Number) as Lang.Boolean {
        return _mesh != null && _meshStep == step;
    }

    // The mesh for a given spacing, built on first use and kept until the spacing
    // changes.
    function meshFor(step as Lang.Number) as Lang.Array {
        var held = _mesh;
        if (held != null && _meshStep == step) {
            return held;
        }

        // Let go of the old mesh before building the new one, so both are never
        // held at once.
        _mesh = null;

        var lines = [];

        // Counted outwards from the celestial equator rather than up from the south
        // pole, so the equator itself is always one of the lines whatever the
        // spacing is set to.
        var dec = 0;
        while (dec <= DEC_LIMIT) {
            lines.add([declinationColor(dec), declinationRun(dec)]);
            if (dec != 0) {
                lines.add([declinationColor(-dec), declinationRun(-dec)]);
            }
            dec += step;
        }

        var ra = 0;
        while (ra < 360) {
            lines.add([LINE_COLOR, hourRun(ra)]);
            ra += step;
        }

        _mesh = lines;
        _meshStep = step;
        return lines;
    }

    // The celestial equator gets its own colour: it is the zero of declination,
    // where the Sun crosses at the equinoxes.
    function declinationColor(decDeg as Lang.Numeric) as Lang.Number {
        if (decDeg == 0) {
            return EQUATOR_COLOR;
        }
        return LINE_COLOR;
    }

    // A circle of equal declination, running parallel to the celestial equator all
    // the way round, as a flat run of equatorial unit vectors.
    function declinationRun(decDeg as Lang.Numeric) as Lang.Array<Lang.Float> {
        var run = new [(360 / RA_SAMPLE + 1) * 3];
        var i = 0;
        var ra = 0;
        while (ra <= 360) {
            var v = SkyMath.raDecToVector(ra, decDeg);
            run[i] = v[0];
            run[i + 1] = v[1];
            run[i + 2] = v[2];
            i += 3;
            ra += RA_SAMPLE;
        }
        return run;
    }

    // An hour circle: straight from pole to pole at one right ascension. Sampled to
    // both poles, so they all meet at the two points the sky turns about.
    function hourRun(raDeg as Lang.Numeric) as Lang.Array<Lang.Float> {
        var run = new [(180 / DEC_SAMPLE + 1) * 3];
        var i = 0;
        var dec = -90;
        while (dec <= 90) {
            var v = SkyMath.raDecToVector(raDeg, dec);
            run[i] = v[0];
            run[i + 1] = v[1];
            run[i + 2] = v[2];
            i += 3;
            dec += DEC_SAMPLE;
        }
        return run;
    }
}
