using Toybox.Test;
using Toybox.Math as Math;

// The data the app draws from, and the small pure helpers that decide how it
// looks: SkyCatalog, Constellations and ObjectArt.
//
// Mostly integrity checks. Coordinate typos in a catalogue do not crash anything.
// They put a star in the wrong place, which is hard to spot by looking at the
// screen.

// ---------------------------------------------------------------- the catalogue

(:test)
function catalogueHoldsEverythingItShould(logger) {
    var all = SkyCatalog.objects();
    Test.assertMessage(all.size() == 35, "Sun, Moon, five planets and 28 stars");
    Test.assertMessage(SkyCatalog.planets().size() == 5, "Mercury through Saturn");
    Test.assertMessage(SkyCatalog.stars().size() == 28, "28 bright stars");
    return true;
}

(:test)
function everyObjectIsFindableByItsOwnId(logger) {
    // Star ids are positions in the catalogue, so a reordering that did not
    // regenerate them would break lookup for everything after the change.
    var all = SkyCatalog.objects();
    var i = 0;
    while (i < all.size()) {
        var obj = all[i];
        var found = SkyCatalog.findById(obj[:id]);
        Test.assertMessage(found != null, "every object should be findable");
        Test.assertMessage(found[:name].equals(obj[:name]), "and should find the right one");
        i += 1;
    }
    return true;
}

(:test)
function unknownIdReturnsNothing(logger) {
    Test.assertMessage(SkyCatalog.findById("pluto") == null, "an id not in the catalogue finds nothing");
    Test.assertMessage(SkyCatalog.findById("") == null, "and neither does an empty one");
    return true;
}

(:test)
function catalogueIdsAreUnique(logger) {
    var all = SkyCatalog.objects();
    var i = 0;
    while (i < all.size()) {
        var j = i + 1;
        while (j < all.size()) {
            Test.assertMessage(!all[i][:id].equals(all[j][:id]), "ids must be unique or lookup is ambiguous");
            j += 1;
        }
        i += 1;
    }
    return true;
}

(:test)
function starCoordinatesAreInRange(logger) {
    // A typo here puts a star somewhere else in the sky and nothing complains.
    var stars = SkyCatalog.stars();
    var i = 0;
    while (i < stars.size()) {
        var s = stars[i];
        Test.assertMessage(s[:ra] >= 0.0 && s[:ra] < 360.0, "right ascension must be in range");
        Test.assertMessage(s[:dec] >= -90.0 && s[:dec] <= 90.0, "declination must be in range");
        Test.assertMessage(s[:mag] > -2.0 && s[:mag] < 3.0, "these are naked-eye stars");
        Test.assertMessage(s[:name].length() > 0, "every star needs a name");
        i += 1;
    }
    return true;
}

(:test)
function knownStarsSitWhereTheyShould(logger) {
    // Two anchors anyone can check: Polaris is almost exactly at the north pole of
    // the sky, and Sirius is the brightest star there is.
    var stars = SkyCatalog.stars();
    var polaris = null;
    var brightest = stars[0];
    var i = 0;
    while (i < stars.size()) {
        if (stars[i][:name].equals("Polaris")) {
            polaris = stars[i];
        }
        if (stars[i][:mag] < brightest[:mag]) {
            brightest = stars[i];
        }
        i += 1;
    }
    Test.assertMessage(polaris != null, "Polaris should be in the catalogue");
    Test.assertMessage(polaris[:dec] > 89.0, "Polaris sits within a degree of the pole");
    Test.assertMessage(brightest[:name].equals("Sirius"), "Sirius is the brightest star in the sky");
    return true;
}

