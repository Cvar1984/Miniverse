using Toybox.Graphics as Graphics;
using Toybox.Lang as Lang;
using Toybox.Math as Math;

// Turns the watch into a viewfinder. You hold it up with the screen toward you
// and the back toward the sky, and the object is drawn where it sits in the sky
// behind the watch, the same idea as a phone astronomy app pointed with its camera.
//
// The aim axis is therefore the watch's Z axis, straight out through the back,
// not the 12 o'clock edge. That changes what roll means: looking through a
// window, turning your wrist turns what you see through it, so the picture is
// built in the watch's own frame and does rotate with the wrist. The written
// turn/tilt guidance stays measured against gravity, because that describes how
// to move your arm and should not care how the watch is rotated in your hand.
//
// Hardware conventions live in the two constants below. Each is a single
// physical fact about how this watch labels its axes, and each has a check
// against the readouts on the pointer screen.
module DeviceAim {
    // Which way the accelerometer vector points at rest. Some devices report
    // specific force (+1g on the axis facing the sky), others report the gravity
    // direction; this one behaves like the latter, so the reading is negated to
    // recover "up". Check: point the back of the watch at the horizon and the
    // Aim elevation reads about 0; tip the back up toward the sky and it climbs.
    const UP_SIGN = -1;

    // Which way along Z the back of the case lies. Z points out through the
    // screen, so the back (the face you aim at the sky) is the other way.
    //
    // This sign applies to forward alone. Flipping the sideways and forward
    // components together cancels in the sideways divide and can only invert up
    // and down. Inverting forward turns both screen axes over at once, which
    // shows up as the object following the watch instead of sliding against it.
    const BACK_SIGN = -1;

    // Below this the aim axis is within ~2 degrees of vertical, where "which way
    // is right" stops being defined and the compass heading carries no usable
    // information about which way the watch faces.
    const MIN_HORIZONTAL = 0.035;

    // An object further off the aim than about 84 degrees is level with the back
    // of the watch or behind it, where a perspective projection has nothing
    // sensible to say.
    const MIN_FORWARD = 0.1;

    // World "up", written in the watch's own coordinates, or null if the reading
    // is unusable. Everything else is built from this.
    function upVector(accel as Lang.Array<Lang.Numeric>) as Lang.Array<Lang.Float>? {
        var ax = accel[0] * 1.0;
        var ay = accel[1] * 1.0;
        var az = accel[2] * 1.0;
        var len = Math.sqrt(ax * ax + ay * ay + az * az);
        if (len < 1.0) {
            return null;
        }
        return [UP_SIGN * ax / len, UP_SIGN * ay / len, UP_SIGN * az / len];
    }

    // How high the back of the watch points, in degrees above the horizon.
    // Shown on the pointer screen, so a wrong sign convention is visible rather
    // than silently mirroring everything.
    function aimElevation(accel as Lang.Array<Lang.Numeric>) as Lang.Float? {
        var u = upVector(accel);
        if (u == null) {
            return null;
        }
        // The back axis is (0, 0, BACK_SIGN), so its height is that component of up.
        return SkyMath.dasin(BACK_SIGN * u[2]);
    }

    // The magnetic azimuth the back of the watch points along, worked out from
    // the raw magnetometer rather than taken from the compass heading the system
    // reports. Null if the reading is unusable or the watch is aimed too near
    // vertical.
    //
    // This is the tilt compensation a flat compass heading lacks. Stellarium's
    // SensorsMgr does the same: it ignores the system heading and de-rotates the
    // raw field by the device's own roll and pitch first. Here that falls out of
    // flattening both the field and the aim axis onto the plane at right angles
    // to gravity, so the answer holds at any tilt.
    //
    // Magnetic, not true: the caller adds declination.
    function magneticAzimuth(accel as Lang.Array<Lang.Numeric>, mag as Lang.Array<Lang.Numeric>) as Lang.Float? {
        var u = upVector(accel);
        if (u == null) {
            return null;
        }
        var ux = u[0];
        var uy = u[1];
        var uz = u[2];

        // The back axis flattened onto the horizontal plane.
        var back = BACK_SIGN * 1.0;
        var dot = back * uz;
        var px = -dot * ux;
        var py = -dot * uy;
        var pz = back - dot * uz;
        var pLen = Math.sqrt(px * px + py * py + pz * pz);
        if (pLen < MIN_HORIZONTAL) {
            return null;
        }
        px = px / pLen;
        py = py / pLen;
        pz = pz / pLen;

        var n = northVector(mag, ux, uy, uz);
        if (n == null) {
            return null;
        }

        // Angle from north round to the aim, turning the way a compass counts.
        var cross = (py * n[2] - pz * n[1]) * ux + (pz * n[0] - px * n[2]) * uy + (px * n[1] - py * n[0]) * uz;
        var along = px * n[0] + py * n[1] + pz * n[2];
        return SkyMath.norm360(SkyMath.datan2(cross, along));
    }

