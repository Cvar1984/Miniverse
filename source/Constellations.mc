using Toybox.Graphics as Graphics;
using Toybox.Lang as Lang;

// The constellation stick figures: eight of the ones people actually recognise,
// drawn as line joining their stars.
//
// The vertices live here rather than in StarCatalog because most of them are not
// stars you would ever aim at. A figure needs its faint stars to read - Orion
// without Mintaka and Saiph is three dots, the Plough without Dubhe and Merak is
// nothing at all - and putting fifty of those into the catalogue would bury the 28
// bright ones in the Stars menu and scatter them over Show All. They are line
// endpoints, not objects, so they are held as plain coordinates.
//
// Positions are J2000 right ascension and declination in degrees, same as
// StarCatalog. Precession and proper motion are ignored for the same reason: both
// are far under what a wrist compass resolves, and these are drawn as lines rather
// than aimed at.
//
// A dozen of the vertices below are bright enough to be in StarCatalog as well -
// Betelgeuse, Bellatrix, Alnilam, Alnitak, Rigel, Alkaid, Mizar, Polaris, Antares,
// Deneb, Regulus, Denebola - and are repeated here rather than looked up, so that
// a figure is one flat run of numbers instead of a mix of names and coordinates.
// The cost is that the two lists have to be corrected together: a position fixed
// in only one of them leaves the figure hanging off its own star.
module Constellations {
    // A steel blue-grey, clear of the horizon grid's blues and the equatorial
    // grid's reds so all three can be on at once and still be told apart.
    const LINE_COLOR = 0x557788;

    var _figures as Lang.Array<Lang.Array<Lang.Float>>? = null;

    // Each figure is one unbroken run of line: right ascension and declination in
    // degrees, in pairs, drawn point to point. A constellation that does not trace
    // in a single stroke simply takes more than one run.
    function figures() as Lang.Array<Lang.Array<Lang.Float>> {
        var held = _figures;
        if (held == null) {
            held = build();
            _figures = held;
        }
        return held;
    }

    function build() as Lang.Array<Lang.Array<Lang.Float>> {
        return [
            // Orion. Shoulders, then down one side through the belt and up the
            // other, then a leg from each end of the belt.
            [88.793, 7.407, 81.283, 6.350],
            [81.283, 6.350, 83.002, -0.299, 84.053, -1.202, 85.190, -1.943, 88.793, 7.407],
            [83.002, -0.299, 78.634, -8.202],
            [85.190, -1.943, 86.939, -9.670],

            // Ursa Major, the Plough. Handle first, round the bowl, and back to
            // Megrez to close it.
            [206.885, 49.313, 200.981, 54.925, 193.507, 55.960, 183.857, 57.033,
             178.458, 53.695, 165.460, 56.382, 165.932, 61.751, 183.857, 57.033],

            // Ursa Minor. The same shape the other way up, hanging off Polaris.
            [37.955, 89.264, 263.054, 86.586, 251.492, 82.037, 236.015, 77.794,
             244.376, 75.755, 230.182, 71.834, 222.676, 74.155, 236.015, 77.794],

            // Cassiopeia, the W.
            [2.295, 59.150, 10.127, 56.537, 14.177, 60.717, 21.454, 60.235, 28.599, 63.670],

            // Cygnus, the Northern Cross: the spine down from Deneb, then the
            // crossbar through Sadr.
            [310.358, 45.280, 305.557, 40.257, 292.680, 27.960],
            [296.244, 45.131, 305.557, 40.257, 311.553, 33.970],

            // Crux, the Southern Cross. Two bars that meet at nothing.
            [186.650, -63.099, 187.792, -57.113],
            [191.930, -59.689, 183.786, -58.749],

            // Scorpius. The head, then Antares, then the curve of the tail.
            [241.359, -19.805, 240.083, -22.622, 247.352, -26.432, 252.542, -34.293,
             264.330, -42.998, 263.402, -37.104],

            // Leo. The sickle that makes the head, then the body back to Denebola.
            [146.463, 23.774, 148.191, 26.007, 154.173, 23.417, 154.993, 19.842,
             151.833, 16.763, 152.093, 11.967],
            [152.093, 11.967, 168.560, 15.429, 177.265, 14.572, 168.527, 20.524,
             154.993, 19.842]
        ];
    }

    // view is [cx, cy, focal], the same screen mapping everything else uses. lat
    // and lstDeg must be the live ones, not the reading the equatorial grid may be
    // pinned to: the figures have to stay under the stars they join, and the stars
    // are drawn from the current time.
    function draw(dc as Graphics.Dc, frame as Lang.Array<Lang.Float>, view as Lang.Array<Lang.Numeric>, lat as Lang.Float, lstDeg as Lang.Double) as Void {
        dc.setColor(LINE_COLOR, Graphics.COLOR_TRANSPARENT);
        var figs = figures();
        var i = 0;
        while (i < figs.size()) {
            drawFigure(dc, frame, figs[i], view, lat, lstDeg);
            i += 1;
        }
    }

    // As in the two grids, the previous point is held as plain coordinates plus a
    // flag, so a star that falls behind the watch breaks the figure there instead
    // of drawing a line across the screen to the next one that does not.
    function drawFigure(dc as Graphics.Dc, frame as Lang.Array<Lang.Float>, points as Lang.Array<Lang.Float>, view as Lang.Array<Lang.Numeric>, lat as Lang.Float, lstDeg as Lang.Double) as Void {
        var havePrevious = false;
        var previousX = 0;
        var previousY = 0;
        var i = 0;
        while (i < points.size()) {
            var point = screenPoint(frame, points[i], points[i + 1], view, lat, lstDeg);
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
            i += 2;
        }
    }

    // Where a vertex lands on screen, or null if it is behind the watch.
    //
    // Refraction is applied here, unlike in the grids, and that is the whole reason
    // this is not just a call into EquatorialGrid.screenPoint. A grid line is its
    // own reference and nothing has to agree with it, but these lines have to sit
    // under the stars they join - and those stars are placed through
    // SkyMath.apparentAltitude, which lifts them. Leave it off and Orion's belt
    // draws a couple of pixels below its own three stars as the constellation
    // rises, which is exactly when anyone would be looking at it.
    //
    // Parallax is not applied: it is nothing at all for stars, which is all these
    // vertices are.
    function screenPoint(frame as Lang.Array<Lang.Float>, raDeg as Lang.Numeric, decDeg as Lang.Numeric, view as Lang.Array<Lang.Numeric>, lat as Lang.Float, lstDeg as Lang.Double) as Lang.Array<Lang.Number>? {
        var altAz = SkyMath.raDecToAltAz(raDeg, decDeg, lat, lstDeg);
        var alt = SkyMath.apparentAltitude(altAz[0], 0.0);
        var enu = SkyMath.horizontalToEnu(altAz[1], alt);
        return DeviceAim.screenPoint(frame, enu[0], enu[1], enu[2], view);
    }
}
