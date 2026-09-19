using Toybox.WatchUi as WatchUi;

module SkyMenus {
    function buildRootMenu() {
        var menu = new WatchUi.Menu2({:title => "Locate Sky Object"});
        menu.addItem(new WatchUi.MenuItem("Show All", null, "all", {}));
        menu.addItem(new WatchUi.MenuItem("Sun", null, "sun", {}));
        menu.addItem(new WatchUi.MenuItem("Moon", null, "moon", {}));
        menu.addItem(new WatchUi.MenuItem("Planets", null, "planets", {}));
        menu.addItem(new WatchUi.MenuItem("Stars", null, "stars", {}));
        return menu;
    }

    function buildObjectMenu(title, objList) {
        var menu = new WatchUi.Menu2({:title => title});
        var sorted = sortedByName(objList);
        var i = 0;
        while (i < sorted.size()) {
            var o = sorted[i];
            menu.addItem(new WatchUi.MenuItem(o[:name], null, o[:id], {}));
            i += 1;
        }
        return menu;
    }

    // Listed by name, whatever order the catalogue holds them in. The catalogue
    // orders stars by brightness and planets by distance from the Sun, and neither
    // helps when you are thumbing down 28 entries looking for Vega.
    //
    // Sorted into a copy rather than in place: a star's id is its position in the
    // catalogue, so the catalogue's own order is not ours to move. Insertion sort,
    // because the lists are short and this runs once as the menu opens, and
    // Array.sort needs API 5, above this app's minimum of 3.4.
    function sortedByName(objList) {
        var out = [];
        var i = 0;
        while (i < objList.size()) {
            var o = objList[i];

            var at = 0;
            while (at < out.size() && out[at][:name].compareTo(o[:name]) < 0) {
                at += 1;
            }

            var head = out.slice(0, at);
            head.add(o);
            out = head.addAll(out.slice(at, null));

            i += 1;
        }
        return out;
    }

    // Each item carries its current value as the sub-label, and selecting it steps
    // that value on (see SettingsMenuDelegate). The two spacings come first because
    // they are what is on the screen; what is allowed to move follows.
    function buildSettingsMenu() {
        var menu = new WatchUi.Menu2({:title => "Settings"});
        menu.addItem(new WatchUi.MenuItem("Horizon Grid", Settings.label("horizon"), "horizon", {}));
        menu.addItem(new WatchUi.MenuItem("Equatorial Grid", Settings.label("equatorial"), "equatorial", {}));
        menu.addItem(new WatchUi.MenuItem("Constellations", Settings.label("constellations"), "constellations", {}));
        menu.addItem(new WatchUi.MenuItem("Sun Path", Settings.label("sunPath"), "sunPath", {}));
        menu.addItem(new WatchUi.MenuItem("Moon Path", Settings.label("moonPath"), "moonPath", {}));
        menu.addItem(new WatchUi.MenuItem("Crosshair", Settings.label("crosshair"), "crosshair", {}));
        menu.addItem(new WatchUi.MenuItem("Update Location", Settings.label("location"), "location", {}));
        return menu;
    }
}
