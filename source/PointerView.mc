using Toybox.Lang as Lang;
using Toybox.WatchUi as WatchUi;
using Toybox.Graphics as Graphics;
using Toybox.Position as Position;
using Toybox.Sensor as Sensor;
using Toybox.Timer as Timer;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Gregorian;
using Toybox.Math as Math;

// Live pointer screen: aim the watch's 12 o'clock edge at the selected object.
// The object is placed in the watch's own frame (see DeviceAim), so the error
// shown is the real angular offset rather than separate azimuth/altitude numbers.
class PointerView extends WatchUi.View {
    // Sensors are polled rather than waited on: the push callbacks only fire once
    // per second, which is far too slow and too stale to aim with while moving.
    const SAMPLE_MS = 100;

    // Exponential smoothing per sample, applied to the raw sensor vectors rather
    // than to angles derived from them - the same thing Stellarium's SensorsMgr
    // does, and for the same reason: magnetometer noise is what makes a sky view
    // jitter, and it settles far better when averaged as vectors. Stellarium runs
    // 0.01 to 0.1 per frame at display rate and smooths harder the tighter the
    // field of view; this is the equivalent for a 10 Hz sample and an 8 degree lock.
    const SMOOTHING = 0.2;

    // Declination changes with where you stand, not with how you hold the watch,
    // so it is averaged in very slowly and only while the watch is near level.
    const DECLINATION_SMOOTHING = 0.05;
    const DECLINATION_MAX_TILT = 25.0;

    const LOCK_DEGREES = 8.0;

    // Spacing of the aim reticle's ticks, in degrees.
    const GRID_STEP = 15.0;

    // Half the field of view mapped across the drawing area, and half its height
    // in pixels. The width is taken from the screen, the height kept short so the
    // sky does not run into the readouts underneath.
    const FOV_HALF = 45.0;
    const GRID_HALF_Y = 65.0;

    hidden var _obj as Lang.Dictionary;
    hidden var _lat as Lang.Float?;
    hidden var _lon as Lang.Float?;
    hidden var _headingDeg as Lang.Float?;
    hidden var _accel as Lang.Array?;
    hidden var _mag as Lang.Array?;
    hidden var _declination as Lang.Float = 0.0;
    hidden var _streaming as Lang.Boolean;
    hidden var _timer as Timer.Timer?;
    hidden var _locateTimer as Timer.Timer?;
    hidden var _haveUsableFix as Lang.Boolean;
    hidden var _usingGps as Lang.Boolean;

    function initialize(obj as Lang.Dictionary) {
        View.initialize();
        _obj = obj;
        _lat = null;
        _lon = null;
        _headingDeg = null;
        _accel = null;
        _mag = null;
        _declination = 0.0;
        _streaming = false;
        _haveUsableFix = false;
        _usingGps = false;
    }

