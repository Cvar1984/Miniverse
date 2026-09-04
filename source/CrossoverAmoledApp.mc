using Toybox.Application as Application;
using Toybox.WatchUi as WatchUi;

class CrossoverAmoledApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [SkyMenus.buildRootMenu(), new RootMenuDelegate()];
    }
}
