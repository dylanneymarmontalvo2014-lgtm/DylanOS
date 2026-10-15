# Architecture

```
QML pages/components ──► Store (StoreController, QML singleton)
                              │  AppModel (QAbstractListModel of AppItem)
                              │  AppFilterModel (QSortFilterProxyModel: query/category/status/sort)
                              ▼
                       PackageBackend (abstract)  ◄── MockPackageBackend (timers, simulated failures)
```

- **PackageBackend** (`src/services/PackageBackend.h`): operations `install/update/updateAll/remove/cancel/retry/setOffline`, query `state(id)`, signals `stateChanged`, `operationCompleted`. The UI never talks to a package manager directly.
- **StoreController** loads `demo-apps.json`, owns the catalog, favorites and derived counts, translates backend state into `AppItem` properties, and emits `toast` signals.
- **AppFilterModel** reproduces the React filtering/sorting (case-insensitive, accent-sensitive substring; score name 3 > tags 2 > text 1).
- **IconImageProvider** serves `image://icon/<Name>/<hex>`: Lucide SVGs from the demo data recoloured at runtime.
- **Theme singletons** (`qml/theme`): Colors, Metrics, Typography, Draw (shared shape helpers), Strings (all UI texts), Nav (view/id/query routing, mirrors the React `useNav`).
- Style: Qt Quick Controls **Basic**, fully custom visuals, so no platform style leaks in.
- Security: no process execution, no sudo, no password handling anywhere in the app.
