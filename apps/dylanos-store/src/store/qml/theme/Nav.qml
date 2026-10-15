pragma Singleton
import QtQuick

// Navigation state. Views: home cats cat search app library updates installed settings
QtObject {
    id: nav
    property string view: "home"
    property string viewId: ""
    property string query: ""
    property int windowWidth: 1280
    signal navigated()

    function go(v, id) {
        query = ""
        viewId = id || ""
        view = v
        navigated()
    }
    function setQuery(q) {
        query = q
        if (q.trim() !== "") { if (view !== "search") { view = "search"; viewId = ""; navigated() } }
        else if (view === "search") go("home")
    }
    readonly property string topSection: ["home", "cats", "cat", "search", "app"].indexOf(view) >= 0 ? "home" : view
}
