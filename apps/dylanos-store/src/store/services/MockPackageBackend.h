#pragma once
#include "PackageBackend.h"
#include <QHash>
#include <QSet>
#include <QTimer>
#include <functional>

// SIMULATED backend. It never touches the system: it only advances in-memory state.
class MockPackageBackend : public PackageBackend
{
    Q_OBJECT
public:
    explicit MockPackageBackend(std::function<double()> rand = nullptr, bool autoRun = true, QObject *parent = nullptr);

    QString kind() const override { return QStringLiteral("mock"); }
    void setCatalog(const QList<CatalogEntry> &entries) override;
    PkgState state(const QString &id) const override { return m_state.value(id); }

    void install(const QString &id) override { begin(id, false); }
    void update(const QString &id) override { begin(id, true); }
    void updateAll() override;
    void remove(const QString &id) override;
    void cancel(const QString &id) override;
    void retry(const QString &id) override;
    void setOffline(bool offline) override { m_offline = offline; }

    void tick(); // one simulation step (public so tests can drive it)

private:
    void begin(const QString &id, bool isUpdate);
    void set(const QString &id, const PkgState &s);

    QList<CatalogEntry> m_catalog;
    QHash<QString, CatalogEntry> m_entries;
    QHash<QString, PkgState> m_state;
    QSet<QString> m_failed;
    std::function<double()> m_rand;
    QTimer m_timer;
    bool m_offline = false;
};
