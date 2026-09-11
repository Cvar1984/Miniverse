using Toybox.Test;
using Toybox.Math as Math;

// DeviceAim: gravity, the tilt-compensated compass, the frame they build, and the
// projection onto the screen.
//
// This is where the app's sign conventions live. A wrong back-of-case sign turns
// both screen axes over at once and makes the object follow the watch instead of
// sliding against it; the orthonormality and round-trip checks below catch that.

// ---------------------------------------------------------------- gravity

(:test)
function upVectorNormalisesAndInverts(logger) {
    // The device reports the gravity direction, so "up" is the negation of it.
    // Screen facing the sky means the accelerometer reads downward.
    var up = DeviceAim.upVector([0, 0, -1000]);
    Test.assertMessage(up != null, "a full-strength reading should be usable");
    Test.assertMessage(up[2] > 0.99, "negating a downward reading should give up");
    var len = Math.sqrt(up[0] * up[0] + up[1] * up[1] + up[2] * up[2]);
    Test.assertMessage((len - 1.0).abs() < 0.000001, "up must be a unit vector");
    return true;
}

(:test)
function upVectorRejectsAnUnusableReading(logger) {
    // Free fall, or a sensor that has not woken up yet: there is no down to find.
    Test.assertMessage(DeviceAim.upVector([0, 0, 0]) == null, "a zero reading has no up in it");
    return true;
}

(:test)
function aimElevationReadsTheBackOfTheCase(logger) {
    // Watch flat on a table, screen up: the back faces the ground, so the aim
    // points at the nadir and the elevation is fully negative.
    var flat = DeviceAim.aimElevation([0, 0, -1000]);
    Test.assertMessage(flat != null && (flat + 90.0).abs() < 0.001, "screen up means the aim points straight down");

    // Held up with the back to the sky: the aim is at the zenith.
    var raised = DeviceAim.aimElevation([0, 0, 1000]);
    Test.assertMessage(raised != null && (raised - 90.0).abs() < 0.001, "screen down means the aim points straight up");

    // On edge, back to the horizon: level.
    var level = DeviceAim.aimElevation([0, -1000, 0]);
    Test.assertMessage(level != null && level.abs() < 0.001, "on edge the aim should be level");
    return true;
}

// ---------------------------------------------------------------- the frame

(:test)
function deviceFrameIsOrthonormal(logger) {
    // East, north and up must stay a right-angled set of unit vectors however the
    // watch is held, or every direction drawn through it comes out skewed.
    var accels = [[0, 0, -1000], [0, -1000, 0], [700, 0, -700], [-500, 500, -700]];
    var mags = [[300, 0, 0], [0, 400, 100], [120, -260, 80]];

    var a = 0;
    while (a < accels.size()) {
        var m = 0;
        while (m < mags.size()) {
            var frame = DeviceAim.deviceFrame(accels[a], mags[m], 0.0);
            if (frame != null) {
                var eLen = Math.sqrt(frame[0] * frame[0] + frame[1] * frame[1] + frame[2] * frame[2]);
                var nLen = Math.sqrt(frame[3] * frame[3] + frame[4] * frame[4] + frame[5] * frame[5]);
                var uLen = Math.sqrt(frame[6] * frame[6] + frame[7] * frame[7] + frame[8] * frame[8]);
                Test.assertMessage((eLen - 1.0).abs() < 0.0001, "east must be unit length");
                Test.assertMessage((nLen - 1.0).abs() < 0.0001, "north must be unit length");
                Test.assertMessage((uLen - 1.0).abs() < 0.0001, "up must be unit length");

                var en = frame[0] * frame[3] + frame[1] * frame[4] + frame[2] * frame[5];
                var eu = frame[0] * frame[6] + frame[1] * frame[7] + frame[2] * frame[8];
                var nu = frame[3] * frame[6] + frame[4] * frame[7] + frame[5] * frame[8];
                Test.assertMessage(en.abs() < 0.0001, "east and north must be perpendicular");
                Test.assertMessage(eu.abs() < 0.0001, "east and up must be perpendicular");
                Test.assertMessage(nu.abs() < 0.0001, "north and up must be perpendicular");
            }
            m += 1;
        }
        a += 1;
    }
    return true;
}