    // Magnetic north along the ground, in the watch's coordinates: the field with
    // its vertical part taken off, which leaves it pointing north however the
    // watch is tilted.
    function northVector(mag as Lang.Array<Lang.Numeric>, ux as Lang.Float, uy as Lang.Float, uz as Lang.Float) as Lang.Array<Lang.Float>? {
        var mx = mag[0] * 1.0;
        var my = mag[1] * 1.0;
        var mz = mag[2] * 1.0;
        var dot = mx * ux + my * uy + mz * uz;
        var nx = mx - dot * ux;
        var ny = my - dot * uy;
        var nz = mz - dot * uz;
        var len = Math.sqrt(nx * nx + ny * ny + nz * nz);
        if (len < 1.0) {
            return null;
        }
        return [nx / len, ny / len, nz / len];
    }

    // The world's axes written in the watch's coordinates, as
    // [eE,eN,eU, nE,nN,nU, uE,uN,uU] for east, north and up. Multiplying a sky
    // direction's world components by these lands it in the watch's frame, which
    // is what the viewfinder needs. Null if the sensors cannot place it.
    function deviceFrame(accel as Lang.Array<Lang.Numeric>, mag as Lang.Array<Lang.Numeric>, declinationDeg as Lang.Float) as Lang.Array<Lang.Float>? {
        var u = upVector(accel);
        if (u == null) {
            return null;
        }
        var n = northVector(mag, u[0], u[1], u[2]);
        if (n == null) {
            return null;
        }
        // East = north x up.
        var eE = n[1] * u[2] - n[2] * u[1];
        var eN = n[2] * u[0] - n[0] * u[2];
        var eU = n[0] * u[1] - n[1] * u[0];

        // Swung round to true north, which is what the declination argument is for.
        //
        // The magnetometer gives magnetic north, but every object placed on this
        // screen comes from RA/Dec and sidereal time, which are true by
        // construction. A magnetic frame would turn the whole drawn sky by the local
        // declination against the numbers printed underneath it: a few degrees in
        // most places, twenty in parts of Canada, against an eight degree lock. The
        // picture is built from this frame, so correcting only the heading readout
        // would still leave it wrong.
        //
        // Declination is measured east-positive, so magnetic north sits that far
        // east of true and true north is the same angle back the other way.
        var cosD = SkyMath.dcos(declinationDeg);
        var sinD = SkyMath.dsin(declinationDeg);
        var tN = [
            n[0] * cosD - eE * sinD,
            n[1] * cosD - eN * sinD,
            n[2] * cosD - eU * sinD
        ];
        var tE = [
            eE * cosD + n[0] * sinD,
            eN * cosD + n[1] * sinD,
            eU * cosD + n[2] * sinD
        ];

        return [
            tE[0], tE[1], tE[2],
            tN[0], tN[1], tN[2],
            u[0], u[1], u[2]
        ];
    }

    // Where a sky direction sits as seen through the back of the watch, as
    // [right, up, forward]: how far it lies to the right of the screen, how far
    // up it, and how far out in front of the back face. Forward at or below zero
    // means it is behind you. All three are direction cosines, ready for a
    // perspective divide.
    function viewOffset(frame as Lang.Array<Lang.Float>, tE as Lang.Float, tN as Lang.Float, tU as Lang.Float) as Lang.Array<Lang.Float> {
        var x = tE * frame[0] + tN * frame[3] + tU * frame[6];
        var y = tE * frame[1] + tN * frame[4] + tU * frame[7];
        var z = tE * frame[2] + tN * frame[5] + tU * frame[8];
        // X is 3 o'clock and Y is 12 o'clock, so both already read as the screen
        // does. Only forward turns round, because the aim is out through the back.
        return [x, y, BACK_SIGN * z];
    }

    // Where a sky direction lands on screen, or null when it is not out in front
    // of the watch's back. view is [cx, cy, focal], where focal is the
    // pixels-per-radian scale that sets how wide a piece of sky the screen
    // covers. Dividing by "forward" lines the sky up the way a camera would,
    // instead of only pointing in the right direction.
    function screenPoint(frame as Lang.Array<Lang.Float>, tE as Lang.Float, tN as Lang.Float, tU as Lang.Float, view as Lang.Array<Lang.Numeric>) as Lang.Array<Lang.Number>? {
        var offset = viewOffset(frame, tE, tN, tU);
        var forward = offset[2];
        if (forward < MIN_FORWARD) {
            return null;
        }
        var focal = view[2];
        return [
            (view[0] + focal * offset[0] / forward).toNumber(),
            (view[1] - focal * offset[1] / forward).toNumber()
        ];
    }

