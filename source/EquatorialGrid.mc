using Toybox.Graphics as Graphics;
using Toybox.Lang as Lang;

// Draws the equatorial coordinate grid - circles of equal declination, and the
// hour circles running between the celestial poles - as seen looking out through
// the back of the watch.
//
// This is the frame the stars are fixed in rather than the one you are standing
// in. It turns with the sky through the night and carries the objects round with
// it, so a star sits at the same place on this grid at every hour, which is why a
// catalogue gives positions in it. Where HorizonGrid answers "how high, and which
// way", this answers "where among the stars".
//
// Same shape and the same costs as HorizonGrid: each plotted point is a handful of
// trig calls, and the sampling constants below are the knob to turn.
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
    // runs round the same 360 degrees as azimuth does, so the default 15 makes each
    // hour circle exactly that - one hour of right ascension.
    //
    // lat and lstDeg are what hold this frame against the sky overhead. They turn a
    // catalogue position into somewhere on the screen, and they are the whole
    // reason this grid moves at all.
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
            drawDeclinationCircle(dc, frame, dec, view, lat, lstDeg);
            if (dec != 0) {
                dc.setColor(declinationColor(-dec), Graphics.COLOR_TRANSPARENT);
                drawDeclinationCircle(dc, frame, -dec, view, lat, lstDeg);
            }
            dec += step;
        }

        var ra = 0;
        while (ra < 360) {
            dc.setColor(LINE_COLOR, Graphics.COLOR_TRANSPARENT);
            drawHourCircle(dc, frame, ra, view, lat, lstDeg);
            ra += step;
        }
    }

    // The celestial equator is the one line worth telling from the rest: it is
    // where the Sun crosses at the equinoxes and the zero of declination.
    function declinationColor(decDeg as Lang.Numeric) as Lang.Number {
        if (decDeg == 0) {
            return EQUATOR_COLOR;
        }
        return LINE_COLOR;
    }

    // A circle of equal declination, running parallel to the celestial equator all
    // the way round.
    //
    // As in HorizonGrid, the previous point is held as plain coordinates plus a
    // flag rather than a nullable pair, so a point dropped behind the watch breaks
    // the line here instead of joining across the gap.
    function drawDeclinationCircle(dc as Graphics.Dc, frame as Lang.Array<Lang.Float>, decDeg as Lang.Numeric, view as Lang.Array<Lang.Numeric>, lat as Lang.Float, lstDeg as Lang.Double) as Void {
        var havePrevious = false;
        var previousX = 0;
        var previousY = 0;
        var ra = 0;
        while (ra <= 360) {
            var point = screenPoint(frame, ra, decDeg, view, lat, lstDeg);
            if (point != null) {
                var x = point[0];
                var y = point[1];
                if (havePrevious) {
                    dc.drawLine(previousX, previousY, x, y);
                }
                previousX = x;
                previousY = y;
                havePrevious = true;
            } else {
                havePrevious = false;
            }
            ra += RA_SAMPLE;
        }
    }

    // An hour circle: straight from pole to pole at one right ascension. Sampled to
    // both poles, so they all meet at the two points the sky turns about.
    function drawHourCircle(dc as Graphics.Dc, frame as Lang.Array<Lang.Float>, raDeg as Lang.Numeric, view as Lang.Array<Lang.Numeric>, lat as Lang.Float, lstDeg as Lang.Double) as Void {
        var havePrevious = false;
        var previousX = 0;
        var previousY = 0;
        var dec = -90;
        while (dec <= 90) {
            var point = screenPoint(frame, raDeg, dec, view, lat, lstDeg);
            if (point != null) {
                var x = point[0];
                var y = point[1];
                if (havePrevious) {
                    dc.drawLine(previousX, previousY, x, y);
                }
                previousX = x;
                previousY = y;
                havePrevious = true;
            } else {
                havePrevious = false;
            }
            dec += DEC_SAMPLE;
        }
    }

    // Where a point of the equatorial grid lands on screen, or null if it is behind
    // the watch. Refraction is not applied: it is a fraction of a degree at the
    // horizon and nothing higher up, which is under the width of these lines.
    function screenPoint(frame as Lang.Array<Lang.Float>, raDeg as Lang.Numeric, decDeg as Lang.Numeric, view as Lang.Array<Lang.Numeric>, lat as Lang.Float, lstDeg as Lang.Double) as Lang.Array<Lang.Number>? {
        var altAz = SkyMath.raDecToAltAz(raDeg, decDeg, lat, lstDeg);
        var enu = SkyMath.horizontalToEnu(altAz[1], altAz[0]);
        return DeviceAim.screenPoint(frame, enu[0], enu[1], enu[2], view);
    }
}