(:test)
function declinationTurnsTheFrameByExactlyThatMuch(logger) {
    // The true-north correction. Passing a declination has to swing north round by
    // that angle and nothing else, and the frame has to stay orthonormal doing it.
    //
    // Without it the whole drawn sky rotates away from the numbers printed
    // underneath it.
    var accel = [200, -300, -900];
    var mag = [150, 220, -60];

    var plain = DeviceAim.deviceFrame(accel, mag, 0.0);
    var swung = DeviceAim.deviceFrame(accel, mag, 12.0);
    Test.assertMessage(plain != null && swung != null, "both frames should build");

    var dot = plain[3] * swung[3] + plain[4] * swung[4] + plain[5] * swung[5];
    var between = SkyMath.dacos(dot);
    Test.assertMessage((between - 12.0).abs() < 0.01, "north should move by the declination given");

    // Up is vertical and has no business moving.
    var upDot = plain[6] * swung[6] + plain[7] * swung[7] + plain[8] * swung[8];
    Test.assertMessage((upDot - 1.0).abs() < 0.0001, "up must not be touched by declination");

    var eLen = Math.sqrt(swung[0] * swung[0] + swung[1] * swung[1] + swung[2] * swung[2]);
    Test.assertMessage((eLen - 1.0).abs() < 0.0001, "east must stay unit length after the swing");
    return true;
}

(:test)
function zeroDeclinationChangesNothing(logger) {
    var accel = [0, -400, -900];
    var mag = [310, 40, -120];
    var frame = DeviceAim.deviceFrame(accel, mag, 0.0);
    Test.assertMessage(frame != null, "frame should build");

    // North with no declination must still be the flattened magnetic north.
    var up = DeviceAim.upVector(accel);
    var north = DeviceAim.northVector(mag, up[0], up[1], up[2]);
    Test.assertMessage((frame[3] - north[0]).abs() < 0.000001, "north should be untouched");
    Test.assertMessage((frame[4] - north[1]).abs() < 0.000001, "north should be untouched");
    Test.assertMessage((frame[5] - north[2]).abs() < 0.000001, "north should be untouched");
    return true;
}

(:test)
function northVectorHasNoVerticalPartLeft(logger) {
    // Removing the field's vertical component is how the tilt-compensated compass
    // works: what is left points north however the watch tilts.
    var up = DeviceAim.upVector([300, -200, -900]);
    var north = DeviceAim.northVector([180, 240, -90], up[0], up[1], up[2]);
    Test.assertMessage(north != null, "should produce a north");
    var alongUp = north[0] * up[0] + north[1] * up[1] + north[2] * up[2];
    Test.assertMessage(alongUp.abs() < 0.0001, "north must lie flat against gravity");
    return true;
}

// ---------------------------------------------------------------- projection

(:test)
function viewOffsetPreservesLength(logger) {
    // It is a rotation with one axis flipped, so it can turn a direction round but
    // never stretch it.
    var frame = DeviceAim.deviceFrame([100, -250, -950], [200, 150, -50], 0.0);
    Test.assertMessage(frame != null, "frame should build");

    var enu = SkyMath.horizontalToEnu(217.0, 34.0);
    var offset = DeviceAim.viewOffset(frame, enu[0], enu[1], enu[2]);
    var len = Math.sqrt(offset[0] * offset[0] + offset[1] * offset[1] + offset[2] * offset[2]);
    Test.assertMessage((len - 1.0).abs() < 0.0001, "the rotation must preserve length");
    return true;
}

