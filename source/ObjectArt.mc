using Toybox.Graphics as Graphics;
using Toybox.Lang as Lang;
using Toybox.Math as Math;

// How each object is drawn: its colour, its size, and the little that can be shown
// of its face at the size a watch has room for.
//
// Stellarium wraps photographic surface maps onto spheres on the GPU. That detail
// is lost on a disc 32 pixels across, and the maps are equirectangular, so they
// would need projecting before they could be drawn. Nothing here is a texture
// image. At this size only a handful of features are still recognisable as shapes:
// the Sun's corona, the Moon's phase, Saturn's rings, Jupiter's belts.
//
// The phase is computed the way Stellarium does it: from the angle between the
// object and the Sun as seen from here.
module ObjectArt {
    // Points sampled along each half-ellipse. Twelve is smooth at these radii and
    // is a polygon the device fills in one go.
    const ARC_STEPS = 12;

    // The screen width the catalogue's disc radii are written for.
    const REFERENCE_WIDTH = 400;

    // Approximate on-screen colour for an object. The Sun, the Moon and the
    // planets carry theirs in the catalogue; stars are white. Shown through the
    // Palette, so a black-and-white screen draws every body; the shading built
    // off it stays dark, which keeps the Moon's phase.
    function color(obj as Lang.Dictionary) as Lang.Number {
        var c = obj[:color];
        if (c == null) {
            return Graphics.COLOR_WHITE;
        }
        return Palette.shown(c);
    }

    // Disc radius in pixels of the screen it is drawn on: fixed per body for the
    // Sun, the Moon and the planets, which carry theirs in the catalogue, and
    // magnitude-scaled for stars, where brighter stars draw larger the way they
    // look.
    //
    // Those radii suit a screen about REFERENCE_WIDTH across and are scaled from
    // there. A size that suits a fenix is a fifth of an Instinct's 176-pixel glass,
    // where it runs into the readout underneath.
    function radius(obj as Lang.Dictionary, width as Lang.Number) as Lang.Number {
        var r = obj[:r];
        if (r == null) {
            var mag = obj[:mag];
            if (mag == null) {
                r = 3;
            } else {
                r = (5.0 - mag).toNumber();
                if (r < 2) {
                    r = 2;
                }
                if (r > 7) {
                    r = 7;
                }
            }
        }
        r = r * width / REFERENCE_WIDTH;
        if (r < 2) {
            // Smaller than this is a dot rather than a disc, and a body that is
            // there at all should be visible.
            r = 2;
        }
        return r;
    }

    // Draws the object centred at (x, y).
    //
    // base is the colour to build from. The caller dims it for anything under the
    // horizon, and every shade here comes off it, so a dimmed object stays dimmed
    // all the way through. offset, sunOffset and zenith are directions in the
    // watch's own axes, as DeviceAim.viewOffset gives them: the object, the Sun,
    // and straight up. The last two are what orient the phase and the rings, and
    // either may be null, in which case a plain disc is drawn.
    function draw(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, obj as Lang.Dictionary, base as Lang.Number, offset as Lang.Array<Lang.Float>, sunOffset as Lang.Array?, zenith as Lang.Array?) as Void {
        switch (obj[:type]) {
            case :sun:
                drawSun(dc, x, y, base, radius(obj, dc.getWidth()));
                return;
            case :moon:
                // Without the Sun to light it there is no phase to draw, and the
                // Moon falls back to the plain disc below.
                if (sunOffset != null) {
                    drawMoon(dc, x, y, base, radius(obj, dc.getWidth()), offset, sunOffset);
                    return;
                }
                break;
            case :planet:
                drawPlanet(dc, x, y, obj, base, offset, zenith);
                return;
            default:
                break;
        }
        dc.setColor(base, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, radius(obj, dc.getWidth()));
    }

    // Corona outside the disc, and a disc that brightens towards the middle. Limb
    // darkening is the one feature of the Sun's face visible to the naked eye
    // through cloud, and it keeps the disc from reading as a flat yellow dot.
    function drawSun(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, base as Lang.Number, r as Lang.Number) as Void {
        dc.setColor(shade(base, 1, 4), Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x, y, r + r / 3);
        dc.setColor(shade(base, 2, 5), Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x, y, r + r / 6);

        dc.setColor(shade(base, 4, 5), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r);
        dc.setColor(base, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r - r / 3);
    }

