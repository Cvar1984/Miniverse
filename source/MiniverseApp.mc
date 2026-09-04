using Toybox.Application as Application;
using Toybox.WatchUi as WatchUi;

class MiniverseApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [SkyMenus.buildRootMenu(), new RootMenuDelegate()];
    }
}
