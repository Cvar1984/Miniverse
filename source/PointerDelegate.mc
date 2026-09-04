using Toybox.WatchUi as WatchUi;
using Toybox.Lang as Lang;

class PointerDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    // Holding the up/menu button. Every setting changes what is on the screen
    // underneath, so they are reachable from the screen they affect rather than
    // only from the root menu two steps back - and the effect is there waiting when
    // the menu closes.
    function onMenu() as Lang.Boolean {
        WatchUi.pushView(SkyMenus.buildSettingsMenu(), new SettingsMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
