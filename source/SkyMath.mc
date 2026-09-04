using Toybox.Math as Math;
using Toybox.Lang as Lang;

module SkyMath {
    const DEG2RAD = 3.14159265358979 / 180.0;
    const RAD2DEG = 180.0 / 3.14159265358979;

    function toRad(deg) {
        return deg * DEG2RAD;
    }

    function toDeg(rad) {
        return rad * RAD2DEG;
    }

    function dsin(deg) {
        return Math.sin(toRad(deg));
    }

    function dcos(deg) {
        return Math.cos(toRad(deg));
    }

    function dtan(deg) {
        return Math.tan(toRad(deg));
    }

    function dasin(x) {
        var v = x;
        if (v > 1.0) {
            v = 1.0;
        }
        if (v < -1.0) {
            v = -1.0;
        }
        return toDeg(Math.asin(v));
    }

    function dacos(x) {
        var v = x;
        if (v > 1.0) {
            v = 1.0;
        }
        if (v < -1.0) {
            v = -1.0;
        }
        return toDeg(Math.acos(v));
    }

    function datan2(y, x) {
        return toDeg(Math.atan2(y, x));
    }

    // Normalize degrees to [0,360)
    function norm360(deg) {
        var d = deg - 360.0 * Math.floor(deg / 360.0);
        if (d < 0) {
            d += 360.0;
        }
        return d;
    }

    // Normalize degrees to (-180,180]
    function norm180(deg) {
        return norm360(deg + 180.0) - 180.0;
    }

    // Julian Day from a UTC Gregorian date/time, in 64-bit Double.
    //
    // The precision matters more here than anywhere else in the app. A Julian Day
    // this century runs to about 2.46 million, and a 32-bit Float carries only
    // about seven digits - enough for the date and nothing whatever for the time
    // of day, which rounds to the nearest six hours.
    //
    // Measured against the sky: an observation at 04:06 wants JD 2461286.37917,
    // a Float holds 2461286.5, and those 2.9 hours moved Saturn from 61 degrees
    // up in the south-west down to 19 degrees. Hours of the evening also collapse
    // onto the same stored value, so the position sits frozen and then jumps.
    //
    // So the running total is forced into Double. The leading toDouble is what
    // does it: the terms before it are exact whole numbers that a Float still
    // holds safely, but everything added afterwards has to land in a Double.
    function julianDay(year, month, day, hour, minute, second) {
        var y = year;
        var m = month;
        if (m <= 2) {
            y = y - 1;
            m = m + 12;
        }
        var a = Math.floor(y / 100.0);
        var b = 2.0 - a + Math.floor(a / 4.0);
        var jd = Math.floor(365.25 * (y + 4716)).toDouble()
               + Math.floor(30.6001 * (m + 1))
               + day + b - 1524.5d;
        return jd + (hour + minute / 60.0d + second / 3600.0d) / 24.0d;
    }

    // Greenwich Mean Sidereal Time in degrees for a given Julian Day.
    //
    // Kept in Double as well: the day count is multiplied by 361 before being
    // wrapped back into a circle, so it passes through three and a half million
    // degrees on the way, and a Float would lose the fraction of a day again.
    function gmst(jd) {
        var days = jd - 2451545.0d;
        var t = days / 36525.0d;
        var g = 280.46061837d + 360.98564736629d * days + 0.000387933d * t * t - (t * t * t) / 38710000.0d;
        return norm360(g);
    }

    // Local Sidereal Time in degrees (east-positive longitude, degrees).
    function lst(jd, lonDeg) {
        return norm360(gmst(jd) + lonDeg);
    }

    // Azimuth/altitude (deg) as a world East-North-Up unit vector.
    function horizontalToEnu(azDeg, altDeg) as Lang.Array<Lang.Float> {
        var cosAlt = dcos(altDeg);
        return [cosAlt * dsin(azDeg), cosAlt * dcos(azDeg), dsin(altDeg)];
    }

    // How much the atmosphere lifts an object above its true height, in degrees
    // (Bennett's formula). About 0.57 degrees right at the horizon, 0.09 at ten
    // degrees up, and negligible overhead - so it matters for exactly the objects
    // that are hardest to find anyway, the ones just clearing the skyline.
    function refraction(altDeg) {
        if (altDeg < -2.0) {
            return 0.0;
        }
        var denom = altDeg + 7.31 / (altDeg + 4.4);
        if (denom < 0.1) {
            denom = 0.1;
        }
        var r = (1.0 / dtan(denom)) / 60.0;
        if (r > 1.0) {
            r = 1.0;
        }
        if (r < 0.0) {
            return 0.0;
        }
        return r;
    }

    // Where an object actually appears from the ground, given its height as seen
    // from Earth's centre. Parallax pushes it down, by more the closer it is, and
    // refraction lifts it back up, by more the lower it is. Both act along the
    // vertical circle, so the azimuth is untouched.
    function apparentAltitude(geocentricAltDeg, horizontalParallaxDeg) {
        var alt = geocentricAltDeg - horizontalParallaxDeg * dcos(geocentricAltDeg);
        return alt + refraction(alt);
    }

    // Convert equatorial RA/Dec (deg) + observer latitude (deg) + LST (deg) to [altitude, azimuth] in degrees.
    // Azimuth is measured from North, clockwise through East.
    function raDecToAltAz(raDeg, decDeg, latDeg, lstDeg) {
        var h = norm180(lstDeg - raDeg);
        var altRad = Math.asin(dsin(decDeg) * dsin(latDeg) + dcos(decDeg) * dcos(latDeg) * dcos(h));
        var alt = toDeg(altRad);
        var cosAlt = Math.cos(altRad);
        var az;
        if (cosAlt.abs() < 0.000001) {
            az = 0.0;
        } else {
            var cosA = (dsin(decDeg) - dsin(latDeg) * Math.sin(altRad)) / (dcos(latDeg) * cosAlt);
            var a = dacos(cosA);
            if (dsin(h) > 0) {
                az = 360.0 - a;
            } else {
                az = a;
            }
        }
        return [alt, az];
    }
}
