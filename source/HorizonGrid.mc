using Toybox.Graphics as Graphics;
using Toybox.Lang as Lang;

// Draws the horizon coordinate grid - circles of equal altitude and the vertical
// circles running between zenith and nadir - as seen looking out through the back
// of the watch.
//
// This is the frame you are standing in rather than the one the stars turn in, so
// it stays put as the night passes and reads directly: the horizon is the horizon,
// north is north, and straight up is the middle of the sky. Rest the watch flat on
// a table and the screen faces the zenith while the aim points at the nadir, so
// the vertical circles should all converge on the centre of the display.
//
// Each plotted point costs a handful of trig calls, so the sampling constants
// below are the knob to turn if this ever costs too much frame time.
module HorizonGrid {
    const ALT_LINE_STEP = 30;   // circles of equal altitude this far apart
    const ALT_LIMIT = 60;       // highest and lowest one drawn
    const AZ_LINE_STEP = 45;    // vertical circles this far apart, so eight compass points
    const AZ_SAMPLE = 20;       // plotted point spacing round a circle of equal altitude
    const ALT_SAMPLE = 20;      // plotted point spacing along a vertical circle

    // view is [cx, cy, focal], the same screen mapping the object
    // dot uses, so the grid and the object always agree. Points behind the watch
    // come back null from the projection and simply break the line there, rather
    // than folding back across the view.
    function draw(dc as Graphics.Dc, frame as Lang.Array<Lang.Float>, view as Lang.Array<Lang.Numeric>) as Void {
        var alt = -ALT_LIMIT;
        while (alt <= ALT_LIMIT) {
            dc.setColor(altitudeColor(alt), Graphics.COLOR_TRANSPARENT);
            drawAltitudeCircle(dc, frame, alt, view);
            alt += ALT_LINE_STEP;
        }

        var az = 0;
        while (az < 360) {
            dc.setColor(Graphics.COLOR_DK_BLUE, Graphics.COLOR_TRANSPARENT);
            drawVerticalCircle(dc, frame, az, view);
            az += AZ_LINE_STEP;
        }

        drawCardinals(dc, frame, view);
    }

    // The horizon is the line worth telling apart. Below it the ground is in the
    // way, so those circles are drawn dimmer to read as underfoot.
    function altitudeColor(altDeg as Lang.Numeric) as Lang.Number {
        if (altDeg == 0) {
            return Graphics.COLOR_BLUE;
        }
        if (altDeg < 0) {
            return Graphics.COLOR_DK_GRAY;
        }
        return Graphics.COLOR_DK_BLUE;
    }

    // A circle of equal altitude, running parallel to the horizon all the way round.
    //
    // The previous point is held as plain coordinates plus a flag rather than a
    // nullable pair, so that dropping a point behind the watch simply breaks the
    // line here instead of joining across the gap.
    function drawAltitudeCircle(dc as Graphics.Dc, frame as Lang.Array<Lang.Float>, altDeg as Lang.Numeric, view as Lang.Array<Lang.Numeric>) as Void {
        var havePrevious = false;
        var previousX = 0;
        var previousY = 0;
        var az = 0;
        while (az <= 360) {
            var point = screenPoint(frame, az, altDeg, view);
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
            az += AZ_SAMPLE;
        }
    }

    // A vertical circle: straight up the sky from nadir to zenith on one bearing.
    // Sampled right to both poles, so they all meet at the point overhead and the
    // point underfoot.
    function drawVerticalCircle(dc as Graphics.Dc, frame as Lang.Array<Lang.Float>, azDeg as Lang.Numeric, view as Lang.Array<Lang.Numeric>) as Void {
        var havePrevious = false;
        var previousX = 0;
        var previousY = 0;
        var alt = -90;
        while (alt <= 90) {
            var point = screenPoint(frame, azDeg, alt, view);
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
            alt += ALT_SAMPLE;
        }
    }

    // North, east, south and west, lettered where they meet the horizon. The most
    // directly useful thing on the screen: it says which way you are facing.
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
