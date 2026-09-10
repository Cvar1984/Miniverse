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
// Unlike the HorizonGrid mesh, these points are worked out every frame. Each is
// one raDecToEnu call, and the sampling constants below set how many there are.
// Refraction is not applied: it is a fraction of a degree at the horizon and
// nothing higher up, which is under the width of these lines.
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

    // view is [cx, cy, focal], the same screen mapping everything else uses. step
    // is the spacing between lines in degrees, and 0 draws nothing: right ascension
    // runs round the same 360 degrees as azimuth does, so a step of 15 puts the
    // hour circles one hour of right ascension apart.
    //
    // lat and lstDeg tie this frame to the sky overhead. They turn a catalogue
    // position into a place on the screen, and a changing lstDeg is what makes
    // this grid move.
    function draw(dc as Graphics.Dc, frame as Lang.Array<Lang.Float>, view as Lang.Array<Lang.Numeric>, step as Lang.Number, lat as Lang.Float, lstDeg as Lang.Double) as Void {
        if (step <= 0) {
            return;
        }

        // Counted outwards from the celestial equator rather than up from the south
        // pole, so the equator itself is always one of the lines whatever the
        // spacing is set to.
        var dec = 0;
        while (dec <= DEC_LIMIT) {
            dc.setColor(declinationColor(dec), Graphics.COLOR_TRANSPARENT);
            DeviceAim.drawRun(dc, frame, declinationRun(dec, lat, lstDeg), view);
            if (dec != 0) {
                dc.setColor(declinationColor(-dec), Graphics.COLOR_TRANSPARENT);
                DeviceAim.drawRun(dc, frame, declinationRun(-dec, lat, lstDeg), view);
            }
            dec += step;
        }

        dc.setColor(LINE_COLOR, Graphics.COLOR_TRANSPARENT);
        var ra = 0;
        while (ra < 360) {
            DeviceAim.drawRun(dc, frame, hourRun(ra, lat, lstDeg), view);
            ra += step;
        }
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
    // the way round, as a flat run of East-North-Up triples.
    function declinationRun(decDeg as Lang.Numeric, lat as Lang.Float, lstDeg as Lang.Double) as Lang.Array<Lang.Float> {
        var run = new [(360 / RA_SAMPLE + 1) * 3];
        var i = 0;
        var ra = 0;
        while (ra <= 360) {
            var enu = SkyMath.raDecToEnu(ra, decDeg, lat, lstDeg);
            run[i] = enu[0];
            run[i + 1] = enu[1];
            run[i + 2] = enu[2];
            i += 3;
            ra += RA_SAMPLE;
        }
        return run;
    }

    // An hour circle: straight from pole to pole at one right ascension. Sampled to
    // both poles, so they all meet at the two points the sky turns about.
    function hourRun(raDeg as Lang.Numeric, lat as Lang.Float, lstDeg as Lang.Double) as Lang.Array<Lang.Float> {
        var run = new [(180 / DEC_SAMPLE + 1) * 3];
        var i = 0;
        var dec = -90;
        while (dec <= 90) {
            var enu = SkyMath.raDecToEnu(raDeg, dec, lat, lstDeg);
            run[i] = enu[0];
            run[i + 1] = enu[1];
            run[i + 2] = enu[2];
            i += 3;
            dec += DEC_SAMPLE;
        }
        return run;
    }
}
