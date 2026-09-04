using Toybox.Math as Math;

// Low-precision Sun and Moon geocentric apparent positions (Meeus, abbreviated series).
// Accuracy is well within what a wrist compass/magnetometer can resolve.
module SolarLunar {
    function centuriesSinceJ2000(jd) {
        // Double: subtracting the epoch is what brings a Julian Day back down to
        // a size a Float could hold, so the subtraction itself has to be exact.
        return (jd - 2451545.0d) / 36525.0d;
    }

    function obliquity(t) {
        return 23.439291 - 0.0130042 * t - 0.00000016 * t * t + 0.000000504 * t * t * t;
    }

    // Ecliptic longitude/latitude (deg) + obliquity (deg) -> [ra, dec] in degrees.
    function eclipticToEquatorial(lonDeg, latDeg, epsDeg) {
        var sinDec = SkyMath.dsin(latDeg) * SkyMath.dcos(epsDeg) + SkyMath.dcos(latDeg) * SkyMath.dsin(epsDeg) * SkyMath.dsin(lonDeg);
        var dec = SkyMath.dasin(sinDec);
        var y = SkyMath.dsin(lonDeg) * SkyMath.dcos(epsDeg) - SkyMath.dtan(latDeg) * SkyMath.dsin(epsDeg);
        var x = SkyMath.dcos(lonDeg);
        var ra = SkyMath.norm360(SkyMath.datan2(y, x));
        return [ra, dec];
    }

    // Returns [ra, dec] in degrees for the given Julian Day (UTC).
    function sunPosition(jd) {
        var t = centuriesSinceJ2000(jd);
        var l0 = SkyMath.norm360(280.46646 + 36000.76983 * t + 0.0003032 * t * t);
        var m = SkyMath.norm360(357.52911 + 35999.05029 * t - 0.0001537 * t * t);
        var c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * SkyMath.dsin(m)
              + (0.019993 - 0.000101 * t) * SkyMath.dsin(2 * m)
              + 0.000289 * SkyMath.dsin(3 * m);
        var trueLon = l0 + c;
        var omega = 125.04 - 1934.136 * t;
        var lambda = trueLon - 0.00569 - 0.00478 * SkyMath.dsin(omega);
        var eps0 = obliquity(t);
        var eps = eps0 + 0.00256 * SkyMath.dcos(omega);
        return eclipticToEquatorial(lambda, 0.0, eps);
    }

    // The Moon's horizontal parallax in degrees: how far its apparent place shifts
    // between Earth's centre, which moonPosition works from, and a watch on the
    // surface 6378 km off that centre. It runs to about 0.95 degrees, roughly two
    // full-Moon widths, which makes it the one body where the difference is worth
    // correcting - see SkyMath.apparentAltitude.
    //
    // Meeus' parallax series. Earth's polar radius is 0.34% shorter than its
    // equatorial one, which would move this by about 12 arcseconds; that is far
    // below anything a wrist compass can resolve, so the flattening is ignored.
    function moonHorizontalParallax(jd) {
        var t = centuriesSinceJ2000(jd);
        var d  = SkyMath.norm360(297.8501921 + 445267.1114034 * t - 0.0018819 * t * t);
        var mp = SkyMath.norm360(134.9633964 + 477198.8675055 * t + 0.0087414 * t * t);

        return 0.9508
             + 0.0518 * SkyMath.dcos(mp)
             + 0.0095 * SkyMath.dcos(2 * d - mp)
             + 0.0078 * SkyMath.dcos(2 * d)
             + 0.0028 * SkyMath.dcos(2 * mp);
    }

    // Returns [ra, dec] in degrees for the given Julian Day (UTC).
    function moonPosition(jd) {
        var t = centuriesSinceJ2000(jd);

        var lp = SkyMath.norm360(218.3164477 + 481267.88123421 * t - 0.0015786 * t * t);
        var d  = SkyMath.norm360(297.8501921 + 445267.1114034 * t - 0.0018819 * t * t);
        var m  = SkyMath.norm360(357.5291092 + 35999.0502909 * t - 0.0001536 * t * t);
        var mp = SkyMath.norm360(134.9633964 + 477198.8675055 * t + 0.0087414 * t * t);
        var f  = SkyMath.norm360(93.2720950 + 483202.0175233 * t - 0.0036539 * t * t);

        var dl = 6.288774 * SkyMath.dsin(mp)
               + 1.274027 * SkyMath.dsin(2 * d - mp)
               + 0.658314 * SkyMath.dsin(2 * d)
               + 0.213618 * SkyMath.dsin(2 * mp)
               - 0.185116 * SkyMath.dsin(m)
               - 0.114332 * SkyMath.dsin(2 * f)
               + 0.058793 * SkyMath.dsin(2 * d - 2 * mp)
               + 0.057066 * SkyMath.dsin(2 * d - m - mp)
               + 0.053322 * SkyMath.dsin(2 * d + mp)
               + 0.045758 * SkyMath.dsin(2 * d - m)
               - 0.040923 * SkyMath.dsin(m - mp)
               - 0.034720 * SkyMath.dsin(d)
               - 0.030383 * SkyMath.dsin(m + mp);

        var db = 5.128122 * SkyMath.dsin(f)
               + 0.280602 * SkyMath.dsin(mp + f)
               + 0.277693 * SkyMath.dsin(mp - f)
               + 0.173237 * SkyMath.dsin(2 * d - f)
               + 0.055413 * SkyMath.dsin(2 * d - mp + f)
               + 0.046271 * SkyMath.dsin(2 * d - mp - f)
               + 0.032573 * SkyMath.dsin(2 * d + f)
               + 0.017198 * SkyMath.dsin(2 * mp)
               + 0.009266 * SkyMath.dsin(2 * d + mp - f)
               + 0.008822 * SkyMath.dsin(2 * d - 2 * mp);

        var lonMoon = SkyMath.norm360(lp + dl);
        var latMoon = db;
        var eps = obliquity(t);
        return eclipticToEquatorial(lonMoon, latMoon, eps);
    }
}
