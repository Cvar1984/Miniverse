using Toybox.Test;
using Toybox.Math as Math;

// SkyMath: time, coordinate conversion and the two atmospheric corrections.
//
// Written as invariants wherever one exists - a zenith is a zenith at every
// latitude, a rotation preserves length, the two routes to a vector must agree -
// because an invariant keeps testing after someone changes a constant, and a
// hand-copied decimal only ever tests that it was copied correctly.

// ---------------------------------------------------------------- angles

(:test)
function norm360WrapsBothWays(logger) {
    Test.assertMessage((SkyMath.norm360(-10.0) - 350.0).abs() < 0.000001, "-10 should wrap to 350");
    Test.assertMessage((SkyMath.norm360(370.0) - 10.0).abs() < 0.000001, "370 should wrap to 10");
    Test.assertMessage(SkyMath.norm360(360.0) < 0.000001, "360 should wrap to 0");
    Test.assertMessage((SkyMath.norm360(-730.0) - 350.0).abs() < 0.000001, "should wrap repeatedly");
    return true;
}

(:test)
function norm180SignsTheShortWayRound(logger) {
    // This is what stops the heading smoothing swinging backwards through 358
    // when it crosses north.
    Test.assertMessage((SkyMath.norm180(350.0) + 10.0).abs() < 0.000001, "350 should read as -10");
    Test.assertMessage((SkyMath.norm180(190.0) + 170.0).abs() < 0.000001, "190 should read as -170");
    Test.assertMessage((SkyMath.norm180(10.0) - 10.0).abs() < 0.000001, "10 should stay 10");
    return true;
}

// ---------------------------------------------------------------- time

(:test)
function julianDayHitsTheJ2000Epoch(logger) {
    // Noon on 1 January 2000 UTC is the definition of JD 2451545.0.
    var jd = SkyMath.julianDay(2000, 1, 1, 12, 0, 0);
    Test.assertMessage((jd - 2451545.0d).abs() < 0.0000001, "J2000 epoch should be JD 2451545.0");
    return true;
}

(:test)
function julianDayAdvancesOnePerDay(logger) {
    var a = SkyMath.julianDay(2026, 3, 14, 0, 0, 0);
    var b = SkyMath.julianDay(2026, 3, 15, 0, 0, 0);
    Test.assertMessage((b - a - 1.0d).abs() < 0.0000001, "consecutive days should differ by exactly 1");
    return true;
}

(:test)
function julianDayCrossesTheMarchBoundary(logger) {
    // January and February are counted as months 13 and 14 of the previous year,
    // so the turn of March is the branch worth pinning down.
    var feb = SkyMath.julianDay(2026, 2, 28, 0, 0, 0);
    var mar = SkyMath.julianDay(2026, 3, 1, 0, 0, 0);
    Test.assertMessage((mar - feb - 1.0d).abs() < 0.0000001, "2026 is not a leap year, so 28 Feb to 1 Mar is one day");
    return true;
}

(:test)
function julianDayKeepsTheTimeOfDay(logger) {
    // The regression test for the precision bug this app was written around: a
    // 32-bit float carries about seven digits, so a Julian Day near 2.46 million
    // rounds the time of day to the nearest six hours and whole evenings collapse
    // onto one stored value. Six hours must come out as exactly a quarter day.
    var midnight = SkyMath.julianDay(2026, 9, 6, 0, 0, 0);
    var sixAm = SkyMath.julianDay(2026, 9, 6, 6, 0, 0);
    Test.assertMessage((sixAm - midnight - 0.25d).abs() < 0.0000001, "six hours should be a quarter of a day");

    // And a single minute has to survive as well.
    var oneMinute = SkyMath.julianDay(2026, 9, 6, 0, 1, 0);
    Test.assertMessage(oneMinute > midnight, "one minute must not round away");
    return true;
}

(:test)
function siderealTimeAdvancesFasterThanTheClock(logger) {
    // The sky turns slightly more than 360 degrees per solar day, which is why a
    // star rises about four minutes earlier each night.
    var jd = SkyMath.julianDay(2026, 9, 6, 0, 0, 0);
    var today = SkyMath.gmst(jd);
    var tomorrow = SkyMath.gmst(jd + 1.0d);
    var gained = SkyMath.norm360(tomorrow - today);
    Test.assertMessage(gained > 0.9 && gained < 1.1, "a solar day should gain about one degree of sidereal time");
    return true;
}

(:test)
function localSiderealTimeIsOffsetByLongitude(logger) {
    var jd = SkyMath.julianDay(2026, 9, 6, 3, 30, 0);
    var greenwich = SkyMath.lst(jd, 0.0);
    var east = SkyMath.lst(jd, 45.0);
    Test.assertMessage((SkyMath.norm360(east - greenwich) - 45.0).abs() < 0.0001, "east longitude should add directly");
    return true;
}

