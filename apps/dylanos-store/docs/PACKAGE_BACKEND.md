# PackageBackend contract

```cpp
class PackageBackend : public QObject {
  virtual QString kind() const = 0;
  virtual void setCatalog(const QList<CatalogEntry>&) = 0;   // id, initial state, versions, failsOnce
  virtual PackageState state(const QString& id) const = 0;   // status none|installed|update|busy|error|cancelled
  virtual void install(id); update(id); updateAll(); remove(id); cancel(id); retry(id); setOffline(bool);
signals: void stateChanged(const QString& id); void operationCompleted(const QString& id, bool wasUpdate);
};
```
Rules: operations are asynchronous and report only through signals; `busy` carries `progress` 0–100; failures set `error` with `errorKind` (`repo`, `deps`, …); `cancel` on an update returns to `update`, on an install to `cancelled`.

## MockPackageBackend
Timer-driven (`tick()` public, `autoRun=false` and an injected `rand` give deterministic tests). Entries with `failsOnce` fail once past 60%. Offline fails immediately with `repo`. Never touches the system.

## Adding a real backend (PackageKit / AppStream)
1. Implement `PackageBackend` in `src/services/PackageKitBackend.*` using the public PackageKit D-Bus API (`org.freedesktop.PackageKit`), mapping transaction progress to `busy` and Finished/ErrorCode to `installed`/`error`. Authorization is delegated to polkit by PackageKit; the app never asks for or stores passwords and never calls sudo.
2. Add it to `CORE_SOURCES` and swap the instance in `main.cpp` (`new StoreController(new PackageKitBackend())`).
3. Feed the catalog from AppStream instead of `demo-apps.json` (`StoreController::loadCatalog` is the only entry).
4. Do not depend on private libdiscover API.