    function onShow() as Void {
        // Polling drives the display; this push feed is only insurance, for
        // devices that keep the sensor subsystem idle until something subscribes.
        Sensor.enableSensorEvents(method(:onSensor));
        startAccelerometer();
        _timer = new Timer.Timer();
        _timer.start(method(:onTimer), SAMPLE_MS, true);

        // Prefer whatever position is already cached/fastest-available (this is
        // where a phone-synced location would surface) before committing to an
        // active GPS fix, which is slower and drains more battery.
        applyPositionInfo(Position.getInfo());
        Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:onPosition));

        _locateTimer = new Timer.Timer();
        _locateTimer.start(method(:onLocateTimeout), 4000, false);
    }

    // Some devices leave the accelerometer powered down until a data listener asks
    // for it, and Sensor.Info.accel stays null until they do. The samples that
    // arrive here are only a fallback: the live values come from polling instead.
    function startAccelerometer() as Void {
        var rate = 10;
        var maxRate = Sensor.getMaxSampleRate();
        if (maxRate != null && maxRate < rate) {
            rate = maxRate;
        }
        try {
            Sensor.registerSensorDataListener(method(:onAccelData), {
                :period => 1,
                :accelerometer => {:enabled => true, :sampleRate => rate}
            });
            _streaming = true;
        } catch (ex) {
            _streaming = false;
        }
    }

    function onHide() as Void {
        Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
        Sensor.enableSensorEvents(null);
        if (_streaming) {
            Sensor.unregisterSensorDataListener();
            _streaming = false;
        }
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
        if (_locateTimer != null) {
            _locateTimer.stop();
            _locateTimer = null;
        }
    }

    function onPosition(info as Position.Info) as Void {
        applyPositionInfo(info);
    }

    function applyPositionInfo(info as Position.Info) as Void {
        if (info.position == null) {
            return;
        }
        var deg = info.position.toDegrees();
        _lat = deg[0].toFloat();
        _lon = deg[1].toFloat();

        var acc = info.accuracy;
        if (acc != null && acc >= Position.QUALITY_USABLE) {
            _haveUsableFix = true;
            if (_locateTimer != null) {
                _locateTimer.stop();
                _locateTimer = null;
            }
        }
    }

    // Fires a few seconds after onShow if no usable cached/quick fix arrived -
    // falls back to actively driving the onboard GPS chip.
    function onLocateTimeout() as Void {
        _locateTimer = null;
        if (!_haveUsableFix && !_usingGps) {
            _usingGps = true;
            Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        }
    }

    function onSensor(info as Sensor.Info) as Void {
        if (info.heading != null) {
            applyHeading(SkyMath.toDeg(info.heading));
        }
    }

    function onAccelData(data as Sensor.SensorData) as Void {
        var accel = data.accelerometerData;
        if (accel == null) {
            return;
        }
        var n = accel.x.size();
        if (n > 0) {
            applyAccel([accel.x[n - 1], accel.y[n - 1], accel.z[n - 1]]);
        }
    }

    function onTimer() as Void {
        var info = Sensor.getInfo();
        if (info has :heading && info.heading != null) {
            applyHeading(SkyMath.toDeg(info.heading));
        }
        if (info has :accel && info.accel != null) {
            applyAccel(info.accel);
        }
        if (info has :mag && info.mag != null) {
            applyMag(info.mag);
        }
        WatchUi.requestUpdate();
    }

    function applyHeading(headingDeg as Lang.Float) as Void {
        var previous = _headingDeg;
        if (previous == null) {
            _headingDeg = SkyMath.norm360(headingDeg);
        } else {
            // Smooth the short way round, so 359 -> 1 does not swing backwards.
            _headingDeg = SkyMath.norm360(previous + SMOOTHING * SkyMath.norm180(headingDeg - previous));
        }
    }

    function applyAccel(sample as Lang.Array) as Void {
        _accel = smoothVector(_accel, sample);
    }

    function applyMag(sample as Lang.Array) as Void {
        _mag = smoothVector(_mag, sample);
    }

    function smoothVector(previous as Lang.Array?, sample as Lang.Array) as Lang.Array<Lang.Float> {
        if (previous == null) {
            return [sample[0] * 1.0, sample[1] * 1.0, sample[2] * 1.0];
        }
        return [
            previous[0] + SMOOTHING * (sample[0] - previous[0]),
            previous[1] + SMOOTHING * (sample[1] - previous[1]),
            previous[2] + SMOOTHING * (sample[2] - previous[2])
        ];
    }

    // Where the 12 o'clock axis points, in degrees from true north, or null while
    // no usable reading has arrived.
    //
    // The magnetometer is worked out here rather than taken from Sensor.Info's
    // heading, because that heading is a flat compass reading and goes wrong the
    // moment the watch tilts up at the sky. The system heading is still worth one
    // thing though: while the watch happens to be near level it is trustworthy
    // AND corrected to true north, so the gap between the two is the local
    // magnetic declination, which is banked and then applied at any tilt.
    function aimHeading() as Lang.Float? {
        var accel = _accel;
        var mag = _mag;
        if (accel != null && mag != null) {
            var magneticAz = DeviceAim.magneticAzimuth(accel, mag);
            if (magneticAz != null) {
                var systemHeading = _headingDeg;
                var elev = DeviceAim.aimElevation(accel);
                if (systemHeading != null && elev != null && elev.abs() < DECLINATION_MAX_TILT) {
                    var target = SkyMath.norm180(systemHeading - magneticAz);
                    _declination += DECLINATION_SMOOTHING * (target - _declination);
                }
                return SkyMath.norm360(magneticAz + _declination);
            }
        }
        // No magnetometer: fall back to the flat heading, level-only as it is.
        return _headingDeg;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        var cx = w / 2;
        var cy = h / 2;

        var lat = _lat;
        var lon = _lon;
        if (lat == null || lon == null) {
            var locStatus;
            if (_usingGps) {
                locStatus = "Acquiring GPS fix...";
            } else {
                locStatus = "Locating...";
            }
            dc.drawText(cx, cy, Graphics.FONT_SMALL, locStatus, Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var headingDeg = aimHeading();
        var accel = _accel;
        var mag = _mag;
        if (headingDeg == null || accel == null || mag == null) {
            dc.drawText(cx, cy, Graphics.FONT_SMALL, "Waiting for sensors...", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        var aimElev = DeviceAim.aimElevation(accel);
        var frame = DeviceAim.deviceFrame(accel, mag);
        if (aimElev == null || frame == null) {
            dc.drawText(cx, cy, Graphics.FONT_SMALL, "Waiting for sensors...", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var g = Gregorian.utcInfo(Time.now(), Time.FORMAT_SHORT);
        var jd = SkyMath.julianDay(g.year, g.month, g.day, g.hour, g.min, g.sec);
        var raDec = SkyCatalog.getRaDec(_obj, jd);
        var lstDeg = SkyMath.lst(jd, lon);
        var altAz = SkyMath.raDecToAltAz(raDec[0], raDec[1], lat, lstDeg);
        // raDecToAltAz answers for Earth's centre; correct it to the watch on the
        // surface, and for the atmosphere bending the view.
        var alt = SkyMath.apparentAltitude(altAz[0], SkyCatalog.horizontalParallax(_obj, jd));
        var az = altAz[1];

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 34, Graphics.FONT_SMALL, _obj[:name], Graphics.TEXT_JUSTIFY_CENTER);

        // Where the object sits looking out through the back. Forward is the
        // cosine of the angle off the aim, so it settles the lock on its own.
        var objEnu = SkyMath.horizontalToEnu(az, alt);
        var objOffset = DeviceAim.viewOffset(frame, objEnu[0], objEnu[1], objEnu[2]);
        var onTarget = SkyMath.dacos(objOffset[2]) < LOCK_DEGREES;

        // The picture is built in the watch's own frame: it is what you would see
        // looking out through the back, so it rolls with the wrist. Grid and object
        // share one mapping, so they always agree. None of it needs the watch to be
        // held any particular way - rest it flat and it looks straight down at the
        // nadir, with the vertical circles meeting in the middle of the screen.
        var halfX = (cx - 26).toFloat();
        var view = [cx, cy, halfX, GRID_HALF_Y, halfX / SkyMath.dtan(FOV_HALF)];
        drawReticle(dc, view);

        // Clipped to the view box, since sky lines run off in every direction and
        // would otherwise scrawl over the readouts below.
        dc.setClip(cx - halfX.toNumber(), (cy - GRID_HALF_Y).toNumber(),
            (2 * halfX).toNumber(), (2 * GRID_HALF_Y).toNumber());
        HorizonGrid.draw(dc, frame, view);
        drawObject(dc, view, objOffset, alt, onTarget);
        dc.clearClip();

        // Object against where the watch is actually aimed, on both axes. Each pair
        // should converge as you settle onto the object, which makes a sensor axis
        // that runs the wrong way obvious instead of just puzzling.
        var altColor;
        if (alt >= 0) {
            altColor = Graphics.COLOR_WHITE;
        } else {
            altColor = Graphics.COLOR_RED;
        }
        var elevLine = "Alt obj " + signedDegrees(alt) + "  aim " + signedDegrees(aimElev);
        dc.setColor(altColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 70, Graphics.FONT_XTINY, elevLine, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 88, Graphics.FONT_XTINY,
            "Az obj " + az.format("%.0f") + "  aim " + headingDeg.format("%.0f"),
            Graphics.TEXT_JUSTIFY_CENTER);

        if (onTarget) {
            dc.drawText(cx, cy + 110, Graphics.FONT_XTINY, "On target", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        // Written guidance is measured against gravity rather than the watch's own
        // axes, so rolling the wrist leaves it alone: it says how to swing your
        // arm, which does not depend on how the watch is turned in your hand.
        //
        // Aimed within a couple of degrees of straight up or down there is no
        // sensible "turn left" to give, since every direction is sideways from
        // there. The picture above still holds, so only these two lines drop out.
        var basis = DeviceAim.aimBasis(aimElev, headingDeg);
        if (basis == null) {
            dc.drawText(cx, cy + 110, Graphics.FONT_XTINY, "Aimed straight up/down", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var aimed = DeviceAim.project(basis, objEnu[0], objEnu[1], objEnu[2]);
        var hAngle = aimed[0];
        var vAngle = aimed[1];

        var hLabel;
        if (hAngle >= 0) {
            hLabel = " right";
        } else {
            hLabel = " left";
        }
        var vLabel;
        if (vAngle >= 0) {
            vLabel = " up";
        } else {
            vLabel = " down";
        }
        dc.drawText(cx, cy + 108, Graphics.FONT_XTINY, "Turn " + hAngle.abs().format("%.0f") + hLabel, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, cy + 126, Graphics.FONT_XTINY, "Tilt " + vAngle.abs().format("%.0f") + vLabel, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Draws the object as a dot that slides in from the edge of the screen as the
    // offset from the aim axis shrinks. Outside the field of view the dot pins to
    // the edge with a chevron pointing further the way to move.
    function drawObject(dc as Graphics.Dc, view as Lang.Array, offset as Lang.Array<Lang.Float>, alt as Lang.Float, onTarget as Lang.Boolean) as Void {
        var cx = view[0];
        var cy = view[1];
        var halfX = view[2];
        var halfY = view[3];
        var focal = view[4];

        // The perspective divide is what makes the object land where a camera
        // would put it rather than merely in the right general direction.
        var right = offset[0];
        var up = offset[1];
        var forward = offset[2];

        var dotX;
        var dotY;
        if (forward >= DeviceAim.MIN_FORWARD) {
            dotX = (cx + focal * right / forward).toNumber();
            dotY = (cy - focal * up / forward).toNumber();
        } else {
            // Level with the back of the watch or behind it, where perspective has
            // nothing to say. Push it right out along the way it lies instead, so
            // the edge marker still points the way to swing.
            var span = Math.sqrt(right * right + up * up);
            if (span < 0.000001) {
                span = 1.0;
            }
            dotX = (cx + 4 * halfX * right / span).toNumber();
            dotY = (cy - 4 * halfY * up / span).toNumber();
        }

        // Pin to the edge of the view box, remembering which way it went so the
        // chevron can point after it.
        var hDir = 0;
        var vDir = 0;
        var left = (cx - halfX).toNumber();
        var rightEdge = (cx + halfX).toNumber();
        var top = (cy - halfY).toNumber();
        var bottom = (cy + halfY).toNumber();
        if (dotX < left) {
            dotX = left;
            hDir = -1;
        } else if (dotX > rightEdge) {
            dotX = rightEdge;
            hDir = 1;
        }
        if (dotY < top) {
            dotY = top;
            vDir = -1;
        } else if (dotY > bottom) {
            dotY = bottom;
            vDir = 1;
        }

        if (onTarget) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(dotX, dotY, objectRadius(_obj) + 6);
        }

        dc.setColor(objectColor(_obj), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(dotX, dotY, objectRadius(_obj));

        if (alt < 0) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(dotX, dotY, objectRadius(_obj) + 3);
        }

        if (hDir != 0) {
            drawChevron(dc, dotX, dotY, hDir, 0);
        }
        if (vDir != 0) {
            drawChevron(dc, dotX, dotY, 0, vDir);
        }
    }

    // The aim reference, drawn under the sky grid: a centre cross for where the
    // watch points, and ticks every GRID_STEP degrees along each axis for scale.
    // Ticks rather than full rules, so this reads as a separate layer from the
    // celestial grid crossing it rather than competing with it.
    function drawReticle(dc as Graphics.Dc, view as Lang.Array) as Void {
        var cx = view[0];
        var cy = view[1];
        var halfX = view[2];
        var halfY = view[3];
        var focal = view[4];

        // Ticks sit where the perspective puts each angle, so they measure the
        // picture rather than merely dividing the box into equal pieces.
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        var step = GRID_STEP;
        while (step < 90.0) {
            var offset = focal * SkyMath.dtan(step);
            if (offset <= halfX) {
                var dx = offset.toNumber();
                dc.drawLine(cx - dx, cy - 5, cx - dx, cy + 5);
                dc.drawLine(cx + dx, cy - 5, cx + dx, cy + 5);
            }
            if (offset <= halfY) {
                var dy = offset.toNumber();
                dc.drawLine(cx - 5, cy - dy, cx + 5, cy - dy);
                dc.drawLine(cx - 5, cy + dy, cx + 5, cy + dy);
            }
            if (offset > halfX && offset > halfY) {
                break;
            }
            step += GRID_STEP;
        }

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - 14, cy, cx + 14, cy);
        dc.drawLine(cx, cy - 14, cx, cy + 14);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText((cx + halfX).toNumber(), (cy - halfY).toNumber() - 20, Graphics.FONT_XTINY,
            GRID_STEP.format("%.0f") + " ticks", Graphics.TEXT_JUSTIFY_RIGHT);
    }

    function signedDegrees(deg as Lang.Float) as Lang.String {
        if (deg >= 0) {
            return "+" + deg.format("%.0f");
        }
        return deg.format("%.0f");
    }

    function clampAngle(angle as Lang.Float, limit as Lang.Float) as Lang.Float {
        if (angle > limit) {
            return limit;
        }
        if (angle < -limit) {
            return -limit;
        }
        return angle;
    }

    // Small triangle at the edge of the sky strip pointing further the way to move.
    // Exactly one of dirX/dirY should be non-zero.
    function drawChevron(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, dirX as Lang.Number, dirY as Lang.Number) as Void {
        var size = 10;
        var tipX = x + dirX * (size + 10);
        var tipY = y + dirY * (size + 10);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        if (dirX != 0) {
            dc.fillPolygon([
                [tipX, tipY],
                [tipX - dirX * size, tipY - size],
                [tipX - dirX * size, tipY + size]
            ]);
        } else {
            dc.fillPolygon([
                [tipX, tipY],
                [tipX - size, tipY - dirY * size],
                [tipX + size, tipY - dirY * size]
            ]);
        }
    }

    // Approximate on-screen color for the selected object.
    function objectColor(obj as Lang.Dictionary) as Lang.Number {
        var type = obj[:type];
        if (type == :sun) {
            return Graphics.COLOR_YELLOW;
        }
        if (type == :moon) {
            return Graphics.COLOR_LT_GRAY;
        }
        if (type == :planet) {
            var id = obj[:id];
            if (id.equals("mars")) {
                return Graphics.COLOR_ORANGE;
            }
            if (id.equals("venus")) {
                return Graphics.COLOR_WHITE;
            }
            if (id.equals("mercury")) {
                return Graphics.COLOR_LT_GRAY;
            }
            if (id.equals("jupiter")) {
                return Graphics.COLOR_YELLOW;
            }
            return Graphics.COLOR_ORANGE;
        }
        return Graphics.COLOR_WHITE;
    }

    // Dot radius: fixed for Sun/Moon/planets, magnitude-scaled for stars
    // (brighter, lower-magnitude stars draw larger, matching how they look in the sky).
    function objectRadius(obj as Lang.Dictionary) as Lang.Number {
        var type = obj[:type];
        if (type == :sun) {
            return 20;
        }
        if (type == :moon) {
            return 16;
        }
        if (type == :planet) {
            return 6;
        }
        var mag = obj[:mag];
        if (mag == null) {
            return 3;
        }
        var r = (5.0 - mag).toNumber();
        if (r < 2) {
            r = 2;
        }
        if (r > 7) {
            r = 7;
        }
        return r;
    }
}