// ---------------------------------------------------------------- coordinates

(:test)
function horizontalToEnuReturnsUnitVectors(logger) {
    var az = 0.0;
    while (az < 360.0) {
        var alt = -80.0;
        while (alt <= 80.0) {
            var v = SkyMath.horizontalToEnu(az, alt);
            var len = Math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
            Test.assertMessage((len - 1.0).abs() < 0.000001, "ENU vectors must be unit length");
            alt += 40.0;
        }
        az += 45.0;
    }
    return true;
}

(:test)
function anObjectOnTheMeridianAtYourLatitudeIsOverhead(logger) {
    // Declination equal to latitude, hour angle zero: that is the zenith, at every
    // latitude, with no exceptions to remember.
    var lats = [-60.0, -23.5, 0.0, 12.0, 51.5, 78.0];
    var i = 0;
    while (i < lats.size()) {
        var lat = lats[i];
        var altAz = SkyMath.raDecToAltAz(100.0, lat, lat, 100.0);
        Test.assertMessage((altAz[0] - 90.0).abs() < 0.001, "should be at the zenith");
        i += 1;
    }
    return true;
}

(:test)
function azimuthPicksTheRightSideOfTheMeridian(logger) {
    // acos cannot tell east from west; the sign of sin(H) is what resolves it.
    // A positive hour angle means the object has already crossed and is setting.
    var west = SkyMath.raDecToAltAz(0.0, 0.0, 45.0, 90.0);
    Test.assertMessage(west[1] > 180.0, "positive hour angle should place the object west");

    var east = SkyMath.raDecToAltAz(0.0, 0.0, 45.0, 270.0);
    Test.assertMessage(east[1] < 180.0, "negative hour angle should place the object east");
    return true;
}

(:test)
function poleSitsAtAltitudeEqualToLatitude(logger) {
    // The celestial pole is the one fixed point in the sky, and its height above
    // the horizon is your latitude. True whatever the time.
    var altAz = SkyMath.raDecToAltAz(0.0, 90.0, 51.5, 217.0);
    Test.assertMessage((altAz[0] - 51.5).abs() < 0.001, "the pole should sit at the observer latitude");
    return true;
}

(:test)
function raDecToEnuAgreesWithTheTwoStepRoute(logger) {
    // The direct rotation replaced raDecToAltAz followed by horizontalToEnu in the
    // grid's hot loop. It has to give the same answer everywhere, including over
    // the poles where the arccosine it drops is least well behaved.
    var ra = 0.0;
    while (ra < 360.0) {
        var dec = -85.0;
        while (dec <= 85.0) {
            var lat = -70.0;
            while (lat <= 70.0) {
                var lst = ra + 37.0;
                var direct = SkyMath.raDecToEnu(ra, dec, lat, lst);
                var altAz = SkyMath.raDecToAltAz(ra, dec, lat, lst);
                var stepped = SkyMath.horizontalToEnu(altAz[1], altAz[0]);

                var dx = direct[0] - stepped[0];
                var dy = direct[1] - stepped[1];
                var dz = direct[2] - stepped[2];
                var apart = Math.sqrt(dx * dx + dy * dy + dz * dz);
                Test.assertMessage(apart < 0.0001, "the two routes must agree");
                lat += 35.0;
            }
            dec += 42.5;
        }
        ra += 60.0;
    }
    return true;
}

(:test)
function raDecToEnuReturnsUnitVectors(logger) {
    var v = SkyMath.raDecToEnu(123.0, -41.0, 33.0, 250.0);
    var len = Math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    Test.assertMessage((len - 1.0).abs() < 0.000001, "must be unit length");
    return true;
}

// ---------------------------------------------------------------- corrections

(:test)
function refractionIsLargestAtTheHorizon(logger) {
    var horizon = SkyMath.refraction(0.0);
    Test.assertMessage(horizon > 0.55 && horizon < 0.60, "Bennett gives about 0.57 degrees at the horizon");

    var tenUp = SkyMath.refraction(10.0);
    Test.assertMessage(tenUp > 0.05 && tenUp < 0.15, "about 0.09 degrees ten degrees up");

    Test.assertMessage(horizon > tenUp, "refraction must fall off with altitude");
    return true;
}

(:test)
function refractionFallsOffMonotonically(logger) {
    var previous = SkyMath.refraction(0.0);
    var alt = 5.0;
    while (alt <= 85.0) {
        var here = SkyMath.refraction(alt);
        Test.assertMessage(here <= previous, "refraction must never increase with altitude");
        previous = here;
        alt += 5.0;
    }
    return true;
}

(:test)
function refractionIsZeroWellBelowTheHorizon(logger) {
    // The guard branch: far under the horizon the formula has nothing to say.
    Test.assertMessage(SkyMath.refraction(-5.0) == 0.0, "should be zero below -2 degrees");
    Test.assertMessage(SkyMath.refraction(90.0) == 0.0, "should be zero straight overhead");
    return true;
}