    // The frame the watch aims in, as world East-North-Up vectors:
    // [dE,dN,dU, rE,rN,rU, uE,uN,uU] for the direction it points, plus "right"
    // and "up" perpendicular to it. Null if it is aimed too near vertical, where
    // "which way is right" stops being defined.
    //
    // Right and up are built from gravity, not from the watch body, which keeps
    // roll out of the written guidance: how to swing your arm to reach the object
    // does not depend on how the watch is turned in your hand.
    function aimBasis(elevDeg as Lang.Float, headingDeg as Lang.Float) as Lang.Array<Lang.Float>? {
        var cosElev = SkyMath.dcos(elevDeg);
        if (cosElev < MIN_HORIZONTAL) {
            return null;
        }
        var dE = cosElev * SkyMath.dsin(headingDeg);
        var dN = cosElev * SkyMath.dcos(headingDeg);
        var dU = SkyMath.dsin(elevDeg);

        // "Right" of the aim: horizontal, perpendicular to it. This is d x up,
        // which works out to (dN, -dE, 0), of length cos(elevation).
        var rE = dN / cosElev;
        var rN = -dE / cosElev;

        // "Up" from the aim: perpendicular to both, so tilting along it climbs
        // straight toward the zenith rather than sideways. This is right x d.
        return [
            dE, dN, dU,
            rE, rN, 0.0,
            rN * dU, -rE * dU, rE * dN - rN * dE
        ];
    }

    // Puts a world direction into that frame, as [turnDeg, tiltDeg, forward]:
    // how far right and how far up it sits from the aim, plus the cosine of the
    // angle off the aim axis, which is negative when it is behind the watch.
    function project(basis as Lang.Array<Lang.Float>, e as Lang.Float, n as Lang.Float, u as Lang.Float) as Lang.Array<Lang.Float> {
        var alongAim = e * basis[0] + n * basis[1] + u * basis[2];
        var alongRight = e * basis[3] + n * basis[4] + u * basis[5];
        var alongUp = e * basis[6] + n * basis[7] + u * basis[8];

        // Tilt is measured off the aim's own horizontal plane, not straight off
        // the aim axis. Both amount to the same thing near the object, but this
        // stays well defined when it is far to one side, where "aim" and "up"
        // both fall to zero and dividing one by the other is meaningless.
        var acrossAim = Math.sqrt(alongAim * alongAim + alongRight * alongRight);

        return [
            SkyMath.datan2(alongRight, alongAim),
            SkyMath.datan2(alongUp, acrossAim),
            alongAim
        ];
    }

    // Draws a run of world directions, flat East-North-Up triples, as one line.
    // A point behind the watch comes back null from the projection and breaks the
    // line there instead of joining across the gap. Both grids and the
    // constellation figures draw through this.
    function drawRun(dc as Graphics.Dc, frame as Lang.Array<Lang.Float>, run as Lang.Array<Lang.Float>, view as Lang.Array<Lang.Numeric>) as Void {
        // The same sums as viewOffset and screenPoint, written out here with the
        // frame held in locals, because every overlay point goes through this
        // loop: no call and no new array per point.
        var cx = view[0];
        var cy = view[1];
        var focal = view[2];
        var x0 = frame[0];
        var y0 = frame[1];
        var z0 = frame[2];
        var x1 = frame[3];
        var y1 = frame[4];
        var z1 = frame[5];
        var x2 = frame[6];
        var y2 = frame[7];
        var z2 = frame[8];
        var havePrevious = false;
        var previousX = 0;
        var previousY = 0;
        var n = run.size();
        var i = 0;
        while (i < n) {
            var tE = run[i];
            var tN = run[i + 1];
            var tU = run[i + 2];
            var forward = BACK_SIGN * (tE * z0 + tN * z1 + tU * z2);
            if (forward >= MIN_FORWARD) {
                var px = (cx + focal * (tE * x0 + tN * x1 + tU * x2) / forward).toNumber();
                var py = (cy - focal * (tE * y0 + tN * y1 + tU * y2) / forward).toNumber();
                if (havePrevious) {
                    dc.drawLine(previousX, previousY, px, py);
                }
                previousX = px;
                previousY = py;
                havePrevious = true;
            } else {
                havePrevious = false;
            }
            i += 3;
        }
    }

    // The frame for vectors kept in some other set of axes. rows maps those axes
    // into East-North-Up, row-major with rows E, N and U. Folding it in once a
    // frame lets a whole grid kept in that other set go straight through drawRun.
    function rotateFrame(frame as Lang.Array<Lang.Float>, rows as Lang.Array<Lang.Float>) as Lang.Array<Lang.Float> {
        var out = new [9];
        var c = 0;
        while (c < 3) {
            var k = 0;
            while (k < 3) {
                out[3 * c + k] = frame[k] * rows[c] + frame[3 + k] * rows[3 + c] + frame[6 + k] * rows[6 + c];
                k += 1;
            }
            c += 1;
        }
        return out;
    }
}
