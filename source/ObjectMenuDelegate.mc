using Toybox.WatchUi as WatchUi;

class ObjectMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var obj = SkyCatalog.findById(item.getId());
        if (obj != null) {
            WatchUi.pushView(new PointerView(obj), new PointerDelegate(), WatchUi.SLIDE_LEFT);
        }
    }
}