(:test)
function screenPointDropsWhatIsBehindTheWatch(logger) {
    // Beyond about 84 degrees off the aim a perspective divide has nothing to say,
    // and returning null there is what breaks grid lines cleanly instead of
    // folding them back across the view.
    var frame = DeviceAim.deviceFrame([0, 0, -1000], [300, 0, 0], 0.0);
    Test.assertMessage(frame != null, "frame should build");

    // Screen up means the aim is at the nadir, so the zenith is directly behind.
    var behind = DeviceAim.screenPoint(frame, 0.0, 0.0, 1.0, [100, 100, 100]);
    Test.assertMessage(behind == null, "a direction behind the watch should be dropped");

    // And the nadir itself is straight down the aim axis, so it lands dead centre.
    var ahead = DeviceAim.screenPoint(frame, 0.0, 0.0, -1.0, [100, 100, 100]);
    Test.assertMessage(ahead != null, "the aim direction itself should project");
    Test.assertMessage((ahead[0] - 100).abs() <= 1, "should land on the centre x");
    Test.assertMessage((ahead[1] - 100).abs() <= 1, "should land on the centre y");
    return true;
}

// ---------------------------------------------------------------- guidance

(:test)
function guidanceIsZeroWhenAlreadyOnTheObject(logger) {
    // Turn and tilt are measured from the aim, so pointing at the thing means
    // there is nothing left to say.
    var basis = DeviceAim.aimBasis(20.0, 137.0);
    Test.assertMessage(basis != null, "a level-ish aim should have a basis");

    var aimed = DeviceAim.project(basis, basis[0], basis[1], basis[2]);
    Test.assertMessage(aimed[0].abs() < 0.001, "no turn needed");
    Test.assertMessage(aimed[1].abs() < 0.001, "no tilt needed");
    Test.assertMessage((aimed[2] - 1.0).abs() < 0.001, "and it is straight ahead");
    return true;
}

(:test)
function guidenceSignsPointTheRightWay(logger) {
    // Due north, level. Something to the east should read as a turn to the right;
    // something higher should read as a tilt up.
    var basis = DeviceAim.aimBasis(0.0, 0.0);
    Test.assertMessage(basis != null, "a level aim should have a basis");

    var east = SkyMath.horizontalToEnu(45.0, 0.0);
    var toTheEast = DeviceAim.project(basis, east[0], east[1], east[2]);
    Test.assertMessage(toTheEast[0] > 0.0, "east of north should be a turn right");

    var high = SkyMath.horizontalToEnu(0.0, 30.0);
    var above = DeviceAim.project(basis, high[0], high[1], high[2]);
    Test.assertMessage(above[1] > 0.0, "higher up should be a tilt up");
    Test.assertMessage((above[1] - 30.0).abs() < 0.001, "and by the angle it is above");
    return true;
}

(:test)
function aimBasisGivesUpWhenAimedStraightUp(logger) {
    // Within a couple of degrees of vertical there is no "right" to point at, and
    // the guidance lines drop out rather than inventing one.
    Test.assertMessage(DeviceAim.aimBasis(90.0, 0.0) == null, "straight up has no horizontal basis");
    Test.assertMessage(DeviceAim.aimBasis(-90.0, 0.0) == null, "straight down has no horizontal basis");
    Test.assertMessage(DeviceAim.aimBasis(45.0, 0.0) != null, "a slanted aim still has one");
    return true;
}

// Folding a rotation into the frame has to land every point exactly where
// rotating it first and projecting it after would.
(:test)
function rotatedFrameProjectsLikeTheTwoSteps(logger) {
    var frame = DeviceAim.deviceFrame([0, -400, -900], [310, 40, -120], 0.0);
    Test.assertMessage(frame != null, "frame should build");
    var rows = SkyMath.equatorialToEnu(51.5, 100.0);
    var turned = DeviceAim.rotateFrame(frame, rows);
    var v = SkyMath.raDecToVector(83.8, -5.4);
    var e = rows[0] * v[0] + rows[1] * v[1] + rows[2] * v[2];
    var n = rows[3] * v[0] + rows[4] * v[1] + rows[5] * v[2];
    var u = rows[6] * v[0] + rows[7] * v[1] + rows[8] * v[2];
    var direct = DeviceAim.viewOffset(frame, e, n, u);
    var folded = DeviceAim.viewOffset(turned, v[0], v[1], v[2]);
    var k = 0;
    while (k < 3) {
        Test.assertMessage((direct[k] - folded[k]).abs() < 0.00001, "folded and two-step projections should agree");
        k += 1;
    }
    return true;
}