(:test)
function refractionLiftsAnObjectOnTheHorizon(logger) {
    // Why the Sun is still visibly up when it has geometrically already set.
    var apparent = SkyMath.apparentAltitude(0.0, 0.0);
    Test.assertMessage(apparent > 0.5, "an object on the geometric horizon should appear above it");
    return true;
}

(:test)
function parallaxPushesTheMoonDown(logger) {
    // Worked from Earth's centre the Moon sits nearly a degree higher than it does
    // from the surface, and that correction has to lower it.
    var withParallax = SkyMath.apparentAltitude(45.0, 0.95);
    var without = SkyMath.apparentAltitude(45.0, 0.0);
    Test.assertMessage(withParallax < without, "parallax must lower the apparent altitude");
    Test.assertMessage((without - withParallax) > 0.5, "at 45 degrees it should be most of the parallax");
    return true;
}

(:test)
function parallaxVanishesAtTheZenith(logger) {
    // It acts along the vertical circle and scales with the cosine of altitude, so
    // straight overhead there is nothing to correct.
    var overhead = SkyMath.apparentAltitude(90.0, 0.95);
    Test.assertMessage((overhead - 90.0).abs() < 0.01, "no parallax shift at the zenith");
    return true;
}

// ---------------------------------------------------------------- the grid mesh

// HorizonGrid builds its geometry once and keeps it. The cache and its
// invalidation are new logic with a branch in them, and they need no graphics
// context to exercise - only the drawing of the mesh does.

(:test)
function meshHoldsWellFormedRuns(logger) {
    var mesh = HorizonGrid.meshFor(15);
    Test.assertMessage(mesh.size() > 0, "there should be lines to draw");

    var i = 0;
    while (i < mesh.size()) {
        var line = mesh[i];
        Test.assertMessage(line.size() == 2, "each line is a colour and a run");

        var run = line[1];
        Test.assertMessage(run.size() % 3 == 0, "points must come in whole triples");
        Test.assertMessage(run.size() >= 6, "a run needs two points to be a line");

        // Every triple has to be a unit vector, or the projection skews it.
        var j = 0;
        while (j < run.size()) {
            var len = Math.sqrt(run[j] * run[j] + run[j + 1] * run[j + 1] + run[j + 2] * run[j + 2]);
            Test.assertMessage((len - 1.0).abs() < 0.0001, "mesh points must be unit vectors");
            j += 3;
        }
        i += 1;
    }
    return true;
}

(:test)
function meshHasTheRightNumberOfLines(logger) {
    // At 15 degrees: 24 vertical circles, and altitude circles counted outwards
    // from the horizon to 60 degrees, which is the horizon plus four either side.
    var mesh = HorizonGrid.meshFor(15);
    Test.assertMessage(mesh.size() == 24 + 9, "24 vertical and 9 altitude circles at 15 degrees");

    // Coarser spacing must give fewer lines, and it must not keep the old ones.
    var coarse = HorizonGrid.meshFor(60);
    Test.assertMessage(coarse.size() == 6 + 3, "6 vertical and 3 altitude circles at 60 degrees");
    return true;
}

(:test)
function meshIsCachedUntilTheSpacingChanges(logger) {
    // Rebuilding this every frame was the most expensive thing the app did, so the
    // cache holding is the point of it.
    var first = HorizonGrid.meshFor(30);
    var again = HorizonGrid.meshFor(30);
    Test.assertMessage(first.size() == again.size(), "the same spacing should give the same mesh back");

    var changed = HorizonGrid.meshFor(45);
    Test.assertMessage(changed.size() != first.size(), "a new spacing must rebuild");

    var back = HorizonGrid.meshFor(30);
    Test.assertMessage(back.size() == first.size(), "and going back must rebuild again");
    return true;
}

(:test)
function meshAlwaysIncludesTheHorizon(logger) {
    // Altitude circles count outwards from zero precisely so the horizon survives
    // every spacing, including ones that do not divide into the 60 degree limit.
    var steps = [10, 15, 30, 45, 60];
    var s = 0;
    while (s < steps.size()) {
        var mesh = HorizonGrid.meshFor(steps[s]);
        var found = false;
        var i = 0;
        while (i < mesh.size()) {
            // A run lying flat on the horizon has zero up-component throughout.
            var run = mesh[i][1];
            var flat = true;
            var j = 2;
            while (j < run.size()) {
                if (run[j].abs() > 0.0001) {
                    flat = false;
                }
                j += 3;
            }
            if (flat) {
                found = true;
            }
            i += 1;
        }
        Test.assertMessage(found, "the horizon must be drawn at every spacing");
        s += 1;
    }
    return true;
}
