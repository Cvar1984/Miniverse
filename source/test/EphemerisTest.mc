using Toybox.Test;
using Toybox.Math as Math;

// SolarLunar and Planets: the series and orbital elements that give each body's
// position.
//
// Checked against the physical facts they must reproduce rather than against
// recopied decimals: the Sun cannot leave the tropics, the planets cannot leave
// the zodiac, and Kepler's equation has to be solved. Those hold for every date,
// where a single spot value covers one.
// Annotated so the whole module is dropped from release builds. It holds no tests
// itself, only the dates they share, and an un-annotated function in a test file
// is compiled into the shipped app like any other code (416 bytes of it, here).
(:test)
module EphemerisTest {
    // Dates spread across a year and a couple of decades, so nothing passes by
    // happening to be evaluated on one convenient afternoon.
    function samples() {
        return [
            SkyMath.julianDay(2024, 1, 4, 3, 15, 0),
            SkyMath.julianDay(2025, 3, 20, 11, 0, 0),
            SkyMath.julianDay(2026, 6, 21, 18, 45, 0),
            SkyMath.julianDay(2026, 9, 6, 0, 0, 0),
            SkyMath.julianDay(2027, 12, 21, 22, 30, 0),
            SkyMath.julianDay(2031, 8, 9, 7, 5, 0)
        ];
    }
}

// ---------------------------------------------------------------- obliquity

(:test)
function obliquityIsAboutTwentyThreeAndAHalf(logger) {
    var atEpoch = SolarLunar.obliquity(0.0);
    Test.assertMessage((atEpoch - 23.439291).abs() < 0.000001, "obliquity at J2000");

    // It decreases slowly, by about 47 arcseconds a century.
    var aCenturyOn = SolarLunar.obliquity(1.0);
    Test.assertMessage(aCenturyOn < atEpoch, "obliquity should be decreasing");
    Test.assertMessage((atEpoch - aCenturyOn) < 0.02, "but only by arcseconds a century");
    return true;
}

(:test)
function eclipticToEquatorialFixesTheEquinox(logger) {
    // The vernal equinox is where the two frames touch: ecliptic zero maps to
    // equatorial zero whatever the obliquity.
    var equinox = SolarLunar.eclipticToEquatorial(0.0, 0.0, 23.4393);
    Test.assertMessage(SkyMath.norm180(equinox[0]).abs() < 0.0001, "RA should be zero");
    Test.assertMessage(equinox[1].abs() < 0.0001, "declination should be zero");
    return true;
}

(:test)
function eclipticToEquatorialTiltsTheSolstice(logger) {
    // A quarter turn along the ecliptic is the summer solstice, which sits one
    // full obliquity north of the equator.
    var solstice = SolarLunar.eclipticToEquatorial(90.0, 0.0, 23.4393);
    Test.assertMessage((solstice[1] - 23.4393).abs() < 0.0001, "declination should equal the obliquity");
    Test.assertMessage((solstice[0] - 90.0).abs() < 0.0001, "RA should be 90 degrees");
    return true;
}

// ---------------------------------------------------------------- the Sun

(:test)
function sunStaysWithinTheTropics(logger) {
    // The Sun's declination is bounded by the obliquity. If it ever leaves that
    // band the series has gone wrong, whatever else looks right.
    var jds = EphemerisTest.samples();
    var i = 0;
    while (i < jds.size()) {
        var raDec = SolarLunar.sunPosition(jds[i]);
        Test.assertMessage(raDec[1].abs() <= 23.5, "the Sun cannot leave the tropics");
        Test.assertMessage(raDec[0] >= 0.0 && raDec[0] < 360.0, "RA must be normalised");
        i += 1;
    }
    return true;
}

(:test)
function sunReachesTheSolsticesAndEquinoxes(logger) {
    // Near midsummer it is as far north as it goes; near the equinox it is on the
    // celestial equator. Both are dates anyone can check against a calendar.
    var midsummer = SolarLunar.sunPosition(SkyMath.julianDay(2026, 6, 21, 12, 0, 0));
    Test.assertMessage(midsummer[1] > 23.0, "should be near its northern limit at the June solstice");

    var midwinter = SolarLunar.sunPosition(SkyMath.julianDay(2026, 12, 21, 12, 0, 0));
    Test.assertMessage(midwinter[1] < -23.0, "should be near its southern limit at the December solstice");

    var equinox = SolarLunar.sunPosition(SkyMath.julianDay(2026, 3, 20, 12, 0, 0));
    Test.assertMessage(equinox[1].abs() < 1.0, "should be near the equator at the March equinox");
    return true;
}

(:test)
function sunMovesAboutADegreeADay(logger) {
    var jd = SkyMath.julianDay(2026, 4, 10, 0, 0, 0);
    var today = SolarLunar.sunPosition(jd);
    var tomorrow = SolarLunar.sunPosition(jd + 1.0d);
    var moved = SkyMath.norm180(tomorrow[0] - today[0]).abs();
    Test.assertMessage(moved > 0.9 && moved < 1.1, "the Sun should advance about a degree of RA a day");
    return true;
}

// ---------------------------------------------------------------- the Moon

(:test)
function moonStaysNearTheEcliptic(logger) {
    // The Moon's orbit is tilted about 5.1 degrees, so its declination can reach
    // roughly the obliquity plus that, and no further.
    var jds = EphemerisTest.samples();
    var i = 0;
    while (i < jds.size()) {
        var raDec = SolarLunar.moonPosition(jds[i]);
        Test.assertMessage(raDec[1].abs() <= 29.0, "the Moon cannot pass 29 degrees of declination");
        Test.assertMessage(raDec[0] >= 0.0 && raDec[0] < 360.0, "RA must be normalised");
        i += 1;
    }
    return true;
}

