using Toybox.Graphics as Graphics;
using Toybox.Lang as Lang;
using Toybox.Math as Math;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Gregorian;

// The Sun's path through the next twelve months and the Moon's through the next
// four weeks, drawn as calendar lines: the Sun's marked on the first of each
// month, the Moon's on each day with its date. Both come from the same series
// that place the bodies themselves, so each body sits on its own line. Each has
// its own switch, and a line switched off lets go of everything it held.
//
// The dated positions are fixed on the sky, so they are worked out once a month
// for the Sun and once a day for the Moon, from the view timer and a few days at
// a time, since a day of the Moon costs about as much as the whole Show All
// catalogue. Every few seconds they are placed for where and when you are, with
// parallax and refraction like the bodies, and each frame only projects them.
//
// Everything held is a 32-bit Float. The ephemeris works in 64 bits, and a 64-bit
// value in an array is an object of its own, several times the size; a unit
// vector needs no more than 32 bits. Labels are made when drawn, not kept.
module SkyPaths {
    const SUN_COLOR = 0xAAAA00;
    const MOON_COLOR = Graphics.COLOR_LT_GRAY;

    // Days of Moon ahead: one sidereal month, so the line does not lap itself.
    const MOON_DAYS = 27;

    // Moon days worked out per timer tick.
    const MOON_CHUNK = 7;

    // How often the lines are placed again for the turning sky.
    const PLACE_SEC = 5;

    const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

    var _sunVecs = null;        // the Sun on the 1st, 11th and 21st of twelve months
    var _sunMonth = 0;          // the month those start in, 1 to 12
    var _sunKey = 0;
    var _moonVecs = null;       // the Moon once a day, filled MOON_CHUNK days a tick
    var _moonDays = null;       // the local date of each, for its label
    var _moonParallax = 0.0;    // one value for the line; it varies by under 0.1 degrees
    var _moonFilled = 0;
    var _moonKey = 0;
    var _moonJd = 0.0d;
    var _sunRun = null;         // the lines placed for here and now, East-North-Up
    var _moonRun = null;
    var _placedAt = 0;

    // Does the next piece of pending work for whichever lines are switched on,
    // and says whether it did. Called from the view timer, never from the draw.
    function work(lat, lon, sun, moon) as Lang.Boolean {
        if (!sun) {
            _sunVecs = null;
            _sunRun = null;
        }
        if (!moon) {
            _moonVecs = null;
            _moonDays = null;
            _moonRun = null;
        }
        if ((!sun && !moon) || lat == null || lon == null) {
            return false;
        }
        var g = Gregorian.utcInfo(Time.now(), Time.FORMAT_SHORT);
        if (sun) {
            var sunKey = g.year * 12 + g.month;
            if (_sunVecs == null || _sunKey != sunKey) {
                _sunRun = null;
                _sunVecs = null;
                _sunVecs = sunPath(g.year, g.month);
                _sunMonth = g.month;
                _sunKey = sunKey;
                return true;
            }
        }
        var jd = SkyMath.julianDay(g.year, g.month, g.day, g.hour, g.min, g.sec);
        if (moon) {
            var moonKey = (jd + 0.5).toNumber();
            if (_moonVecs == null || _moonKey != moonKey) {
                _moonRun = null;
                startMoon(jd);
                _moonKey = moonKey;
                return true;
            }
            if (_moonFilled <= MOON_DAYS) {
                fillMoon();
                return true;
            }
        }
        var now = Time.now().value();
        if ((sun && _sunRun == null) || (moon && _moonRun == null) || now - _placedAt >= PLACE_SEC) {
            // Old lines go before the new ones are built, as with the Show All
            // positions; no frame runs in between.
            _sunRun = null;
            _moonRun = null;
            var rows = SkyMath.equatorialToEnu(lat, SkyMath.lst(jd, lon));
            if (sun) {
                _sunRun = placed(_sunVecs, rows, 0.0);
            }
            if (moon) {
                _moonRun = placed(_moonVecs, rows, _moonParallax);
            }
            _placedAt = now;
            return true;
        }
        return false;
    }

    // The Sun on the 1st, 11th and 21st of twelve months from year and month,
    // closed with the 1st of the month a year on, as equatorial unit vectors.
    // Every third one is a 1st.
    function sunPath(year as Lang.Number, month as Lang.Number) as Lang.Array {
        var vecs = new [37 * 3];
        var y = year;
        var m = month;
        var i = 0;
        while (i < 37) {
            var raDec = SolarLunar.sunPosition(SkyMath.julianDay(y, m, 1 + (i % 3) * 10, 0, 0, 0));
            var v = SkyMath.raDecToVector(raDec[0], raDec[1]);
            vecs[3 * i] = v[0].toFloat();
            vecs[3 * i + 1] = v[1].toFloat();
            vecs[3 * i + 2] = v[2].toFloat();
            if (i % 3 == 2) {
                m += 1;
                if (m > 12) {
                    m = 1;
                    y += 1;
                }
            }
            i += 1;
        }
        return vecs;
    }

