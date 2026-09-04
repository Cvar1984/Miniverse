using Toybox.WatchUi as WatchUi;

module SkyMenus {
    function buildRootMenu() {
        var menu = new WatchUi.Menu2({:title => "Locate Sky Object"});
        menu.addItem(new WatchUi.MenuItem("Sun", null, "sun", {}));
        menu.addItem(new WatchUi.MenuItem("Moon", null, "moon", {}));
        menu.addItem(new WatchUi.MenuItem("Planets", null, "planets", {}));
        menu.addItem(new WatchUi.MenuItem("Stars", null, "stars", {}));
        return menu;
    }

    function buildObjectMenu(title, objList) {
        var menu = new WatchUi.Menu2({:title => title});
        var i = 0;
        while (i < objList.size()) {
            var o = objList[i];
            menu.addItem(new WatchUi.MenuItem(o[:name], null, o[:id], {}));
            i += 1;
        }
        return menu;
    }
}
