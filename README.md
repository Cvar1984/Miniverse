# Miniverse

A sky pointer for Garmin watches. Pick an object — the Sun, the Moon, a planet, a
bright star — hold the watch up with the back facing the sky, and the object is
drawn where it really is behind the case. Move your arm until the marker settles in
the middle of the screen and you are looking straight at it.

It is the idea behind a phone astronomy app held up with its camera, on a wrist,
with no network, no phone, and no chart to orient yourself against first.

![Root menu](Screenshoot/G94J3307.png)

## Contents

- [How it works](#how-it-works)
- [Screens](#screens)
- [Settings](#settings)
- [The maths](#the-maths)
  - [1. Time](#1-time)
  - [2. Where the object is](#2-where-the-object-is)
  - [3. Turning that into a direction in the sky](#3-turning-that-into-a-direction-in-the-sky)
  - [4. Corrections](#4-corrections)
  - [5. Where the watch is pointing](#5-where-the-watch-is-pointing)
  - [6. Putting the sky on the screen](#6-putting-the-sky-on-the-screen)
  - [7. The two grids](#7-the-two-grids)
  - [8. Turn-and-tilt guidance](#8-turn-and-tilt-guidance)
  - [9. Drawing the objects](#9-drawing-the-objects)
- [Source map](#source-map)
- [Cost and frame time](#cost-and-frame-time)
- [Building](#building)
- [Devices](#devices)
- [Accuracy](#accuracy)
- [Licence](#licence)

## How it works

The aim axis is the watch's Z axis, straight out through the **back** of the case —
not the 12 o'clock edge. That is what makes it a viewfinder rather than a compass
arrow: you look at the screen, the sky is behind it, and the object is drawn at the
place on the glass you would see it through if the watch were transparent.

Because it is a window, turning your wrist turns what you see through it. The
picture is built in the watch's own frame and rolls with your hand. The written
turn/tilt guidance underneath does **not** — it is measured against gravity,
because it describes how to swing your arm, which has nothing to do with how the
watch is rotated in your grip.

The whole chain, once per frame at 10 Hz:

```
       clock ──► Julian Day ──► sidereal time ─┐
                                               ├──► RA/Dec ──► alt/az ──► ENU unit vector
   catalogue / orbital elements ───────────────┘                              │
                                                                              ▼
  accelerometer ──► gravity ──┐                                     rotate into watch axes
                              ├──► device frame (east, north, up) ──►         │
  magnetometer ──► field ─────┘                                               ▼
                                                                    perspective divide
                                                                              │
                                                                              ▼
                                                                         screen x, y
```

## Screens

### Aiming at one object

![Moon with phase, locked on](Screenshoot/G94J1340.png)

The object name at the top, the marker where the object is, and four readouts. Each
readout pairs the object against the aim on the same axis — `Alt obj +30  aim +25`
— so the two numbers converge as you settle onto it. Showing both halves is
deliberate: a sensor axis wired the wrong way makes the pair diverge as you close
in, which is obvious, instead of just being puzzling.

Within 8° of the object the marker takes a green ring and the guidance is replaced
by **On target**. Below the horizon it takes a red one — the object is real and
correctly placed, it is just underneath you.

When the object is off the edge of the view it pins to the rim with a chevron
pointing further the way to move, inset far enough that the marker and its chevron
both stay on the glass.

### Show All

![Show All with both grids](Screenshoot/G94J1044.png)

The whole catalogue at once — 35 objects, Sun, Moon, five planets and 28 bright
stars — as a plain sky map. Nothing is being aimed at, so there is nothing to steer
towards and no turn/tilt guidance: the single line at the bottom says only where
the watch is currently pointing.

Objects below the horizon are darkened rather than greyed out, so they still read
as underfoot without losing the colour and the face that identify them. Nothing is
pinned to the rim in this mode — with the whole sky on show, markers would pile up
around the edge — so an object that is not in front of the watch is simply not
drawn.

Above: both grids on at 60°, the blue horizon grid crossing the red equatorial one,
with `N` at the north point.

### The grids

![Horizon grid at 10 degrees, near the zenith](Screenshoot/G94J1216.png)

Aimed near the zenith with the horizon grid at 10°, where the vertical circles all
converge on the point overhead. The dense end of the range: 36 vertical circles and
13 circles of equal altitude.

## Settings

Hold the **up/menu** button on any sky screen. Every setting changes what is on the
screen behind, so they are reachable from the screen they affect rather than only
from the root menu. Selecting an item steps it to its next value in place — a short
list is quicker to thumb through than a submenu, and the label cannot go stale
behind the menu showing it.

![Settings](Screenshoot/G94J3349.png)

| Setting | Values | Default |
|---|---|---|
| Horizon Grid | Off · 60 · 45 · 30 · 15 · 10 degrees | Off |
| Equatorial Grid | Off · 60 · 45 · 30 · 15 · 10 degrees | Off |
| Equatorial Motion | Held still · Turns with sky | Held still |
| Azimuth Motion | Held still · Follows position | Held still |
| Update Location | One fix only · every 5 / 15 / 30 / 60 min | One fix only |

Spacings that come to a whole number of hours say so — the sky turns 360° in 24
hours, so 15° is one hour of it and the grid divides the sky into hour-wide cells.

Everything starts off and held still. The sky is what the screen is for; a grid over
it is a reference you ask for rather than one you have to dismiss, and a reference
is worth more when it stays where it was put.

**Azimuth Motion** has nothing but position updates to follow — the horizon frame
has no clock in it — so with location updates off it says `On - no updates` rather
than claiming to follow something that never arrives.

The display is held awake while a sky screen is up, re-arming the backlight every 3
seconds. Burn-in protection means the system refuses to hold it on indefinitely
(about a minute at a stretch), so the refusal is caught and the panel given a
10-second rest before asking again.

---

# The maths

Everything below runs on the watch, from the clock and two sensors. No network, no
almanac file, no phone.

## 1. Time

### Julian Day

`SkyMath.julianDay` — the standard Gregorian algorithm. For `y`, `m` with January
and February counted as months 13 and 14 of the previous year:

```
a  = floor(y / 100)
b  = 2 - a + floor(a / 4)
JD = floor(365.25 · (y + 4716)) + floor(30.6001 · (m + 1)) + d + b - 1524.5
     + (hh + mm/60 + ss/3600) / 24
```

**This one must be 64-bit.** A Julian Day this century runs to about 2 460 000, and
a 32-bit float carries roughly seven significant digits — enough for the date and
nothing whatever for the time of day, which rounds to the nearest six hours.

Measured against the sky: an observation at 04:06 wants JD 2461286.37917; a float
holds 2461286.5, and those 2.9 hours moved Saturn from 61° up in the south-west down
to 19°. Whole evenings collapse onto one stored value, so a position sits frozen and
then jumps. The leading `.toDouble()` is what forces the running total wide — the
terms before it are exact whole numbers a float still holds safely.

### Sidereal time

Greenwich Mean Sidereal Time, in degrees, with `D` the days since J2000 and
`T = D / 36525`:

```
GMST = 280.46061837 + 360.98564736629·D + 0.000387933·T² − T³/38710000
LST  = GMST + longitude          (east-positive)
```

Also 64-bit, and for the same reason: `D` is multiplied by 361 before being wrapped
back into a circle, passing through three and a half million degrees on the way.

The `.98564736629` is the whole point — the sky turns *slightly more* than 360° per
solar day, which is why a star rises about four minutes earlier each night.

## 2. Where the object is

Every object resolves to a geocentric right ascension and declination at a given
Julian Day. Four different routes get there.

### Stars — `StarCatalog`

28 naked-eye stars as literal J2000 RA/Dec plus visual magnitude. Proper motion and
precession are ignored; both are far below what a wrist magnetometer can resolve.

### Sun — `SolarLunar.sunPosition`

Meeus, abbreviated. Mean longitude, mean anomaly, equation of the centre, then the
apparent longitude corrected for aberration and nutation:

```
L₀ = 280.46646 + 36000.76983·T + 0.0003032·T²
M  = 357.52911 + 35999.05029·T − 0.0001537·T²
C  = (1.914602 − 0.004817·T − 0.000014·T²)·sin M
   + (0.019993 − 0.000101·T)·sin 2M
   + 0.000289·sin 3M
Ω  = 125.04 − 1934.136·T
λ  = L₀ + C − 0.00569 − 0.00478·sin Ω
ε  = ε₀ + 0.00256·cos Ω
```

### Moon — `SolarLunar.moonPosition`

The hard one, and the reason there is a series rather than a formula. Built from the
four fundamental arguments — mean elongation `D`, solar anomaly `M`, lunar anomaly
`M′` and argument of latitude `F` — with a 13-term longitude series and a 10-term
latitude series. The largest terms:

```
Δλ = 6.288774·sin M′ + 1.274027·sin(2D − M′) + 0.658314·sin 2D + …
Δβ = 5.128122·sin F  + 0.280602·sin(M′ + F)  + 0.277693·sin(M′ − F) + …
```

`6.29·sin M′` is the elliptical orbit; `1.27·sin(2D − M′)` is evection, the Sun
stretching the orbit; `0.66·sin 2D` is variation. `5.13·sin F` is simply the 5.1°
tilt of the Moon's orbit against the ecliptic.

### Planets — `Planets`

Mercury through Saturn from approximate Keplerian elements, in the style of Paul
Schlyter's *How to compute planetary positions*. Each planet's elements — ascending
node `N`, inclination `i`, argument of perihelion `w`, semi-major axis `a`,
eccentricity `e`, mean anomaly `M` — are linear in the day number.

Kepler's equation `M = E − e·sin E` has no closed form, so it is solved by Newton
iteration from a first guess, to 10⁻⁶ degrees or eight passes:

```
E₀ = M + (180/π)·e·sin M·(1 + e·cos M)
Eₙ₊₁ = Eₙ + (M − (Eₙ − (180/π)·e·sin Eₙ)) / (1 − e·cos Eₙ)
```

Then true anomaly and radius from the eccentric anomaly, rotated out of the orbital
plane into heliocentric ecliptic coordinates, and the Sun's own geocentric vector
added to shift the origin from the Sun to the Earth:

```
x_g = x_helio + x_sun
y_g = y_helio + y_sun
z_g = z_helio
```

That last addition is the parallax of the whole Earth's orbit, and it is what makes
Mars swing backwards through the sky a few weeks a year.

### Ecliptic to equatorial

All three computed bodies come out in ecliptic coordinates and are rotated by the
obliquity `ε = 23.439291 − 0.0130042·T − …`:

```
sin δ = sin β·cos ε + cos β·sin ε·sin λ
tan α = (sin λ·cos ε − tan β·sin ε) / cos λ
```

## 3. Turning that into a direction in the sky

`SkyMath.raDecToAltAz`. With hour angle `H = LST − α`, latitude `φ`:

```
sin(alt) = sin δ·sin φ + cos δ·cos φ·cos H
cos(A)   = (sin δ − sin φ·sin alt) / (cos φ·cos alt)
az       = 360° − A   if sin H > 0,  else A
```

Azimuth from north, clockwise through east. The `sin H` branch is what resolves the
ambiguity `acos` leaves — east or west of the meridian.

Then to a world East-North-Up unit vector:

```
E = cos(alt)·sin(az)
N = cos(alt)·cos(az)
U = sin(alt)
```

## 4. Corrections

Both act along the vertical circle, so azimuth is untouched.

### Parallax

Everything above answers for the **centre of the Earth**. You are 6378 km off that
centre. For the Moon that matters:

```
alt′ = alt − π·cos(alt)
```

where `π` is the horizontal parallax from Meeus' series:

```
π = 0.9508 + 0.0518·cos M′ + 0.0095·cos(2D − M′) + 0.0078·cos 2D + 0.0028·cos 2M′
```

That runs to about **0.95°** — nearly two full-Moon widths — which is why the Moon
is the only body corrected. The Sun comes to 0.0024°, the planets at closest
approach to 0.009°, and the stars to nothing. Earth's polar flattening would move
the answer by ~12 arcseconds and is ignored.

### Refraction

Bennett's formula, in arcminutes:

```
R = 1 / tan(h + 7.31/(h + 4.4))
```

About **0.57° at the horizon**, 0.09° at ten degrees up, and negligible overhead —
so it matters for exactly the objects that are hardest to find anyway, the ones just
clearing the skyline. It is what makes the Sun visibly still up when it has
geometrically already set.

## 5. Where the watch is pointing

Two sensors, polled at 10 Hz rather than waited on — the push callbacks fire about
once a second, which is far too slow and too stale to aim with while moving.

### Smoothing

Exponential smoothing at 0.2 per sample, applied to the **raw sensor vectors**, not
to angles derived from them. This is what Stellarium's `SensorsMgr` does and for the
same reason: magnetometer noise is what makes a sky view jitter, and it settles far
better averaged as vectors. Stellarium runs 0.01–0.1 per frame at display rate and
smooths harder the tighter the field of view; 0.2 at 10 Hz is the equivalent for an
8° lock.

Heading is smoothed the short way round the circle, so 359° → 1° does not swing
backwards through 358.

### Gravity

```
up = −accel / |accel|
```

The sign is a hardware fact, not a choice: this device reports the gravity direction
rather than specific force. Each such convention lives in a named constant with a
check you can run on the pointer screen — aim the back at the horizon and the aim
elevation should read about 0; tip it skyward and it should climb.

### Tilt-compensated magnetic azimuth

The system's compass heading is a **flat** reading and goes wrong the moment you tilt
the watch up at the sky, which is the only thing you ever do with this app. So the
azimuth is worked out from the raw magnetometer instead.

Flatten both the field and the aim axis onto the plane at right angles to gravity:

```
n = m − (m·u)u          magnetic north along the ground
p = b − (b·u)u          the back axis, flattened
az = atan2((p × n)·u, p·n)
```

Removing the vertical component of the field is the whole trick — what is left points
north however the watch is tilted. Stellarium does the same, de-rotating the raw
field by the device's own roll and pitch rather than trusting a system heading.

### Magnetic declination

The system heading is worth exactly one thing: while the watch happens to be near
level it is both trustworthy *and* corrected to true north. The gap between it and
the computed magnetic azimuth is therefore the local declination:

```
declination ← declination + 0.05·(systemHeading − magneticAz)
```

banked slowly, only while `|elevation| < 25°`, and then applied at any tilt.
Averaging stops after 100 near-level samples — well past converged — so the
reference stops creeping. A fresh position re-opens it, if Azimuth Motion is on.

### The device frame

`DeviceAim.deviceFrame` returns the world's axes written in the watch's coordinates:

```
east  = handedness · (north × up)
north = n
up    = u
```

Multiplying a sky direction's world components by these lands it in the watch's own
frame. `viewOffset` does that and flips the forward axis, because the aim is out
through the back:

```
right   =  t·east_watch
up      =  t·north_watch
forward = −t·up_watch          (BACK_SIGN)
```

All three are direction cosines, ready for a perspective divide. Keeping the back
sign separate from the handedness sign matters: tangling them flips the sideways and
forward components together, the flip cancels in the sideways divide, and the result
can only ever invert up and down — which looks like the object following the watch
instead of sliding against it.

## 6. Putting the sky on the screen

A pinhole camera. With `f` the focal length in pixels:

```
x = cx + f · right / forward
y = cy − f · up    / forward
f = cx / tan(45°) = cx
```

so the screen spans **90° of sky** across its width, and the same down its height on
a square display. The perspective divide is what makes the sky line up the way a
camera would, rather than merely pointing in the right general direction: at the
edges of a 90° field the difference between the two is large.

Anything with `forward < 0.1` — more than about 84° off the aim — is level with the
back of the watch or behind it, where a perspective projection has nothing to say. It
is dropped, which breaks grid lines cleanly instead of folding them back across the
view.

Nothing is clipped and no band is reserved. The sky is laid down across the whole
display and the text is drawn on top of it afterwards.

## 7. The two grids

They answer different questions, and the difference between them is the point of
having both.

| | anchored to | moves when |
|---|---|---|
| **Horizon** (`HorizonGrid`) — circles of equal altitude, vertical circles between zenith and nadir | the ground and the compass | you move the watch |
| **Equatorial** (`EquatorialGrid`) — circles of equal declination, hour circles between the celestial poles | the stars | you move the watch, **and** as time passes |

The horizon grid takes no clock and no position: `(az, alt)` maps straight to a
direction. Rest the watch flat on a table and it looks at the nadir, with the
vertical circles converging in the middle of the screen.

The equatorial grid runs every point through `raDecToAltAz(ra, dec, lat, LST)`.
Sidereal time is the only thing in that chain that moves, so **pinning LST to one
reading is what holds the grid still** — which is the default. Let loose, it turns at
15° per hour, one full revolution per sidereal day, pivoting about the celestial
poles at altitude = your latitude. Turn both on and you can watch the red grid slide
past the stationary blue one.

Both count outwards from their zero line — the horizon, the celestial equator — rather
than up from the bottom, so that line is always drawn whatever the spacing is set to.
It is the one worth guaranteeing.

Cardinal letters are drawn even with the horizon grid off. Which way you are facing
is the most directly useful thing on the screen, and it is not grid furniture.

## 8. Turn-and-tilt guidance

Measured against gravity rather than the watch's own axes, so rolling your wrist
leaves it alone. `aimBasis` builds a frame from the aim direction plus a horizontal
"right" and a perpendicular "up":

```
d     = (cos ε·sin θ, cos ε·cos θ, sin ε)      aim
right = d × up = (d_N, −d_E, 0) / cos ε
up    = right × d
```

and `project` puts the object into it:

```
turn = atan2(alongRight, alongAim)
tilt = atan2(alongUp, √(alongAim² + alongRight²))
```

Tilt is measured off the aim's own **horizontal plane**, not straight off the aim
axis. Both amount to the same thing near the object, but this stays well defined when
it is far to one side — where "aim" and "up" both fall to zero and dividing one by the
other is meaningless.

Aimed within a couple of degrees of straight up or down there is no sensible "turn
left" to give, since every direction is sideways from there. Those two lines drop out;
the picture still holds.

## 9. Drawing the objects

`ObjectArt`. Stellarium wraps photographic surface maps onto spheres on the GPU. None
of that survives the trip down to a disc 32 pixels across, and the maps are
equirectangular — made to be projected, not pasted. So what is drawn is the handful of
features still recognisable as *shapes* at this size.

### Moon phase

The real one, from the same geometry Stellarium uses. Both directions are unit
vectors, so their dot product is the cosine of the elongation and the lit fraction
falls straight out:

```
k = (1 − m·s) / 2
```

What the drawing wants is the terminator ellipse's semi-axis as a fraction of the
disc, `c = 2k − 1`, which reduces to simply:

```
c = −(m·s)
```

running from −1 at new, through 0 at half, to +1 at full. The bright limb faces the
Sun, so the whole figure is oriented by the tangent direction from the Moon towards
it:

```
t = s − (s·m)m
```

taken from the geometry rather than off the screen, which is why it stays right as
your wrist rolls.

It is drawn as a dark disc, then the bright hemisphere, then the terminator ellipse
in whichever colour that side ended up — **two convex half-ellipses rather than one
lune**, because a crescent is concave and how a device fills a concave polygon is not
something to rely on.

### The rest

- **Sun** — corona rings outside the disc, and a disc brightening towards the middle
  for limb darkening.
- **Saturn** — rings, drawn before the disc so the planet sits in front of them.
- **Jupiter** — two belts either side of the equator, which is as much as any small
  telescope shows.
- **Stars** — magnitude-scaled radius, `r = clamp(5 − magnitude, 2, 7)`, so brighter
  stars draw larger the way they look.

Rings and belts lie along the local horizontal, derived from where the zenith falls in
the watch axes, so they roll with the sky rather than staying pinned to the screen.

## Source map

| File | What it does |
|---|---|
| `PointerView.mc` | The sky screen: sensors, layout, both modes, drawing |
| `ObjectArt.mc` | Colour, size and face of each body; Moon phase |
| `DeviceAim.mc` | Orientation, tilt-compensated compass, projection |
| `Settings.mc` | Persisted choices, cached in memory |
| `SkyMath.mc` | Time, coordinate conversion, refraction, parallax |
| `HorizonGrid.mc` | Alt/az grid and cardinal letters |
| `EquatorialGrid.mc` | RA/Dec grid |
| `Planets.mc` | Keplerian planetary positions |
| `SolarLunar.mc` | Sun and Moon series, obliquity, parallax |
| `SkyCatalog.mc` | The object registry and RA/Dec dispatch |
| `SettingsMenuDelegate.mc` | Cycling settings in place |
| `SkyMenus.mc` | Menu construction |
| `StarCatalog.mc` | 28 bright stars, J2000 |
| `RootMenuDelegate.mc` | Root menu routing |
| `PointerDelegate.mc` | Back, and the menu button |
| `ObjectMenuDelegate.mc` | Object list routing |
| `MiniverseApp.mc` | Entry point |

## Cost and frame time

`onUpdate` runs at 10 Hz and every plotted grid point costs a handful of trig calls,
so the two things that dominate are grid density and catalogue size.

- **Grids.** A grid at spacing `s` draws `360/s` vertical circles and `2·(60/s)+1`
  circles of equal altitude, each sampled every 20°. At 15° that is about 410 plotted
  points per grid per frame; at 10° about 610. Both grids on at 10° is roughly 1200.
  `AZ_SAMPLE` and `ALT_SAMPLE` are the knob if that ever costs too much.
- **Show All** works out where all 35 objects are at most every 5 seconds and holds
  the result. The sky turns 15° an hour, so 5 seconds moves it 0.02° — well under a
  pixel — while running the Sun, Moon and planets through their own orbital maths ten
  times a second would cost far more than drawing them does. Only the projection is
  redone per frame. The cache is dropped when your position changes.
- **Position** is event-driven, not per-frame. A cached fix is used immediately; if
  nothing usable arrives within 4 seconds the GPS is driven actively.

## Building

Requires the [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) 6.0.2 or
later and a developer key.

```sh
monkeyc -f monkey.jungle -o bin/Miniverse.prg -y developer_key -d instinctcrossoveramoled
```

Run it in the simulator with `connectiq` followed by `monkeydo bin/Miniverse.prg
instinctcrossoveramoled`, or build for the store with `-e -r`.

Permissions: `Positioning` and `Sensor`.

## Devices

27 products, all round displays from 390×390 up. Layout is derived from the display
size and the real font metrics rather than fixed pixel offsets, so the picture takes
every row the text does not need, and labels are pulled in to where the round glass
actually reaches on each row.

`enduro3` · `fenix843mm` · `fenix847mm` · `fenix8pro47mm` · `fenix8solar47mm` ·
`fenix8solar51mm` · `fenix943mm` · `fenix947mm` · `fenix9pro43mm` · `fenix9pro47mm` ·
`fenix9pro51mm` · `fenix9prosolar47mm` · `fenix9prosolar51mm` · `fenixe` ·
`fr57042mm` · `fr57047mm` · `fr970` · `instinct3amoled45mm` · `instinct3amoled50mm` ·
`instinct3solar45mm` · `instinctcrossoveramoled` · `instincte40mm` · `instincte45mm` ·
`venu441mm` · `venu445mm` · `venux1` · `vivoactive6`

## Accuracy

The limit is the magnetometer, not the astronomy. A wrist compass resolves a few
degrees at best, and every approximation here is chosen to sit comfortably underneath
that:

| Source | Error |
|---|---|
| Sun position | < 0.01° |
| Moon position | ~0.02° |
| Planets | arcminutes |
| Stars (no proper motion or precession) | arcminutes |
| Refraction (Bennett) | < 0.02° above 5° altitude |
| Earth's flattening, ignored | ~12 arcseconds |
| **Wrist magnetometer** | **a few degrees** |

## Licence

GPL-3.0. See [LICENSE](LICENSE).

The approach to sensor handling — smoothing raw vectors rather than angles,
de-rotating the raw field instead of trusting a system heading, and taking the lunar
phase from the elongation — follows [Stellarium](https://github.com/Stellarium/stellarium).
No Stellarium code or assets are used. Solar and lunar series are from Jean Meeus,
*Astronomical Algorithms*; the planetary elements follow Paul Schlyter's *How to
compute planetary positions*.
