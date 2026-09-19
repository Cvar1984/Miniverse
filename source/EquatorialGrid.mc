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
// It has no points of its own. A horizon-grid point with its first two parts
// swapped is exactly the equatorial unit vector with right ascension equal to the
// azimuth and declination equal to the altitude, and the two grids share their
// limits and sampling. So the horizon grid's mesh for the same spacing is this
// grid's too: swapping the first two columns of the equatorial rotation swaps
// every point at once, and folded into the watch axes that leaves nine
// multiplications a point. When both grids use the same spacing they share one
// mesh. Refraction is not applied: it is a fraction of a degree at the horizon
// and nothing higher up, under the width of these lines.
module EquatorialGrid {
    // Blue, so this tells apart at a glance from the green HorizonGrid draws.
    const LINE_COLOR = Graphics.COLOR_DK_BLUE;

    // view is [cx, cy, focal], the same screen mapping everything else uses. step
    // is the spacing between lines in degrees, and 0 draws nothing: right ascension
    // runs round the same 360 degrees as azimuth does, so a step of 15 puts the
    // hour circles one hour of right ascension apart.
    //
    // lat and lstDeg tie this frame to the sky overhead, and a changing lstDeg is
    // what makes this grid move.
    function draw(dc as Graphics.Dc, frame as Lang.Array<Lang.Float>, view as Lang.Array<Lang.Numeric>, step as Lang.Number, lat as Lang.Float, lstDeg as Lang.Double) as Void {
        // Built from the view timer (see PointerView.prepare), never here.
        if (step <= 0 || !HorizonGrid.ready(step)) {
            return;
        }
        var mesh = HorizonGrid.meshFor(step);
        var r = SkyMath.equatorialToEnu(lat, lstDeg);
        var sky = DeviceAim.rotateFrame(frame, [r[1], r[0], r[2], r[4], r[3], r[5], r[7], r[6], r[8]]);
        dc.setColor(Palette.shown(LINE_COLOR), Graphics.COLOR_TRANSPARENT);
        var i = 0;
        while (i < mesh.size()) {
            DeviceAim.drawRun(dc, sky, mesh[i], view, 0);
            i += 1;
        }
    }
}
