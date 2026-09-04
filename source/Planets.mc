using Toybox.Math as Math;
using Toybox.Lang as Lang;

// Low-precision planetary positions (Mercury-Saturn) using approximate Keplerian
// orbital elements, in the style popularized by Paul Schlyter's "How to compute
// planetary positions" notes. Accuracy (arcminutes) far exceeds what a wrist
// compass can resolve.
module Planets {
    function eccentricAnomaly(mDeg, e) {
        var eAnom = mDeg + SkyMath.RAD2DEG * e * SkyMath.dsin(mDeg) * (1.0 + e * SkyMath.dcos(mDeg));
        var i = 0;
        while (i < 8) {
            var dM = mDeg - (eAnom - SkyMath.RAD2DEG * e * SkyMath.dsin(eAnom));
            var dE = dM / (1.0 - e * SkyMath.dcos(eAnom));
            eAnom += dE;
            if (dE.abs() < 0.000001) {
                break;
            }
            i += 1;
        }
        return eAnom;
    }

    // Heliocentric ecliptic coordinates [xh, yh, zh] in AU.
    function heliocentric(nDeg, iDeg, wDeg, a, e, mDeg) as Lang.Array<Lang.Float> {
        var eAnom = eccentricAnomaly(mDeg, e);
        var xv = a * (SkyMath.dcos(eAnom) - e);
        var yv = a * Math.sqrt(1.0 - e * e) * SkyMath.dsin(eAnom);
        var r = Math.sqrt(xv * xv + yv * yv);
        var v = SkyMath.datan2(yv, xv);
        var vw = v + wDeg;
        var xh = r * (SkyMath.dcos(nDeg) * SkyMath.dcos(vw) - SkyMath.dsin(nDeg) * SkyMath.dsin(vw) * SkyMath.dcos(iDeg));
        var yh = r * (SkyMath.dsin(nDeg) * SkyMath.dcos(vw) + SkyMath.dcos(nDeg) * SkyMath.dsin(vw) * SkyMath.dcos(iDeg));
        var zh = r * (SkyMath.dsin(vw) * SkyMath.dsin(iDeg));
        return [xh, yh, zh];
    }

    // Sun's geocentric position [xs, ys] in AU (i.e. the Earth->Sun vector),
    // used to convert planet heliocentric coordinates to geocentric ones.
    function sunGeocentric(d) as Lang.Array<Lang.Float> {
        var w = SkyMath.norm360(282.9404 + 0.0000470935 * d);
        var e = 0.016709 - 0.000000001151 * d;
        var m = SkyMath.norm360(356.0470 + 0.9856002585 * d);
        var eAnom = eccentricAnomaly(m, e);
        var xv = SkyMath.dcos(eAnom) - e;
        var yv = Math.sqrt(1.0 - e * e) * SkyMath.dsin(eAnom);
        var r = Math.sqrt(xv * xv + yv * yv);
        var lonSun = SkyMath.norm360(SkyMath.datan2(yv, xv) + w);
        return [r * SkyMath.dcos(lonSun), r * SkyMath.dsin(lonSun)];
    }

    // Orbital elements [N, i, w, a, e, M] (degrees/AU) at day-number d (days since 2000-01-00 = JD 2451543.5).
    function elementsFor(id, d) as Lang.Array<Lang.Float> {
        if (id.equals("mercury")) {
            return [
                SkyMath.norm360(48.3313 + 0.0000324587 * d),
                7.0047 + 0.00000005 * d,
                SkyMath.norm360(29.1241 + 0.0000101444 * d),
                0.387098,
                0.205635 + 0.000000000559 * d,
                SkyMath.norm360(168.6562 + 4.0923344368 * d)
            ];
        } else if (id.equals("venus")) {
            return [
                SkyMath.norm360(76.6799 + 0.0000246590 * d),
                3.3946 + 0.0000000275 * d,
                SkyMath.norm360(54.8910 + 0.0000138374 * d),
                0.723330,
                0.006773 - 0.000000001302 * d,
                SkyMath.norm360(48.0052 + 1.6021302244 * d)
            ];
        } else if (id.equals("mars")) {
            return [
                SkyMath.norm360(49.5574 + 0.0000211081 * d),
                1.8497 - 0.0000000178 * d,
                SkyMath.norm360(286.5016 + 0.0000292961 * d),
                1.523688,
                0.093405 + 0.000000002516 * d,
                SkyMath.norm360(18.6021 + 0.5240207766 * d)
            ];
        } else if (id.equals("jupiter")) {
            return [
                SkyMath.norm360(100.4542 + 0.0000276854 * d),
                1.3030 - 0.0000001557 * d,
                SkyMath.norm360(273.8777 + 0.0000164505 * d),
                5.20256,
                0.048498 + 0.000000004469 * d,
                SkyMath.norm360(19.8950 + 0.0830853001 * d)
            ];
        }
        // saturn
        return [
            SkyMath.norm360(113.6634 + 0.0000238980 * d),
            2.4886 - 0.0000001081 * d,
            SkyMath.norm360(339.3939 + 0.0000297661 * d),
            9.55475,
            0.055546 - 0.000000009499 * d,
            SkyMath.norm360(316.9670 + 0.0334442282 * d)
        ];
    }

    // Returns [ra, dec] in degrees for the given Julian Day (UTC).
    function planetPosition(id, jd) {
        // Double, so the fraction of a day survives being subtracted from a
        // number in the millions - see SkyMath.julianDay.
        var d = jd - 2451543.5d;
        var sun = sunGeocentric(d);

        var el = elementsFor(id, d);
        var helio = heliocentric(el[0], el[1], el[2], el[3], el[4], el[5]);

        var xg = helio[0] + sun[0];
        var yg = helio[1] + sun[1];
        var zg = helio[2];

        var lon = SkyMath.norm360(SkyMath.datan2(yg, xg));
        var lat = SkyMath.datan2(zg, Math.sqrt(xg * xg + yg * yg));

        var t = (jd - 2451545.0) / 36525.0;
        var eps = SolarLunar.obliquity(t);
        return SolarLunar.eclipticToEquatorial(lon, lat, eps);
    }
}
