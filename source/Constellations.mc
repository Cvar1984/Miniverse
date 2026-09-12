using Toybox.Graphics as Graphics;
using Toybox.Lang as Lang;
using Toybox.Math as Math;

// The constellation stick figures: six familiar constellations and the twelve of
// the zodiac, drawn as lines joining their stars, with a dot on each star. The
// watches with half the per-frame budget carry eight of them (see zodiac).
//
// The vertices live here rather than in SkyCatalog because most of them are not
// stars you would ever aim at. A figure needs its faint stars to read: Orion
// without Mintaka and Saiph is three dots, and the Plough without Dubhe and Merak
// is unrecognisable. Putting all of those into the catalogue would bury the
// bright ones in the Stars menu and scatter them over Show All. They are line
// endpoints, not objects, so they are held as plain coordinates.
//
// Positions are J2000 right ascension and declination in degrees, same as
// SkyCatalog. Precession and proper motion are ignored for the same reason: both
// are far under what a wrist compass resolves, and these are drawn as lines rather
// than aimed at.
//
// Some of the vertices below are bright enough to be in SkyCatalog as well
// (Betelgeuse, Rigel, Aldebaran, Pollux, Castor, Regulus, Spica, Antares and
// others). They are repeated here rather than looked
// up, so that a figure is one flat run of numbers instead of a mix of names and
// coordinates.
// The cost is that the two lists have to be corrected together: a position fixed
// in only one of them leaves the figure hanging off its own star.
//
// The twelve zodiac figures follow the line figures published with d3-celestial
// (github.com/ofrohn/d3-celestial, BSD 3-Clause).
module Constellations {
    // A steel blue-grey, clear of the horizon grid's green and the equatorial
    // grid's blue so all three can be on at once and still be told apart.
    const LINE_COLOR = 0x557788;

    // Each figure is one unbroken run of line: right ascension and declination in
    // degrees, in pairs, drawn point to point. A constellation that does not trace
    // in a single stroke takes more than one run.
    function build() as Lang.Array<Lang.Array<Lang.Float>> {
        var figs = [
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

            // Two of the zodiac, on every watch.
            // Leo.
            [152.093, 11.967, 151.833, 16.763, 154.993, 19.841, 168.527, 20.524,
             177.265, 14.572, 168.560, 15.430, 152.093, 11.967],
            [154.993, 19.841, 154.173, 23.417, 148.191, 26.007, 146.463, 23.774],

            // Scorpius.
            [239.713, -26.114, 240.083, -22.622, 241.359, -19.805],
            [240.083, -22.622, 245.297, -25.593, 247.352, -26.432, 248.971, -28.216,
             252.541, -34.293, 252.968, -38.047, 253.646, -42.361, 258.038, -43.239,
             264.330, -42.998, 266.896, -40.127, 265.622, -39.030, 263.402, -37.104]
        ];
        var more = zodiac();
        var i = 0;
        while (i < more.size()) {
            figs.add(more[i]);
            i += 1;
        }
        return figs;
    }