(:test)
function parallaxIsAppliedToTheMoonAlone(logger) {
    // Every other body is too far away for the difference between Earth's centre
    // and its surface to register.
    var jd = SkyMath.julianDay(2026, 9, 6, 0, 0, 0);
    var moon = SkyCatalog.findById("moon");
    Test.assertMessage(SkyCatalog.horizontalParallax(moon, jd) > 0.85, "the Moon gets a real correction");

    var sun = SkyCatalog.findById("sun");
    Test.assertMessage(SkyCatalog.horizontalParallax(sun, jd) == 0.0, "the Sun does not");
    var mars = SkyCatalog.findById("mars");
    Test.assertMessage(SkyCatalog.horizontalParallax(mars, jd) == 0.0, "nor do the planets");
    return true;
}

// ---------------------------------------------------------------- constellations

(:test)
function constellationRunsAreWellFormed(logger) {
    // Points are stored in flat pairs, so an odd length means a coordinate was
    // dropped and every vertex after it is shifted by one, which draws a figure
    // that looks plausible and is wrong.
    var figures = Constellations.build();
    Test.assertMessage(figures.size() > 0, "there should be figures to draw");

    var i = 0;
    while (i < figures.size()) {
        var run = figures[i];
        Test.assertMessage(run.size() % 2 == 0, "coordinates must come in pairs");
        Test.assertMessage(run.size() >= 4, "a run needs at least two points to be a line");

        var j = 0;
        while (j < run.size()) {
            Test.assertMessage(run[j] >= 0.0 && run[j] < 360.0, "right ascension must be in range");
            Test.assertMessage(run[j + 1] >= -90.0 && run[j + 1] <= 90.0, "declination must be in range");
            j += 2;
        }
        i += 1;
    }
    return true;
}

(:test)
function constellationVerticesMatchTheirCatalogueStars(logger) {
    // A dozen vertices are repeated from SkyCatalog rather than looked up. If the
    // two lists drift apart, the figure hangs off its own star, so this checks the
    // repeated vertices still match.
    var stars = SkyCatalog.stars();
    var figures = Constellations.build();

    var names = ["Betelgeuse", "Rigel", "Polaris", "Antares", "Deneb", "Regulus"];
    var n = 0;
    while (n < names.size()) {
        var star = null;
        var s = 0;
        while (s < stars.size()) {
            if (stars[s][:name].equals(names[n])) {
                star = stars[s];
            }
            s += 1;
        }
        Test.assertMessage(star != null, "the anchor star should be in the catalogue");

        // Somewhere in the figures there must be a vertex sitting on it.
        var matched = false;
        var i = 0;
        while (i < figures.size()) {
            var run = figures[i];
            var j = 0;
            while (j < run.size()) {
                if ((run[j] - star[:ra]).abs() < 0.01 && (run[j + 1] - star[:dec]).abs() < 0.01) {
                    matched = true;
                }
                j += 2;
            }
            i += 1;
        }
        Test.assertMessage(matched, "a constellation vertex should still sit on its catalogue star");
        n += 1;
    }
    return true;
}

// ---------------------------------------------------------------- appearance

(:test)
function shadeDarkensEachChannelEvenly(logger) {
    Test.assertMessage(ObjectArt.shade(0xFFFFFF, 1, 2) == 0x7F7F7F, "half of white is mid grey");
    Test.assertMessage(ObjectArt.shade(0xFFFFFF, 1, 1) == 0xFFFFFF, "a whole share changes nothing");
    Test.assertMessage(ObjectArt.shade(0xFFFFFF, 0, 1) == 0x000000, "no share is black");
    return true;
}

(:test)
function shadeKeepsChannelsApart(logger) {
    // The channels must not bleed into one another: a shift done in the wrong
    // order would turn a dimmed red into a different colour.
    var dimmedRed = ObjectArt.shade(0xFF0000, 1, 2);
    Test.assertMessage(dimmedRed == 0x7F0000, "red should stay red");
    var dimmedBlue = ObjectArt.shade(0x0000FF, 1, 4);
    Test.assertMessage(dimmedBlue == 0x00003F, "blue should stay blue");
    return true;
}