(:test)
function moonMovesAboutThirteenDegreesADay(logger) {
    // It laps the sky in roughly 27.3 days, so it moves about 13 degrees a day.
    var jd = SkyMath.julianDay(2026, 5, 2, 0, 0, 0);
    var today = SolarLunar.moonPosition(jd);
    var tomorrow = SolarLunar.moonPosition(jd + 1.0d);
    var moved = SkyMath.norm180(tomorrow[0] - today[0]).abs();
    Test.assertMessage(moved > 11.0 && moved < 15.5, "the Moon should advance about 13 degrees of RA a day");
    return true;
}

(:test)
function moonParallaxStaysInItsRange(logger) {
    // Meeus' series runs about 0.95 degrees, swinging with the Moon's distance.
    // The Moon is the only body where the correction is large enough to apply.
    var jds = EphemerisTest.samples();
    var i = 0;
    while (i < jds.size()) {
        var parallax = SolarLunar.moonHorizontalParallax(jds[i]);
        Test.assertMessage(parallax > 0.85 && parallax < 1.05, "lunar parallax should stay near 0.95 degrees");
        i += 1;
    }
    return true;
}

// ---------------------------------------------------------------- planets

(:test)
function keplersEquationIsActuallySolved(logger) {
    // The Newton iteration returns E; feeding it back through M = E - e sin E has
    // to give back the M that went in, for a circle and for a comet-like ellipse
    // alike.
    var eccentricities = [0.0, 0.0068, 0.0934, 0.2056, 0.6];
    var e = 0;
    while (e < eccentricities.size()) {
        var ecc = eccentricities[e];
        var m = 5.0;
        while (m < 360.0) {
            var eAnom = Planets.eccentricAnomaly(m, ecc);
            var backToM = eAnom - SkyMath.RAD2DEG * ecc * SkyMath.dsin(eAnom);
            Test.assertMessage(SkyMath.norm180(backToM - m).abs() < 0.001, "Kepler's equation should be satisfied");
            m += 55.0;
        }
        e += 1;
    }
    return true;
}

(:test)
function keplersEquationHandlesACircle(logger) {
    // Zero eccentricity is the degenerate case: the eccentric anomaly is the mean
    // anomaly, with nothing to iterate towards.
    var eAnom = Planets.eccentricAnomaly(137.0, 0.0);
    Test.assertMessage((eAnom - 137.0).abs() < 0.0001, "a circular orbit needs no correction");
    return true;
}

(:test)
function planetsStayInTheZodiac(logger) {
    // Every planet here orbits within a few degrees of the ecliptic, so none can
    // stray far in latitude. Mercury is the worst at about 7 degrees.
    var ids = ["mercury", "venus", "mars", "jupiter", "saturn"];
    var jds = EphemerisTest.samples();
    var p = 0;
    while (p < ids.size()) {
        var i = 0;
        while (i < jds.size()) {
            var raDec = Planets.planetPosition(ids[p], jds[i]);
            Test.assertMessage(raDec[0] >= 0.0 && raDec[0] < 360.0, "RA must be normalised");
            // Declination is bounded by the obliquity plus the orbital tilt.
            Test.assertMessage(raDec[1].abs() < 31.0, "a planet cannot leave the zodiac band");
            i += 1;
        }
        p += 1;
    }
    return true;
}

(:test)
function innerPlanetsNeverStrayFarFromTheSun(logger) {
    // Mercury and Venus are between us and the Sun, so their elongation is capped
    // at about 28 and 47 degrees. This catches a heliocentric-to-geocentric shift
    // that has been left out or applied the wrong way round, which a bounds check
    // on RA alone would sail straight past.
    var jds = EphemerisTest.samples();
    var i = 0;
    while (i < jds.size()) {
        var jd = jds[i];
        var sun = SolarLunar.sunPosition(jd);
        var sunVec = SkyMath.raDecToEnu(sun[0], sun[1], 0.0, 0.0);

        var venus = Planets.planetPosition("venus", jd);
        var venusVec = SkyMath.raDecToEnu(venus[0], venus[1], 0.0, 0.0);
        var dot = sunVec[0] * venusVec[0] + sunVec[1] * venusVec[1] + sunVec[2] * venusVec[2];
        Test.assertMessage(SkyMath.dacos(dot) < 50.0, "Venus cannot be more than about 47 degrees from the Sun");

        var mercury = Planets.planetPosition("mercury", jd);
        var mercuryVec = SkyMath.raDecToEnu(mercury[0], mercury[1], 0.0, 0.0);
        var mDot = sunVec[0] * mercuryVec[0] + sunVec[1] * mercuryVec[1] + sunVec[2] * mercuryVec[2];
        Test.assertMessage(SkyMath.dacos(mDot) < 32.0, "Mercury cannot be more than about 28 degrees from the Sun");
        i += 1;
    }
    return true;
}

(:test)
function outerPlanetsMoveSlowlyAgainstTheStars(logger) {
    // Saturn takes 29 years to go round, so it cannot shift more than a fraction
    // of a degree in a day even at its fastest.
    var jd = SkyMath.julianDay(2026, 2, 17, 0, 0, 0);
    var today = Planets.planetPosition("saturn", jd);
    var tomorrow = Planets.planetPosition("saturn", jd + 1.0d);
    var moved = SkyMath.norm180(tomorrow[0] - today[0]).abs();
    Test.assertMessage(moved < 0.5, "Saturn should barely move in a day");
    return true;
}
