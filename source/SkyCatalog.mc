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
        var stars = StarCatalog.getStars();
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
