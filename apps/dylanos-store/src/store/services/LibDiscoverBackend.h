#pragma once
#include "PackageBackend.h"
#include <QHash>
#include <QPointer>
#include <QSet>

class AbstractResource;
class Transaction;

// Real backend on top of libdiscover (PackageKit/Flatpak backends). It never runs
// shell commands: every operation goes through the resource's backend, PackageKit
// asks for authorization through polkit and progress arrives via Transaction.
class LibDiscoverBackend : public PackageBackend
{
    Q_OBJECT
public:
    explicit LibDiscoverBackend(QObject *parent = nullptr);

    QString kind() const override { return QStringLiteral("packagekit"); }
    void setCatalog(const QList<CatalogEntry> &entries) override { Q_UNUSED(entries) }
    PkgState state(const QString &id) const override;

    void install(const QString &id) override;
    void update(const QString &id) override;
    void updateAll() override;
    void remove(const QString &id) override;
    void cancel(const QString &id) override;
    void retry(const QString &id) override;
    void setOffline(bool offline) override { m_offline = offline; }

    void registerResource(const QString &id, AbstractResource *resource) override;
    QVariant resourceIcon(const QString &id) const override;
    bool launch(const QString &id) override;

private:
    void start(const QString &id, Transaction *txn, bool isUpdate);
    void fail(const QString &id, const QString &errorKind);

    QHash<QString, AbstractResource *> m_resources;
    QHash<QString, QPointer<Transaction>> m_transactions;
    QHash<QString, double> m_progress;
    QHash<QString, bool> m_txnIsUpdate;
    QHash<QString, int> m_txnStatus;
    QHash<QString, QString> m_txnPhase;
    QHash<QString, QString> m_lastError;
    QSet<QString> m_cancelled;
    bool m_offline = false;
};
