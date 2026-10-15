#pragma once
#include <QList>
#include <QObject>
#include <QString>
#include <QVariant>

class AbstractResource;

// Initial per-package facts the backend needs to start from. A real backend ignores this
// and reads the system (PackageKit/AppStream) instead.
struct CatalogEntry {
    QString id;
    QString initial; // "none" | "installed" | "update"
    QString version;
    QString newVersion;
    QString failsOnce; // error kind the simulated backend raises once; empty = never
};

struct PkgState {
    QString status = QStringLiteral("none"); // none|installed|update|busy|error|cancelled
    double progress = 0;
    bool isUpdate = false;
    QString errorKind; // download|deps|space|repo|perm
    QString version;   // version after a completed operation
};

// Contract between the presentation layer and the package system.
// Operations are asynchronous: callers observe stateChanged / operationCompleted.
// A real implementation (PackageKit via libdiscover) must serialize operations
// and must never be driven by QML with raw commands.
class PackageBackend : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;
    virtual QString kind() const = 0; // "mock" | "packagekit"
    virtual void setCatalog(const QList<CatalogEntry> &entries) = 0;
    virtual PkgState state(const QString &id) const = 0;

    virtual void install(const QString &id) = 0;
    virtual void update(const QString &id) = 0;
    virtual void updateAll() = 0;
    virtual void remove(const QString &id) = 0;
    virtual void cancel(const QString &id) = 0;
    virtual void retry(const QString &id) = 0;
    virtual void setOffline(bool offline) = 0;

    // Hooks only used by real backends; the mock keeps the defaults.
    virtual void registerResource(const QString &id, AbstractResource *resource)
    {
        Q_UNUSED(id)
        Q_UNUSED(resource)
    }
    virtual QVariant resourceIcon(const QString &id) const
    {
        Q_UNUSED(id)
        return {};
    }
    virtual bool launch(const QString &id)
    {
        Q_UNUSED(id)
        return false;
    }

Q_SIGNALS:
    void stateChanged(const QString &id);
    void operationCompleted(const QString &id, bool wasUpdate);
};
