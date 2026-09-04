using Toybox.WatchUi as WatchUi;

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    // Selecting a setting steps it to its next value in place rather than opening a
    // list to pick from, so what the menu shows is always what is stored. Off is in
    // each grid's ring, so either can be put away without leaving the item.
    //
    // Turning location updates on or off changes what the azimuth item is able to
    // do, so that one is relabelled too rather than left claiming to follow
    // something that has stopped arriving.
    function onSelect(item) {
        var id = item.getId();
        if (id == null) {
            return;
        }
        if (id.equals("horizon")) {
            Settings.cycleHorizon();
            item.setSubLabel(Settings.gridLabel(Settings.horizonStep()));
        } else if (id.equals("equatorial")) {
            Settings.cycleEquatorial();
            item.setSubLabel(Settings.gridLabel(Settings.equatorialStep()));
        } else if (id.equals("dynEquatorial")) {
            Settings.cycleDynamicEquatorial();
            item.setSubLabel(Settings.equatorialMotionLabel());
        } else if (id.equals("dynAzimuth")) {
            Settings.cycleDynamicAzimuth();
            item.setSubLabel(Settings.azimuthMotionLabel());
        } else if (id.equals("location")) {
            Settings.cycleLocation();
            item.setSubLabel(Settings.locationLabel());
            relabelAzimuth();
        }
        WatchUi.requestUpdate();
    }

    // The azimuth item sits above the location one, so it is already on screen when
    // the interval changes underneath it.
    function relabelAzimuth() as Void {
        var menu = WatchUi.getCurrentView()[0];
        if (menu instanceof WatchUi.Menu2) {
            var index = menu.findItemById("dynAzimuth");
            if (index >= 0) {
                var azimuth = menu.getItem(index);
                if (azimuth != null) {
                    azimuth.setSubLabel(Settings.azimuthMotionLabel());
                }
            }
        }
    }
}
