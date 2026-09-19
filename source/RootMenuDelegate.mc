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
        switch (id) {
            case "all":
                // No object to aim at: a null one puts the pointer screen into its
                // whole-catalogue mode.
                WatchUi.pushView(new PointerView(null), new PointerDelegate(), WatchUi.SLIDE_LEFT);
                break;
            case "planets":
                WatchUi.pushView(SkyMenus.buildObjectMenu("Planets", SkyCatalog.filterByType(:planet)), new RootMenuDelegate(), WatchUi.SLIDE_LEFT);
                break;
            case "stars":
                WatchUi.pushView(SkyMenus.buildObjectMenu("Stars", SkyCatalog.filterByType(:star)), new RootMenuDelegate(), WatchUi.SLIDE_LEFT);
                break;
            default: {
                // Anything else is the id of one object in the catalogue.
                var obj = SkyCatalog.findById(id);
                if (obj != null) {
                    WatchUi.pushView(new PointerView(obj), new PointerDelegate(), WatchUi.SLIDE_LEFT);
                }
                break;
            }
        }
    }
}