    // The other ten constellations of the zodiac. They are left out on the
    // watches with half the per-frame budget (see monkey.jungle): a frame with
    // all of them on top of everything else is more than those allow, and the
    // smallest of them do not have the memory either. Leo and Scorpius stay
    // above for every watch.
    (:fullBudget)
    function zodiac() as Lang.Array<Lang.Array<Lang.Float>> {
        return [
            // Aries.
            [42.496, 27.261, 31.793, 23.462, 28.660, 20.808, 28.383, 19.294],

            // Taurus.
            [84.411, 21.142, 68.980, 16.509, 67.166, 15.871, 64.948, 15.628,
             65.734, 17.543, 67.154, 19.180, 81.573, 28.608],
            [64.948, 15.628, 60.170, 12.490, 51.792, 9.733, 60.789, 5.989],
            [51.792, 9.733, 51.203, 9.029, 54.218, 0.402],

            // Gemini.
            [93.719, 22.507, 95.740, 22.514, 100.983, 25.131, 107.785, 30.245,
             113.649, 31.888, 116.329, 28.026, 113.981, 26.896, 110.031, 21.982,
             106.027, 20.570, 99.428, 16.399, 101.322, 12.896],
            [110.031, 21.982, 109.523, 16.540],

            // Cancer.
            [134.622, 11.858, 131.171, 18.154, 130.821, 21.468, 131.667, 28.765],
            [131.171, 18.154, 124.129, 9.185],

            // Virgo.
            [176.465, 6.529, 177.674, 1.765, 184.976, -0.667, 190.415, -1.449,
             197.488, -5.539, 201.298, -11.161, 214.004, -6.000, 220.765, -5.658],
            [195.544, 10.959, 193.901, 3.397, 190.415, -1.449],
            [197.488, -5.539, 203.673, -0.596, 210.412, 1.544, 221.562, 1.893],

            // Libra.
            [226.018, -25.282, 222.720, -16.042, 229.252, -9.383, 233.882, -14.790,
             234.256, -28.135, 234.664, -29.778],
            [222.720, -16.042, 233.882, -14.790],

            // Sagittarius.
            [274.407, -36.762, 276.043, -34.385, 275.249, -29.828, 276.993, -25.422,
             273.441, -21.059],
            [290.660, -44.459, 290.972, -40.616, 285.653, -29.880, 281.414, -26.991,
             276.993, -25.422],
            [298.815, -41.868, 299.934, -35.276, 298.960, -26.299, 294.177, -24.884,
             291.319, -24.509, 288.885, -25.257, 283.816, -26.297, 281.414, -26.991,
             275.249, -29.828, 271.452, -30.424, 276.043, -34.385, 285.653, -29.880,
             286.735, -27.670, 283.816, -26.297, 286.171, -21.741, 287.441, -21.024,
             289.409, -18.953, 290.418, -17.847, 290.432, -15.955],
            [286.171, -21.741, 284.433, -21.107, 283.542, -22.745, 283.816, -26.297],

            // Capricornus.
            [304.412, -12.508, 305.253, -14.781, 307.215, -17.814, 311.524, -25.271,
             312.955, -26.919, 321.667, -22.411, 326.760, -16.127, 325.023, -16.662,
             320.562, -16.834, 316.487, -17.233, 304.412, -12.508],

            // Aquarius.
            [311.919, -9.496, 313.163, -8.983, 322.890, -5.571, 331.446, -0.320,
             335.414, -1.387, 337.208, -0.020, 338.839, -0.117, 343.154, -7.580,
             349.476, -9.182, 347.362, -21.172],
            [322.890, -5.571, 331.609, -13.870],
            [331.446, -0.320, 334.209, -7.783],
            [337.208, -0.020, 336.319, 1.377],
            [350.743, -20.101, 349.476, -9.182, 355.441, -17.817],

            // Pisces.
            [18.437, 24.584, 17.915, 30.090, 19.867, 27.264, 18.437, 24.584,
             17.863, 21.035, 22.871, 15.346, 26.349, 9.158, 30.512, 2.764,
             28.389, 3.188, 25.358, 5.488, 22.546, 6.144, 18.433, 7.575,
             15.736, 7.890, 12.171, 7.585, 359.828, 6.863, 354.988, 5.626,
             351.992, 6.379, 350.086, 5.381, 349.291, 3.282, 351.733, 1.256,
             355.512, 1.780, 356.598, 3.487, 354.988, 5.626],
            [349.291, 3.282, 345.969, 3.820]
        ];
    }

    (:halfBudget)
    function zodiac() as Lang.Array<Lang.Array<Lang.Float>> {
        return [] as Lang.Array<Lang.Array<Lang.Float>>;
    }

    // Every figure as runs of fixed equatorial unit vectors, built a few figures
    // a tick from the view timer (see buildSome), and the degrees they come
    // from, held only while that is under way.
    var _vectors as Lang.Array<Lang.Array<Lang.Float>>?;
    var _pending = null;
    const BUILD_CHUNK = 6;

    // Refraction is only worked out for vertices lower than this. At 15 degrees up
    // it is already down to 0.06 degrees, a fraction of a pixel, and it only gets
    // smaller higher up. It is the sine of that altitude, because the up component
    // of each vertex is already to hand.
    const REFRACTION_BELOW = 0.2588;

    // Nor for vertices more than 2 degrees under the horizon, where the formula
    // gives no lift at all. That leaves a thin band along the skyline, so a sky
    // full of figures pays for a few lifts a frame rather than for half of them.
    const REFRACTION_UNDER = -0.0349;

