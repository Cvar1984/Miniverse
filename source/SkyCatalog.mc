// Registry of everything the app can locate: Sun, Moon, planets and stars.
module SkyCatalog {
    var _objects = null;

    function objects() {
        if (_objects == null) {
            _objects = buildObjects();
        }
        return _objects;
    }

    function buildObjects() {
        var list = [
            {:id => "sun", :name => "Sun", :type => :sun},
            {:id => "moon", :name => "Moon", :type => :moon},
            {:id => "mercury", :name => "Mercury", :type => :planet},
            {:id => "venus", :name => "Venus", :type => :planet},
            {:id => "mars", :name => "Mars", :type => :planet},
            {:id => "jupiter", :name => "Jupiter", :type => :planet},
            {:id => "saturn", :name => "Saturn", :type => :planet}
        ];
        // Bright naked-eye stars: J2000 RA/Dec (degrees) and visual magnitude.
        // Proper motion and precession are ignored; the error is far below what a
        // wrist compass/magnetometer can resolve. Order is the id: star_0 is Sirius.
        var stars = [
            {:name => "Sirius", :ra => 101.287, :dec => -16.716, :mag => -1.46},
            {:name => "Canopus", :ra => 95.988, :dec => -52.696, :mag => -0.74},
            {:name => "Alpha Centauri", :ra => 219.900, :dec => -60.834, :mag => -0.27},
            {:name => "Arcturus", :ra => 213.916, :dec => 19.182, :mag => -0.05},
            {:name => "Vega", :ra => 279.234, :dec => 38.784, :mag => 0.03},
            {:name => "Capella", :ra => 79.172, :dec => 45.998, :mag => 0.08},
            {:name => "Rigel", :ra => 78.634, :dec => -8.202, :mag => 0.13},
            {:name => "Procyon", :ra => 114.825, :dec => 5.225, :mag => 0.34},
            {:name => "Betelgeuse", :ra => 88.793, :dec => 7.407, :mag => 0.50},
            {:name => "Achernar", :ra => 24.429, :dec => -57.237, :mag => 0.46},
            {:name => "Hadar", :ra => 210.956, :dec => -60.373, :mag => 0.61},
            {:name => "Altair", :ra => 297.696, :dec => 8.868, :mag => 0.76},
            {:name => "Aldebaran", :ra => 68.980, :dec => 16.509, :mag => 0.85},
            {:name => "Antares", :ra => 247.352, :dec => -26.432, :mag => 0.96},
            {:name => "Spica", :ra => 201.298, :dec => -11.161, :mag => 1.04},
            {:name => "Pollux", :ra => 116.329, :dec => 28.026, :mag => 1.14},
            {:name => "Fomalhaut", :ra => 344.413, :dec => -29.622, :mag => 1.16},
            {:name => "Deneb", :ra => 310.358, :dec => 45.280, :mag => 1.25},
            {:name => "Regulus", :ra => 152.093, :dec => 11.967, :mag => 1.36},
            {:name => "Castor", :ra => 113.650, :dec => 31.888, :mag => 1.58},
            {:name => "Bellatrix", :ra => 81.283, :dec => 6.350, :mag => 1.64},
            {:name => "Alnilam", :ra => 84.053, :dec => -1.202, :mag => 1.69},
            {:name => "Alnitak", :ra => 85.190, :dec => -1.943, :mag => 1.77},
            {:name => "Alkaid", :ra => 206.885, :dec => 49.313, :mag => 1.86},
            {:name => "Polaris", :ra => 37.955, :dec => 89.264, :mag => 1.98},
            {:name => "Alphard", :ra => 141.897, :dec => -8.659, :mag => 1.98},
            {:name => "Mizar", :ra => 200.981, :dec => 54.925, :mag => 2.23},
            {:name => "Denebola", :ra => 177.265, :dec => 14.572, :mag => 2.14}
        ];
        var i = 0;
        while (i < stars.size()) {
            var s = stars[i];
            list.add({:id => "star_" + i, :name => s[:name], :type => :star, :ra => s[:ra], :dec => s[:dec], :mag => s[:mag]});
            i += 1;
        }
        return list;
    }

    function findById(id) {
        var list = objects();
        var i = 0;
        while (i < list.size()) {
            if (list[i][:id].equals(id)) {
                return list[i];
            }
            i += 1;
        }
        return null;
    }

    function filterByType(t) {
        var list = objects();
        var out = [];
        var i = 0;
        while (i < list.size()) {
            if (list[i][:type] == t) {
                out.add(list[i]);
            }
            i += 1;
        }
        return out;
    }

    function planets() {
        return filterByType(:planet);
    }

    function stars() {
        return filterByType(:star);
    }

    // How far the object's apparent place shifts between Earth's centre and the
    // surface, in degrees. Only the Moon is close enough for this to register: the
    // Sun comes to 0.0024 degrees, the planets at their closest to 0.009, and the
    // stars to nothing, all of them far under what a wrist compass can resolve.
    function horizontalParallax(obj, jd) {
        if (obj[:type] == :moon) {
            return SolarLunar.moonHorizontalParallax(jd);
        }
        return 0.0;
    }

    // Returns [ra, dec] in degrees for the given object at Julian Day jd (UTC).
    function getRaDec(obj, jd) {
        var type = obj[:type];
        if (type == :sun) {
            return SolarLunar.sunPosition(jd);
        } else if (type == :moon) {
            return SolarLunar.moonPosition(jd);
        } else if (type == :planet) {
            return Planets.planetPosition(obj[:id], jd);
        }
        return [obj[:ra], obj[:dec]];
    }
}
