using Toybox.Lang as Lang;
using Toybox.WatchUi as WatchUi;
using Toybox.Graphics as Graphics;
using Toybox.Position as Position;
using Toybox.Sensor as Sensor;
using Toybox.Timer as Timer;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Gregorian;
using Toybox.Math as Math;
using Toybox.Attention as Attention;

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

    // Near-level samples folded into the declination average before it is taken as
    // settled. At 0.05 a sample this is well past converged, and it is what lets
    // the horizon frame be held still: once settled it stops moving, and only a
    // fresh position re-opens it.
    const DECLINATION_SETTLE = 100;

    const LOCK_DEGREES = 8.0;

    // Whole-catalogue mode works out where everything is at most this often rather
    // than every frame. The sky turns 15 degrees an hour, so a few seconds moves it
    // a small fraction of a pixel, while running all 35 objects - Sun, Moon and
    // planets through their own orbital maths included - ten times a second would
    // cost far more than drawing them does.
    const SKY_REFRESH_SEC = 5;

    // Holds the display awake while this screen is up. You are looking at the sky
    // rather than at the watch, and glancing back to a display that has timed out
    // makes it useless for aiming.
    //
    // The backlight always obeys the device timeout, so it has to be asked again
    // every few seconds rather than switched on once.
    const WAKE_INTERVAL_SEC = 3;

    // An AMOLED panel has burn in protection, and the system throws rather than
    // hold the display on for ever - about a minute at a stretch. When it does, it
    // wants the panel rested, so stop asking for this long instead of throwing on
    // every tick from there on.
    const WAKE_COOLDOWN_SEC = 10;

    // Half the field of view mapped across the display. The picture is the whole
    // screen - nothing is carved out of it for the text - so the width of the glass
    // and this angle between them are all there is to how much sky fits.
    const FOV_HALF = 45.0;

    // The name and the readouts are drawn straight onto the sky, the way the tick
    // note always has been, so they are sized to stay legible over grid lines
    // rather than to fit into a band of their own.
    const NAME_FONT = Graphics.FONT_MEDIUM;
    const DATA_FONT = Graphics.FONT_TINY;
    const LABEL_FONT = Graphics.FONT_XTINY;

    // Readout rows the single-object mode needs along the bottom: object and aim
    // altitude, object and aim azimuth, then the two lines of turn-and-tilt
    // guidance. Showing the whole catalogue needs one row, and says so itself.
    const DATA_ROWS = 4;

    // Room left inside the rim, so nothing lands where the round glass has already
    // run out. TEXT_MARGIN is the deeper one the readouts need, because the bottom
    // rows of a circle are the narrowest part of it.
    const EDGE_MARGIN = 6;
    const TEXT_MARGIN = 16;
    const GAP = 6;

    // Half-width of the edge chevron, and how far it reaches past the marker it
    // hangs off. Markers pin that far inside the rim so both stay on the glass.
    const CHEVRON_SIZE = 10;
    const MARKER_REACH = 22;

    hidden var _obj as Lang.Dictionary?;
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

    // Whole-catalogue mode only: where everything was last worked out, and when.
    hidden var _sky as Lang.Array?;
    hidden var _skyAt as Lang.Number;

    // Not before this second is the display asked to stay awake again.
    hidden var _wakeAt as Lang.Number;

    // Near-level samples folded in so far, and the sidereal time the equatorial grid
    // is pinned to while it is being held still. Both are re-opened by a new fix.
    hidden var _declinationSamples as Lang.Number;
    hidden var _gridLst as Lang.Double?;

    // When the position was last asked for, for the refresh interval.
    hidden var _locationAt as Lang.Number;

    function initialize(obj as Lang.Dictionary?) {
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
        _sky = null;
        _skyAt = 0;
        _wakeAt = 0;
        _declinationSamples = 0;
        _gridLst = null;
        _locationAt = 0;
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

        // The refresh interval runs from here, so the first one lands an interval
        // after the screen opened rather than straight away.
        _locationAt = Time.now().value();
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
        // Stood somewhere else now, so nothing worked out for the old place still
        // answers: the catalogue positions, and the sidereal time the held-still
        // equatorial grid is pinned to.
        _sky = null;
        _gridLst = null;

        // A new position is the only thing that makes the settled declination wrong,
        // so it is the only thing that re-opens the average - and only if the horizon
        // frame has been asked to follow the position at all.
        if (Settings.dynamicAzimuth()) {
            _declinationSamples = 0;
        }

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
        keepAwake();
        refreshLocation();
        WatchUi.requestUpdate();
    }

    // Asks the system to keep the display lit, at most once every
    // WAKE_INTERVAL_SEC. The backlight respects the device timeout whatever an app
    // wants, so holding it on means re-arming it, not setting it once.
    function keepAwake() as Void {
        if (!(Attention has :backlight)) {
            return;
        }
        var now = Time.now().value();
        if (now < _wakeAt) {
            return;
        }
        try {
            Attention.backlight(true);
            _wakeAt = now + WAKE_INTERVAL_SEC;
        } catch (ex) {
            // Burn in protection has refused. Let the panel have the rest it is
            // asking for and come back for it.
            _wakeAt = now + WAKE_COOLDOWN_SEC;
        }
    }

    // Asks for the position again once the interval has run out. One shot rather
    // than a continuous feed: a fix every few minutes is what was asked for, and
    // leaving the GPS streaming between them would cost far more than it is worth.
    //
    // Skipped while the continuous feed is already running, which only happens when
    // the first fix never arrived and there is nothing to re-arm.
    function refreshLocation() as Void {
        var minutes = Settings.locationMinutes();
        if (minutes <= 0 || _usingGps) {
            return;
        }
        var now = Time.now().value();
        if (now - _locationAt < minutes * 60) {
            return;
        }
        _locationAt = now;
        Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:onPosition));
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
                // Averaged only until it has settled. Left running it would keep
                // nudging true north for as long as the screen was up, and the
                // horizon grid would creep with it; a fresh position is the one
                // thing that makes the old value wrong, and that re-opens it.
                if (systemHeading != null && elev != null && elev.abs() < DECLINATION_MAX_TILT
                        && _declinationSamples < DECLINATION_SETTLE) {
                    var target = SkyMath.norm180(systemHeading - magneticAz);
                    _declination += DECLINATION_SMOOTHING * (target - _declination);
                    _declinationSamples += 1;
                }
                return SkyMath.norm360(magneticAz + _declination);
            }
        }
        // No magnetometer: fall back to the flat heading, level-only as it is.
        return _headingDeg;
    }

    // The screen mapping the sky is drawn with: [cx, cy, focal], where focal is
    // the pixels-per-radian scale - see DeviceAim.screenPoint.
    //
    // No box is carved out of the display for the text. The name and the readouts
    // are drawn onto the sky, the way the tick note always was, so the picture runs
    // to all four edges instead of sitting in a letterbox with black bands above
    // and below it.
    function layout(dc as Graphics.Dc) as Lang.Array<Lang.Numeric> {
        var cx = dc.getWidth() / 2;
        return [cx, dc.getHeight() / 2, cx / SkyMath.dtan(FOV_HALF)];
    }

    // Top of the object name, and top of the first readout row.
    //
    // Neither is pushed hard against the rim: the screen is round, so the rows at
    // the very top and bottom are the narrowest on it, and a long name such as
    // Alpha Centauri would have its ends cut off by the bezel up there.
    function nameRow(h as Lang.Number) as Lang.Number {
        return h / 12;
    }

    // Top of the first of rows readout lines, counted back from the bottom so the
    // block always ends the same distance inside the rim however many it needs.
    function dataRow(dc as Graphics.Dc, h as Lang.Number, rows as Lang.Number) as Lang.Number {
        return h - TEXT_MARGIN - rows * dc.getFontHeight(DATA_FONT);
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
            drawStatus(dc, cx, cy, locStatus);
            return;
        }

        var headingDeg = aimHeading();
        var accel = _accel;
        var mag = _mag;
        if (headingDeg == null || accel == null || mag == null) {
            drawStatus(dc, cx, cy, "Waiting for sensors...");
            return;
        }
        var aimElev = DeviceAim.aimElevation(accel);
        var frame = DeviceAim.deviceFrame(accel, mag);
        if (aimElev == null || frame == null) {
            drawStatus(dc, cx, cy, "Waiting for sensors...");
            return;
        }

        // The picture is built in the watch's own frame: it is what you would see
        // looking out through the back, so it rolls with the wrist. Grids and object
        // share one mapping, so they always agree. None of it needs the watch to be
        // held any particular way - rest it flat and it looks straight down at the
        // nadir, with the vertical circles meeting in the middle of the screen.
        //
        // Nothing is clipped and nothing is reserved: the sky is laid down across
        // the whole display first, and the text goes on top of it below.
        var g = Gregorian.utcInfo(Time.now(), Time.FORMAT_SHORT);
        var jd = SkyMath.julianDay(g.year, g.month, g.day, g.hour, g.min, g.sec);
        var lstDeg = SkyMath.lst(jd, lon);

        // Where the Sun is, and which way is up, both in the watch axes. The Sun
        // lights everything else out there, so it is what sets the Moon a phase;
        // the zenith is what lays Saturn a set of rings the right way up. Worked
        // out once here and handed down rather than found again per object.
        var sunRaDec = SolarLunar.sunPosition(jd);
        var sunAltAz = SkyMath.raDecToAltAz(sunRaDec[0], sunRaDec[1], lat, lstDeg);
        var sunEnu = SkyMath.horizontalToEnu(sunAltAz[1], sunAltAz[0]);
        var sunOffset = DeviceAim.viewOffset(frame, sunEnu[0], sunEnu[1], sunEnu[2]);
        var zenith = DeviceAim.viewOffset(frame, 0.0, 0.0, 1.0);

        var view = layout(dc);
        var horizonStep = Settings.horizonStep();
        var equatorialStep = Settings.equatorialStep();
        HorizonGrid.draw(dc, frame, view, horizonStep);

        // Sidereal time is the only thing in the equatorial grid that moves, so
        // pinning it to one reading is what holds that grid still. Held by default:
        // true to the sky is a grid that never stops creeping, and a reference is
        // worth more when it stays where it was put. The pin is dropped by a new
        // position, which is what makes the old reading wrong.
        var gridLst = lstDeg;
        if (!Settings.dynamicEquatorial()) {
            if (_gridLst == null) {
                _gridLst = lstDeg;
            }
            gridLst = _gridLst;
        }
        EquatorialGrid.draw(dc, frame, view, equatorialStep, lat, gridLst);

        // Whole-catalogue mode. There is no object being aimed at, so there is
        // nothing to be told to turn towards: all it can usefully say is where the
        // watch is currently pointing.
        if (_obj == null) {
            drawAllObjects(dc, view, frame, lat, jd, lstDeg, sunOffset, zenith);
            drawScale(dc, view, horizonStep, equatorialStep);
            // Room left for a second row it does not use, which lifts it clear of
            // the very bottom of the glass - the narrowest part of a round screen,
            // and no reason to sit in it with only one line to place.
            drawAimPair(dc, dataRow(dc, h, 2), headingDeg.format("%.0f"),
                signedDegrees(aimElev));
            return;
        }

        var raDec = SkyCatalog.getRaDec(_obj, jd);
        var altAz = SkyMath.raDecToAltAz(raDec[0], raDec[1], lat, lstDeg);
        // raDecToAltAz answers for Earth's centre; correct it to the watch on the
        // surface, and for the atmosphere bending the view.
        var alt = SkyMath.apparentAltitude(altAz[0], SkyCatalog.horizontalParallax(_obj, jd));
        var az = altAz[1];

        // Where the object sits looking out through the back. Forward is the
        // cosine of the angle off the aim, so it settles the lock on its own.
        var objEnu = SkyMath.horizontalToEnu(az, alt);
        var objOffset = DeviceAim.viewOffset(frame, objEnu[0], objEnu[1], objEnu[2]);
        var onTarget = SkyMath.dacos(objOffset[2]) < LOCK_DEGREES;
        drawObject(dc, view, objOffset, alt, onTarget, sunOffset, zenith);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, nameRow(h), NAME_FONT, _obj[:name], Graphics.TEXT_JUSTIFY_CENTER);
        drawScale(dc, view, horizonStep, equatorialStep);

        // Object against where the watch is actually aimed, a row each, so the two
        // pairs read straight down their columns instead of having to be picked out
        // of a sentence. They should converge as you settle onto the object, which
        // makes a sensor axis that runs the wrong way obvious rather than puzzling.
        var row = dataRow(dc, h, DATA_ROWS);
        var step = dc.getFontHeight(DATA_FONT);
        var cols = columns(dc, cy, row + 3 * step);
        drawHeads(dc, cols, row);

        var altColor;
        if (alt >= 0) {
            altColor = Graphics.COLOR_WHITE;
        } else {
            altColor = Graphics.COLOR_RED;
        }
        drawPair(dc, cols, row, "Obj", az.format("%.0f"), signedDegrees(alt), altColor);
        drawPair(dc, cols, row + step, "Aim", headingDeg.format("%.0f"),
            signedDegrees(aimElev), Graphics.COLOR_WHITE);

        if (onTarget) {
            drawNote(dc, row + 2 * step, "On target");
            return;
        }

        // Written guidance is measured against gravity rather than the watch's own
        // axes, so rolling the wrist leaves it alone: it says how to swing your
        // arm, which does not depend on how the watch is turned in your hand.
        //
        // These two are the differences down the columns above - turn closes the
        // azimuth gap and tilt the altitude one - so they run on under the same
        // left edge rather than being centred against it.
        //
        // Aimed within a couple of degrees of straight up or down there is no
        // sensible "turn left" to give, since every direction is sideways from
        // there. The picture above still holds, so only these two lines drop out.
        var basis = DeviceAim.aimBasis(aimElev, headingDeg);
        if (basis == null) {
            drawNote(dc, row + 2 * step, "Straight up/down");
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
        drawNote(dc, row + 2 * step, "Turn " + hAngle.abs().format("%.0f") + hLabel);
        drawNote(dc, row + 3 * step, "Tilt " + vAngle.abs().format("%.0f") + vLabel);
    }

    // Where the three columns of the readout table sit: [label, azimuth, altitude].
    // The label is left-aligned on the first and the two numbers right-aligned on
    // the others, so digits line up under each other instead of drifting with how
    // many of them there are.
    //
    // Sized to the narrowest row the table occupies rather than to the widest. The
    // columns have to line up all the way down, and on a round screen the bottom
    // row has the least glass under it, so that is the one with the casting vote.
    function columns(dc as Graphics.Dc, cy as Lang.Number, bottomRow as Lang.Number) as Lang.Array<Lang.Number> {
        var cx = dc.getWidth() / 2;
        var half = screenHalfWidth(dc, cy, bottomRow + dc.getFontHeight(DATA_FONT) / 2);
        return [cx - half, cx + (3 * half) / 10, cx + half];
    }

    // Column heads, dim and small and sat just above the first row. The numbers
    // below them are bare, and which column is which is the whole question they
    // would otherwise raise.
    function drawHeads(dc as Graphics.Dc, cols as Lang.Array<Lang.Number>, row as Lang.Number) as Void {
        var y = row - dc.getFontHeight(LABEL_FONT);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cols[1], y, LABEL_FONT, "Az", Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(cols[2], y, LABEL_FONT, "Alt", Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // Where the watch is pointing, with no object to set it against. There is no
    // label column and so nothing to range on: the pair is simply centred, each
    // number under its own head, which sits it in the middle of the row where a
    // round screen is widest.
    function drawAimPair(dc as Graphics.Dc, y as Lang.Number, azText as Lang.String, altText as Lang.String) as Void {
        var cx = dc.getWidth() / 2;
        var gap = dc.getWidth() / 9;
        var headY = y - dc.getFontHeight(LABEL_FONT);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - gap, headY, LABEL_FONT, "Az", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx + gap, headY, LABEL_FONT, "Alt", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - gap, y, DATA_FONT, azText, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx + gap, y, DATA_FONT, altText, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // One row of the table: a label and its two numbers. Altitude carries its own
    // colour, since an object below the horizon is the one value here worth
    // colouring on its own rather than reddening the whole line.
    function drawPair(dc as Graphics.Dc, cols as Lang.Array<Lang.Number>, y as Lang.Number, label as Lang.String, azText as Lang.String, altText as Lang.String, altColor as Lang.Number) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cols[0], y, DATA_FONT, label, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(cols[1], y, DATA_FONT, azText, Graphics.TEXT_JUSTIFY_RIGHT);
        dc.setColor(altColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cols[2], y, DATA_FONT, altText, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // A row that runs across the columns rather than filling them, and is centred
    // rather than ranged against them: it is a sentence, not a column of figures,
    // so nothing has to line up under it - and on a round screen the middle of the
    // row is where the room is.
    function drawNote(dc as Graphics.Dc, y as Lang.Number, text as Lang.String) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, y, DATA_FONT, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // A waiting message has the whole screen to itself, so it is centred both ways
    // rather than hung off the middle line with all its weight below the centre.
    function drawStatus(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, text as Lang.String) as Void {
        dc.drawText(cx, cy, Graphics.FONT_SMALL, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Draws the object as a dot that slides in from the edge of the screen as the
    // offset from the aim axis shrinks. Outside the field of view the dot pins to
    // the edge with a chevron pointing further the way to move.
    function drawObject(dc as Graphics.Dc, view as Lang.Array<Lang.Numeric>, offset as Lang.Array<Lang.Float>, alt as Lang.Float, onTarget as Lang.Boolean, sunOffset as Lang.Array, zenith as Lang.Array) as Void {
        var cx = view[0];
        var cy = view[1];
        var focal = view[2];

        // Pinning stops short of the rim by the chevron's reach, so a pinned marker
        // and the chevron hanging off it are both drawn whole instead of running off
        // the glass exactly when they are the only thing left to steer by.
        var edgeLeft = MARKER_REACH;
        var edgeTop = MARKER_REACH;
        var edgeRight = dc.getWidth() - MARKER_REACH;
        var edgeBottom = dc.getHeight() - MARKER_REACH;

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
            var push = 4 * dc.getWidth();
            dotX = (cx + push * right / span).toNumber();
            dotY = (cy - push * up / span).toNumber();
        }

        // Pin to the edge of the screen, remembering which way it went so the
        // chevron can point after it.
        var hDir = 0;
        var vDir = 0;
        if (dotX < edgeLeft) {
            dotX = edgeLeft;
            hDir = -1;
        } else if (dotX > edgeRight) {
            dotX = edgeRight;
            hDir = 1;
        }
        if (dotY < edgeTop) {
            dotY = edgeTop;
            vDir = -1;
        } else if (dotY > edgeBottom) {
            dotY = edgeBottom;
            vDir = 1;
        }

        // The corners those edges meet at are off a round display, so a marker
        // pinned into one would sit behind the bezel. Pull it back along the line
        // from the centre, which leaves it pointing the same way as it went out.
        var limit = cx - MARKER_REACH;
        var dx = dotX - cx;
        var dy = dotY - cy;
        var reach = Math.sqrt(dx * dx + dy * dy);
        if (reach > limit) {
            dotX = (cx + limit * dx / reach).toNumber();
            dotY = (cy + limit * dy / reach).toNumber();
        }

        if (onTarget) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(dotX, dotY, ObjectArt.radius(_obj) + 6);
        }

        ObjectArt.draw(dc, dotX, dotY, _obj, ObjectArt.color(_obj), offset, sunOffset, zenith);

        if (alt < 0) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(dotX, dotY, ObjectArt.radius(_obj) + 3);
        }

        if (hDir != 0) {
            drawChevron(dc, dotX, dotY, hDir, 0);
        }
        if (vDir != 0) {
            drawChevron(dc, dotX, dotY, 0, vDir);
        }
    }

    // What each grid's cells are worth, one line per grid that is switched on, in
    // the top right where the sky is emptiest. Each line names its frame, since two
    // grids at different spacings would otherwise be a bare number apiece.
    //
    // Nothing at all is drawn at the middle of the screen. Where the watch points
    // is the centre of the display whether it is marked or not, and the reticle
    // that used to sit there - a cross, and a run of ticks out along both axes -
    // only crowded the object at exactly the moment you had aimed at it.
    function drawScale(dc as Graphics.Dc, view as Lang.Array<Lang.Numeric>, horizonStep as Lang.Number, equatorialStep as Lang.Number) as Void {
        var y = nameRow(dc.getHeight()) + dc.getFontHeight(NAME_FONT) + GAP;
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        if (horizonStep > 0) {
            drawScaleLine(dc, view, y, horizonStep.toString() + " alt/az");
            y += dc.getFontHeight(LABEL_FONT);
        }
        if (equatorialStep > 0) {
            drawScaleLine(dc, view, y, equatorialStep.toString() + " ra/dec");
        }
    }

    // Right-justified as far out as the round glass reaches on that row.
    function drawScaleLine(dc as Graphics.Dc, view as Lang.Array<Lang.Numeric>, y as Lang.Number, text as Lang.String) as Void {
        var cx = view[0];
        var cy = view[1];
        var x = cx + screenHalfWidth(dc, cy, y + dc.getFontHeight(LABEL_FONT) / 2);
        dc.drawText(x, y, LABEL_FONT, text, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // Every object in the catalogue at once, drawn as a plain sky map: no marker is
    // pinned to the rim and no chevron points off it, because with the whole sky on
    // show there is nothing in particular to be steered towards. An object that is
    // not out in front of the watch is simply left out.
    //
    // Below the horizon they are darkened rather than greyed out, so they still
    // read as underfoot without losing the colour and the face that identify them.
    function drawAllObjects(dc as Graphics.Dc, view as Lang.Array<Lang.Numeric>, frame as Lang.Array<Lang.Float>, lat as Lang.Float, jd as Lang.Double, lstDeg as Lang.Double, sunOffset as Lang.Array, zenith as Lang.Array) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = view[0];
        var cy = view[1];
        var focal = view[2];

        var sky = skyPositions(lat, jd, lstDeg);
        var i = 0;
        while (i < sky.size()) {
            var entry = sky[i];
            var enu = entry[1];
            // The offset is wanted as well as the screen point - it is what orients
            // the phase and the rings - so the projection is done here rather than
            // through DeviceAim.screenPoint, which would work it out twice.
            var offset = DeviceAim.viewOffset(frame, enu[0], enu[1], enu[2]);
            var forward = offset[2];
            if (forward >= DeviceAim.MIN_FORWARD) {
                var px = (cx + focal * offset[0] / forward).toNumber();
                var py = (cy - focal * offset[1] / forward).toNumber();
                if (px >= 0 && px < w && py >= 0 && py < h) {
                    var obj = entry[0];
                    var base = ObjectArt.color(obj);
                    if (entry[2] < 0) {
                        // Underfoot. Darkened rather than replaced with a flat grey:
                        // one grey for everything threw away the colour and the face
                        // that say which object it is, which left the Sun a plain
                        // disc and the planets indistinguishable from dim stars.
                        base = ObjectArt.shade(base, 1, 3);
                    }
                    ObjectArt.draw(dc, px, py, obj, base, offset, sunOffset, zenith);
                }
            }
            i += 1;
        }
    }

    // Where every object in the catalogue is, as [object, ENU direction, altitude],
    // worked out at most every SKY_REFRESH_SEC and held between times. Only the
    // projection onto the screen is redone per frame, which is what keeps this mode
    // as cheap to draw as the single-object one.
    function skyPositions(lat as Lang.Float, jd as Lang.Double, lstDeg as Lang.Double) as Lang.Array {
        var now = Time.now().value();
        var cached = _sky;
        if (cached != null && now - _skyAt < SKY_REFRESH_SEC) {
            return cached;
        }

        var list = SkyCatalog.objects();
        var out = [];
        var i = 0;
        while (i < list.size()) {
            var obj = list[i];
            var raDec = SkyCatalog.getRaDec(obj, jd);
            var altAz = SkyMath.raDecToAltAz(raDec[0], raDec[1], lat, lstDeg);
            var alt = SkyMath.apparentAltitude(altAz[0], SkyCatalog.horizontalParallax(obj, jd));
            out.add([obj, SkyMath.horizontalToEnu(altAz[1], alt), alt]);
            i += 1;
        }

        _sky = out;
        _skyAt = now;
        return out;
    }

    // How far out the round glass reaches on a given row, measured from the middle
    // line, so a label can sit as far out as there is screen for it.
    function screenHalfWidth(dc as Graphics.Dc, cy as Lang.Numeric, y as Lang.Numeric) as Lang.Number {
        var r = dc.getWidth() / 2;
        var dy = (y - cy).abs();
        if (dy >= r) {
            return 0;
        }
        return Math.sqrt(r * r - dy * dy).toNumber() - EDGE_MARGIN;
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
        var size = CHEVRON_SIZE;
        var tipX = x + dirX * (2 * size);
        var tipY = y + dirY * (2 * size);
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
}