    // view is [cx, cy, focal], the same screen mapping everything else uses. lat
    // and lstDeg must be the live ones, not the reading the equatorial grid may be
    // pinned to: the figures have to stay under the stars they join, and the stars
    // are drawn from the current time.
    //
    // The vertices are fixed on the sky, so each frame only turns them with one
    // matrix, the same one the equatorial grid uses.
    function draw(dc as Graphics.Dc, frame as Lang.Array<Lang.Float>, view as Lang.Array<Lang.Numeric>, lat as Lang.Float, lstDeg as Lang.Double) as Void {
        // Built from the view timer, not here (see PointerView.prepare), so the
        // frame that switches them on does not pay for them on top of its drawing.
        var runs = _vectors;
        if (runs == null || !ready()) {
            return;
        }
        dc.setColor(LINE_COLOR, Graphics.COLOR_TRANSPARENT);
        var rows = SkyMath.equatorialToEnu(lat, lstDeg);
        // A dot on every star, sized to the screen: a radius of 1 on the smallest
        // glass, 3 on the largest.
        var dot = dc.getWidth() / 150;
        // Most figures have no star near the skyline. Those go straight through the
        // watch frame with the rotation folded in, like the equatorial grid, with
        // no work per star beyond the projection. Only a figure with a star in the
        // refraction band is turned star by star, so that star can be lifted.
        var sky = DeviceAim.rotateFrame(frame, rows);
        var i = 0;
        while (i < runs.size()) {
            var run = runs[i];
            if (nearSkyline(run, rows)) {
                DeviceAim.drawRun(dc, frame, enuRun(run, rows), view, dot);
            } else {
                DeviceAim.drawRun(dc, sky, run, view, dot);
            }
            i += 1;
        }
    }

    // Whether every figure has been turned into vectors.
    function ready() as Lang.Boolean {
        return _vectors != null && _pending == null;
    }

    // Turns the next few figures into vectors. Called from the view timer until
    // ready() says they are all done: two hundred stars at once is more than an
    // older watch allows in one event. The degrees are let go of at the end.
    function buildSome() as Void {
        if (_vectors == null) {
            _pending = build();
            _vectors = [];
        }
        var figs = _pending;
        if (figs == null) {
            return;
        }
        var out = _vectors;
        var stop = out.size() + BUILD_CHUNK;
        if (stop > figs.size()) {
            stop = figs.size();
        }
        while (out.size() < stop) {
            var points = figs[out.size()];
            var run = new [points.size() / 2 * 3];
            var i = 0;
            var j = 0;
            while (i < points.size()) {
                var v = SkyMath.raDecToVector(points[i], points[i + 1]);
                run[j] = v[0];
                run[j + 1] = v[1];
                run[j + 2] = v[2];
                i += 2;
                j += 3;
            }
            out.add(run);
        }
        if (out.size() == figs.size()) {
            _pending = null;
        }
    }

    // Whether any star of a figure is in the band where refraction is applied.
    // Only the up component is needed: three multiplications a star.
    function nearSkyline(vecs as Lang.Array<Lang.Float>, rows as Lang.Array<Lang.Float>) as Lang.Boolean {
        var j = 0;
        while (j < vecs.size()) {
            var u = rows[6] * vecs[j] + rows[7] * vecs[j + 1] + rows[8] * vecs[j + 2];
            if (u < REFRACTION_BELOW && u > REFRACTION_UNDER) {
                return true;
            }
            j += 3;
        }
        return false;
    }

    // One figure turned into East-North-Up for this frame.
    //
    // Refraction is applied here, unlike in the grids. A grid line is its own
    // reference and nothing has to agree with it, but these lines have to sit
    // under the stars they join, and those stars are placed through
    // SkyMath.apparentAltitude, which lifts them. Without it Orion's belt draws a
    // couple of pixels below its own three stars as the constellation rises. The
    // lift moves a vertex up its vertical circle, so the up component takes the
    // new altitude and the level part shrinks to match.
    //
    // Parallax is not applied: it is zero for stars, and every vertex here is one.
    function enuRun(vecs as Lang.Array<Lang.Float>, rows as Lang.Array<Lang.Float>) as Lang.Array<Lang.Float> {
        var run = new [vecs.size()];
        var j = 0;
        while (j < vecs.size()) {
            var x = vecs[j];
            var y = vecs[j + 1];
            var z = vecs[j + 2];
            var e = rows[0] * x + rows[1] * y + rows[2] * z;
            var n = rows[3] * x + rows[4] * y + rows[5] * z;
            var u = rows[6] * x + rows[7] * y + rows[8] * z;
            if (u < REFRACTION_BELOW && u > REFRACTION_UNDER) {
                var level = Math.sqrt(e * e + n * n);
                if (level > 0.000001) {
                    var lifted = SkyMath.apparentAltitude(SkyMath.dasin(u), 0.0);
                    var k = SkyMath.dcos(lifted) / level;
                    e = e * k;
                    n = n * k;
                    u = SkyMath.dsin(lifted);
                }
            }
            run[j] = e;
            run[j + 1] = n;
            run[j + 2] = u;
            j += 3;
        }
        return run;
    }
}
