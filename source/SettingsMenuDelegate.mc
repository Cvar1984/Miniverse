using Toybox.WatchUi as WatchUi;

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    // Selecting a setting steps it to its next value in place rather than opening a
    // list to pick from, so what the menu shows is always what is stored. Off is in
    // each grid's ring, so either can be put away without leaving the item.
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
        }
        WatchUi.requestUpdate();
    }
}
