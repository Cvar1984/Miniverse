using Toybox.WatchUi as WatchUi;

class RootMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var id = item.getId();
        if (id == null) {
            return;
        }
        if (id.equals("all")) {
            // No object to aim at: a null one puts the pointer screen into its
            // whole-catalogue mode.
            WatchUi.pushView(new PointerView(null), new PointerDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id.equals("planets")) {
            WatchUi.pushView(SkyMenus.buildObjectMenu("Planets", SkyCatalog.planets()), new ObjectMenuDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id.equals("stars")) {
            WatchUi.pushView(SkyMenus.buildObjectMenu("Stars", SkyCatalog.stars()), new ObjectMenuDelegate(), WatchUi.SLIDE_LEFT);
        } else {
            var obj = SkyCatalog.findById(id);
            if (obj != null) {
                WatchUi.pushView(new PointerView(obj), new PointerDelegate(), WatchUi.SLIDE_LEFT);
            }
        }
    }
}