    // The Moon at its current phase.
    //
    // Both directions are unit vectors, so their dot product is the cosine of the
    // elongation, and the lit fraction follows from it directly: k = (1 - m.s) / 2.
    // What the drawing wants is c = 2k - 1, which is -(m.s). It runs from -1 at
    // new, through 0 at half, to +1 at full, and it is the width of the
    // terminator ellipse as a fraction of the disc.
    //
    // The bright limb faces the Sun, so the whole thing is oriented by the tangent
    // direction from the Moon towards it. That comes out of the geometry rather
    // than off the screen, which is why it stays right as the wrist rolls.
    function drawMoon(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, base as Lang.Number, r as Lang.Number, offset as Lang.Array<Lang.Float>, sunOffset as Lang.Array) as Void {
        var dark = shade(base, 1, 6);

        var dot = offset[0] * sunOffset[0] + offset[1] * sunOffset[1] + offset[2] * sunOffset[2];
        var c = -dot;

        // Sun towards the Moon with the along-the-Moon part taken out: what is left
        // points along the sphere from one to the other.
        var tRight = sunOffset[0] - dot * offset[0];
        var tUp = sunOffset[1] - dot * offset[1];
        // Screen y runs down where up runs up, which is the only reason for the sign.
        var bx = tRight;
        var by = -tUp;
        var len = Math.sqrt(bx * bx + by * by);
        if (len < 0.000001) {
            // Sun dead behind or dead in front of the Moon, where there is no bright
            // limb to point at. The phase is then full or new, so it does not matter.
            bx = 1.0;
            by = 0.0;
        } else {
            bx = bx / len;
            by = by / len;
        }

        // Unlit side drawn faint rather than left out: on a black panel a thin
        // crescent would otherwise be all there is of the Moon, and it would be easy
        // to lose against the stars.
        dc.setColor(dark, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r);

        dc.setColor(base, Graphics.COLOR_TRANSPARENT);
        fillHalfEllipse(dc, x, y, bx, by, r, r);

        // The terminator bulges past the middle into the dark side when gibbous and
        // bites into the bright side when a crescent. Same ellipse either way: only
        // the colour it is painted in changes, and its width is c.
        if (c >= 0) {
            dc.setColor(base, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(dark, Graphics.COLOR_TRANSPARENT);
        }
        fillHalfEllipse(dc, x, y, bx, by, -c * r, r);
    }

    // Saturn gets its rings and Jupiter its belts, both lying along the object's own
    // equator. That is taken as square to the local vertical, worked out from where
    // the zenith is in the watch's axes, so the rings roll with the sky rather than
    // with the wrist. A ring pinned to the screen would be wrong as soon as you
    // turned your arm.
    function drawPlanet(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, obj as Lang.Dictionary, base as Lang.Number, offset as Lang.Array<Lang.Float>, zenith as Lang.Array?) as Void {
        var r = radius(obj, dc.getWidth());
        var id = obj[:id];

        var along = equatorDirection(offset, zenith);
        var ax = along[0];
        var ay = along[1];

        if (id.equals("saturn")) {
            // Drawn before the disc so the planet sits in front of its own rings.
            dc.setPenWidth(2);
            dc.setColor(shade(base, 3, 5), Graphics.COLOR_TRANSPARENT);
            var reach = 2 * r + 2;
            dc.drawLine((x - reach * ax).toNumber(), (y - reach * ay).toNumber(),
                (x + reach * ax).toNumber(), (y + reach * ay).toNumber());
            dc.setPenWidth(1);
        }

        dc.setColor(base, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r);

        if (id.equals("jupiter")) {
            // Two belts either side of the equator, which is as much as any small
            // telescope shows and as much as there is room for here.
            dc.setColor(shade(base, 3, 5), Graphics.COLOR_TRANSPARENT);
            drawBelt(dc, x, y, r, ax, ay, r / 2);
            drawBelt(dc, x, y, r, ax, ay, -r / 2);
        }
    }

    // A belt across the disc at the given distance from the equator, cut to the
    // chord so it stops at the limb instead of running past it.
    function drawBelt(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, r as Lang.Number, ax as Lang.Float, ay as Lang.Float, gap as Lang.Number) as Void {
        var half = Math.sqrt((r * r - gap * gap).toFloat());
        var px = -ay;
        var py = ax;
        var cx = x + gap * px;
        var cy = y + gap * py;
        dc.drawLine((cx - half * ax).toNumber(), (cy - half * ay).toNumber(),
            (cx + half * ax).toNumber(), (cy + half * ay).toNumber());
    }

    // Screen direction of the object's equator: square to the way the zenith lies
    // from it. Falls back to across the screen when there is nothing to go on.
    function equatorDirection(offset as Lang.Array<Lang.Float>, zenith as Lang.Array?) as Lang.Array<Lang.Float> {
        if (zenith == null) {
            return [1.0, 0.0];
        }
        var dot = offset[0] * zenith[0] + offset[1] * zenith[1] + offset[2] * zenith[2];
        var upX = zenith[0] - dot * offset[0];
        var upY = -(zenith[1] - dot * offset[1]);
        var len = Math.sqrt(upX * upX + upY * upY);
        if (len < 0.000001) {
            return [1.0, 0.0];
        }
        // Square to the local vertical.
        return [-upY / len, upX / len];
    }

    // Half an ellipse as a filled polygon: semi-axis ax along (bx, by) and r across
    // it, closed along the diameter. ax may be negative, which puts the half on the
    // other side, as the terminator needs.
    //
    // Two convex halves rather than one lune, because a crescent is concave and how
    // a device fills a concave polygon is not something to rely on.
    function fillHalfEllipse(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, bx as Lang.Float, by as Lang.Float, ax as Lang.Numeric, r as Lang.Number) as Void {
        var px = -by;
        var py = bx;
        var points = new [ARC_STEPS + 1];
        var i = 0;
        while (i <= ARC_STEPS) {
            var t = (180.0 * i) / ARC_STEPS;
            var a = ax * SkyMath.dsin(t);
            var b = r * SkyMath.dcos(t);
            points[i] = [(x + a * bx + b * px).toNumber(), (y + a * by + b * py).toNumber()];
            i += 1;
        }
        dc.fillPolygon(points);
    }

    // A darker version of a colour, channel by channel, so every shade an object is
    // drawn in comes off the one colour it was given.
    function shade(color as Lang.Number, numerator as Lang.Number, denominator as Lang.Number) as Lang.Number {
        var r = ((color >> 16) & 0xFF) * numerator / denominator;
        var g = ((color >> 8) & 0xFF) * numerator / denominator;
        var b = (color & 0xFF) * numerator / denominator;
        return (r << 16) | (g << 8) | b;
    }
}