    // The label for the k-th monthly mark of a path that starts in firstMonth.
    function monthLabel(firstMonth as Lang.Number, k as Lang.Number) as Lang.String {
        return MONTHS[(firstMonth - 1 + k) % 12];
    }

    // Starts four weeks of Moon from jd, noting each day's local date. The
    // positions themselves are filled in by fillMoon, a few days a tick.
    function startMoon(jd) as Void {
        _moonVecs = null;
        _moonDays = null;
        var n = MOON_DAYS + 1;
        _moonVecs = new [n * 3];
        _moonDays = new [n];
        _moonFilled = 0;
        _moonJd = jd;
        _moonParallax = SolarLunar.moonHorizontalParallax(jd).toFloat();
        var now = Time.now();
        var k = 0;
        while (k < n) {
            _moonDays[k] = Gregorian.info(now.add(new Time.Duration(k * 86400)), Time.FORMAT_SHORT).day;
            k += 1;
        }
    }

    function fillMoon() as Void {
        var stop = _moonFilled + MOON_CHUNK;
        if (stop > MOON_DAYS + 1) {
            stop = MOON_DAYS + 1;
        }
        while (_moonFilled < stop) {
            var k = _moonFilled;
            var raDec = SolarLunar.moonPosition(_moonJd + k);
            var v = SkyMath.raDecToVector(raDec[0], raDec[1]);
            _moonVecs[3 * k] = v[0].toFloat();
            _moonVecs[3 * k + 1] = v[1].toFloat();
            _moonVecs[3 * k + 2] = v[2].toFloat();
            _moonFilled += 1;
        }
    }

    // A run of fixed vectors turned into East-North-Up for here and now, each
    // raised or lowered the way its body would be: parallax pushes the Moon down
    // by up to a degree, and refraction lifts both near the horizon.
    function placed(vecs, rows, parallax) as Lang.Array {
        var run = new [vecs.size()];
        var j = 0;
        while (j < vecs.size()) {
            var x = vecs[j];
            var y = vecs[j + 1];
            var z = vecs[j + 2];
            var e = rows[0] * x + rows[1] * y + rows[2] * z;
            var n = rows[3] * x + rows[4] * y + rows[5] * z;
            var u = rows[6] * x + rows[7] * y + rows[8] * z;
            var level = Math.sqrt(e * e + n * n);
            if (level > 0.000001) {
                var lifted = SkyMath.apparentAltitude(SkyMath.dasin(u), parallax);
                var k = SkyMath.dcos(lifted) / level;
                e = e * k;
                n = n * k;
                u = SkyMath.dsin(lifted);
            }
            run[j] = e.toFloat();
            run[j + 1] = n.toFloat();
            run[j + 2] = u.toFloat();
            j += 3;
        }
        return run;
    }

    // view is [cx, cy, focal], the same screen mapping everything else uses.
    // A line is drawn once it has been placed, and only if it is switched on.
    function draw(dc as Graphics.Dc, frame as Lang.Array<Lang.Float>, view as Lang.Array<Lang.Numeric>, sun as Lang.Boolean, moon as Lang.Boolean) as Void {
        var run = _sunRun;
        if (sun && run != null) {
            dc.setColor(SUN_COLOR, Graphics.COLOR_TRANSPARENT);
            DeviceAim.drawRun(dc, frame, run, view, 0);
            var m = 0;
            while (m < 12) {
                drawMark(dc, frame, view, run, 3 * m, monthLabel(_sunMonth, m));
                m += 1;
            }
        }

        run = _moonRun;
        var days = _moonDays;
        if (moon && run != null && days != null) {
            dc.setColor(MOON_COLOR, Graphics.COLOR_TRANSPARENT);
            DeviceAim.drawRun(dc, frame, run, view, 0);
            var k = 0;
            while (k <= MOON_DAYS) {
                drawMark(dc, frame, view, run, k, days[k].toString());
                k += 1;
            }
        }
    }

    // A dot and a label on one point of a line, if it is in front of the watch.
    function drawMark(dc as Graphics.Dc, frame as Lang.Array<Lang.Float>, view as Lang.Array<Lang.Numeric>, run as Lang.Array, index as Lang.Number, label as Lang.String) as Void {
        var j = index * 3;
        var p = DeviceAim.screenPoint(frame, run[j], run[j + 1], run[j + 2], view);
        if (p != null) {
            dc.fillCircle(p[0], p[1], 2);
            dc.drawText(p[0] + 4, p[1], Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}
