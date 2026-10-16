pragma Singleton
import QtQuick

// 24x24 stroke icons (SVG path data), drawn by components/Icon.qml.
QtObject {
    readonly property var map: ({
        "home": "M3 11.5 12 4l9 7.5 M5.5 10v9.5h5v-6h3v6h5V10",
        "desktop": "M3 5h18v11H3z M8 20h8 M12 16v4",
        "doc": "M6 3h8l4 4v14H6z M14 3v4h4 M9 12h6 M9 16h6",
        "download": "M12 4v11 M7.5 10.5 12 15l4.5-4.5 M5 19.5h14",
        "image": "M4 5h16v14H4z M4 16l5-5 4 4 3-3 4 4 M8.5 9h.01",
        "music": "M9 18V5l11-2v13 M9 18a3 3 0 1 1-6 0 3 3 0 0 1 6 0z M20 16a3 3 0 1 1-6 0 3 3 0 0 1 6 0z",
        "film": "M4 5h16v14H4z M10 9.5v5l4.5-2.5z",
        "trash": "M5 7h14 M9 7V4h6v3 M7 7l1 13h8l1-13 M10 11v6 M14 11v6",
        "drive": "M4 14h16v6H4z M4 14l2.5-9h11L20 14 M16 17h1",
        "gear": "M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z M12 3v3 M12 18v3 M3 12h3 M18 12h3 M5.6 5.6l2.1 2.1 M16.3 16.3l2.1 2.1 M5.6 18.4l2.1-2.1 M16.3 7.7l2.1-2.1",
        "server": "M4 5h16v5H4z M4 14h16v5H4z M7.5 7.5h.01 M7.5 16.5h.01",
        "search": "M10.5 17a6.5 6.5 0 1 0 0-13 6.5 6.5 0 0 0 0 13z M15.5 15.5 20 20",
        "back": "M14.5 5 7.5 12l7 7",
        "forward": "M9.5 5l7 7-7 7",
        "up": "M5 14.5l7-7 7 7",
        "chevronDown": "M5 9.5l7 7 7-7",
        "grid": "M4 4h6.5v6.5H4z M13.5 4H20v6.5h-6.5z M4 13.5h6.5V20H4z M13.5 13.5H20V20h-6.5z",
        "list": "M9 6h11 M9 12h11 M9 18h11 M4 6h.01 M4 12h.01 M4 18h.01",
        "columns": "M3.5 5h17v14h-17z M12 5v14",
        "preview": "M3.5 5h17v14h-17z M9 9h6v6H9z",
        "more": "M6 12h.01 M12 12h.01 M18 12h.01",
        "folder": "M3 7a2 2 0 0 1 2-2h4l2 2.5h8a2 2 0 0 1 2 2V18a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z",
        "folderPlus": "M3 7a2 2 0 0 1 2-2h4l2 2.5h8a2 2 0 0 1 2 2V18a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z M12 11v6 M9 14h6",
        "check": "M5 12.5l4.5 4.5L19 7.5",
        "close": "M6 6l12 12 M18 6 6 18",
        "warning": "M12 4 21 20H3z M12 10v4.5 M12 17.5h.01",
        "info": "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z M12 11v5.5 M12 7.7h.01",
        "plus": "M12 5v14 M5 12h14",
        "lock": "M6 11h12v9H6z M8.5 11V8a3.5 3.5 0 0 1 7 0v3",
        "copy": "M9 9h11v11H9z M5 15V4h11",
        "cut": "M7 9a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z M7 20a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z M9 8l11 11 M9 16 20 5",
        "paste": "M8 5H6a1 1 0 0 0-1 1v14h14V6a1 1 0 0 0-1-1h-2 M9 3h6v4H9z",
        "rename": "M4 20h4L19 9l-4-4L4 16z M13 7l4 4",
        "open": "M14 4h6v6 M20 4 10 14 M18 14v6H4V6h6",
        "restore": "M4 12a8 8 0 1 0 2.5-5.8 M4 4v5h5",
        "sort": "M7 5v14 M4 16l3 3 3-3 M17 19V5 M14 8l3-3 3 3",
        "code": "M8.5 7 3.5 12l5 5 M15.5 7l5 5-5 5 M13.5 5l-3 14",
        "refresh": "M20 12a8 8 0 1 1-2.5-5.8 M20 4v5h-5",
        "eye": "M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z M12 14.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z"
    })
    function path(name) { return map[name] || "" }
}