(:test)
function shadeNeverOverflowsAChannel(logger) {
    // Every shade in the app comes off one base colour, so this runs on all of
    // them at every ratio the drawing uses.
    var all = SkyCatalog.objects();
    var ratios = [[1, 6], [1, 4], [2, 5], [1, 3], [3, 5], [4, 5]];
    var i = 0;
    while (i < all.size()) {
        var base = ObjectArt.color(all[i]);
        var r = 0;
        while (r < ratios.size()) {
            var shaded = ObjectArt.shade(base, ratios[r][0], ratios[r][1]);
            Test.assertMessage(shaded >= 0 && shaded <= 0xFFFFFF, "a shade must stay a colour");
            Test.assertMessage(((shaded >> 16) & 0xFF) <= 0xFF, "red channel must not overflow");
            Test.assertMessage(((shaded >> 8) & 0xFF) <= 0xFF, "green channel must not overflow");
            Test.assertMessage((shaded & 0xFF) <= 0xFF, "blue channel must not overflow");
            r += 1;
        }
        i += 1;
    }
    return true;
}

(:test)
function everyObjectHasADrawableSize(logger) {
    // Nothing may come out at zero radius, or it is in the sky and invisible.
    var all = SkyCatalog.objects();
    var i = 0;
    while (i < all.size()) {
        var r = ObjectArt.radius(all[i]);
        Test.assertMessage(r >= 2, "every object needs to be big enough to see");
        Test.assertMessage(r <= 20, "and small enough not to swamp the screen");
        i += 1;
    }
    return true;
}

(:test)
function brighterStarsDrawLarger(logger) {
    // Radius is magnitude-scaled, and magnitude runs backwards: lower is brighter.
    var bright = ObjectArt.radius({:type => :star, :mag => -1.46});
    var faint = ObjectArt.radius({:type => :star, :mag => 2.2});
    Test.assertMessage(bright > faint, "Sirius should draw larger than a second-magnitude star");

    // Clamped at both ends so nothing runs away.
    var absurd = ObjectArt.radius({:type => :star, :mag => -30.0});
    Test.assertMessage(absurd == 7, "the radius is capped");
    var invisible = ObjectArt.radius({:type => :star, :mag => 30.0});
    Test.assertMessage(invisible == 2, "and floored");

    var unknown = ObjectArt.radius({:type => :star});
    Test.assertMessage(unknown == 3, "a star with no magnitude gets a default");
    return true;
}

(:test)
function theSunAndMoonAreTheBiggestThings(logger) {
    var sun = ObjectArt.radius(SkyCatalog.findById("sun"));
    var moon = ObjectArt.radius(SkyCatalog.findById("moon"));
    var jupiter = ObjectArt.radius(SkyCatalog.findById("jupiter"));
    Test.assertMessage(sun > moon, "the Sun draws largest");
    Test.assertMessage(moon > jupiter, "then the Moon");
    return true;
}

// ---------------------------------------------------------------- labels

(:test)
function gridLabelSaysTheHoursWhenItCan(logger) {
    // The sky turns 15 degrees an hour, so spacings that divide into that say so.
    Test.assertMessage(Settings.gridLabel(0).equals("Off"), "zero is off");
    Test.assertMessage(Settings.gridLabel(15).equals("15 deg - 1 h"), "15 degrees is one hour");
    Test.assertMessage(Settings.gridLabel(60).equals("60 deg - 4 h"), "60 degrees is four hours");
    Test.assertMessage(Settings.gridLabel(10).equals("10 deg"), "10 degrees is not a whole hour");
    return true;
}

// The grid list offers Off and nothing finer than this watch can draw, so the
// menu can never step onto a spacing that stops the app.
(:test)
function gridChoicesStopAtTheFinestThisWatchCanDraw(logger) {
    var choices = Settings.specs()["horizon"][1];
    var finest = Settings.finestGrid();
    Test.assertMessage(choices[0] == 0, "Off should come first");
    var i = 1;
    while (i < choices.size()) {
        Test.assertMessage(choices[i] >= finest, "no spacing finer than the watch can draw");
        i += 1;
    }
    Test.assertMessage(choices[choices.size() - 1] == finest, "the finest allowed spacing should be offered");
    return true;
}
