#include "LibDiscoverBackend.h"
#include <Transaction/Transaction.h>
#include <resources/AbstractResource.h>
#include <resources/AbstractResourcesBackend.h>

LibDiscoverBackend::LibDiscoverBackend(QObject *parent)
    : PackageBackend(parent)
{
}

void LibDiscoverBackend::registerResource(const QString &id, AbstractResource *resource)
{
    if (!resource)
        return;
    m_resources.insert(id, resource);
    connect(resource, &AbstractResource::stateChanged, this, [this, id] {
        Q_EMIT stateChanged(id);
    });
}

QVariant LibDiscoverBackend::resourceIcon(const QString &id) const
{
    auto *res = m_resources.value(id);
    return res ? res->icon() : QVariant();
}

bool LibDiscoverBackend::launch(const QString &id)
{
    auto *res = m_resources.value(id);
    if (!res || !res->canExecute())
        return false;
    res->invokeApplication();
    return true;
}

PkgState LibDiscoverBackend::state(const QString &id) const
{
    PkgState s;
    auto *res = m_resources.value(id);
    if (!res)
        return s;
    if (Transaction *txn = m_transactions.value(id)) {
        Q_UNUSED(txn)
        s.status = QStringLiteral("busy");
        s.progress = m_progress.value(id);
        s.isUpdate = m_txnIsUpdate.value(id);
        return s;
    }
    if (m_lastError.contains(id)) {
        s.status = QStringLiteral("error");
        s.errorKind = m_lastError.value(id);
        return s;
    }
    if (m_cancelled.contains(id) && res->state() != AbstractResource::Upgradeable) {
        s.status = QStringLiteral("cancelled");
        return s;
    }
    switch (res->state()) {
    case AbstractResource::Installed:
        s.status = QStringLiteral("installed");
        s.version = res->installedVersion();
        break;
    case AbstractResource::Upgradeable:
        s.status = QStringLiteral("update");
        break;
    default:
        s.status = QStringLiteral("none");
        break;
    }
    return s;
}

void LibDiscoverBackend::install(const QString &id)
{
    auto *res = m_resources.value(id);
    if (!res || m_transactions.contains(id))
        return;
    if (m_offline) {
        fail(id, QStringLiteral("repo"));
        return;
    }
    m_cancelled.remove(id);
    m_lastError.remove(id);
    const bool isUpdate = res->state() == AbstractResource::Upgradeable;
    start(id, res->backend()->installApplication(res), isUpdate);
}

void LibDiscoverBackend::update(const QString &id)
{
    install(id);
}

void LibDiscoverBackend::updateAll()
{
    const auto ids = m_resources.keys();
    for (const QString &id : ids) {
        auto *res = m_resources.value(id);
        if (res && res->state() == AbstractResource::Upgradeable && !m_transactions.contains(id))
            install(id);
    }
}

void LibDiscoverBackend::remove(const QString &id)
{
    auto *res = m_resources.value(id);
    if (!res || m_transactions.contains(id))
        return;
    m_cancelled.remove(id);
    m_lastError.remove(id);
    start(id, res->backend()->removeApplication(res), false);
}

void LibDiscoverBackend::cancel(const QString &id)
{
    if (Transaction *txn = m_transactions.value(id)) {
        if (txn->isCancellable())
            txn->cancel();
        else
            Q_EMIT stateChanged(id);
    }
}

void LibDiscoverBackend::retry(const QString &id)
{
    m_lastError.remove(id);
    m_cancelled.remove(id);
    install(id);
}

void LibDiscoverBackend::start(const QString &id, Transaction *txn, bool isUpdate)
{
    if (!txn) {
        fail(id, QStringLiteral("deps"));
        return;
    }
    m_transactions.insert(id, txn);
    m_progress.insert(id, 0);
    m_txnIsUpdate.insert(id, isUpdate);
    m_txnPhase.insert(id, QStringLiteral("download"));
    m_txnStatus.insert(id, Transaction::SetupStatus);
    connect(txn, &Transaction::progressChanged, this, [this, id](int progress) {
        m_progress.insert(id, progress);
        Q_EMIT stateChanged(id);
    });
    connect(txn, &Transaction::statusChanged, this, [this, id](Transaction::Status status) {
        m_txnStatus.insert(id, int(status));
        if (status == Transaction::CommittingStatus)
            m_txnPhase.insert(id, QStringLiteral("deps"));
        Q_EMIT stateChanged(id);
    });
    connect(txn, &QObject::destroyed, this, [this, id, isUpdate] {
        m_transactions.remove(id);
        m_progress.remove(id);
        m_txnIsUpdate.remove(id);
        const int lastStatus = m_txnStatus.value(id, Transaction::DoneStatus);
        const QString phase = m_txnPhase.take(id);
        m_txnStatus.remove(id);
        if (lastStatus == Transaction::DoneStatus) {
            m_lastError.remove(id);
            m_cancelled.remove(id);
            Q_EMIT operationCompleted(id, isUpdate);
        } else if (lastStatus == Transaction::DoneWithErrorStatus) {
            m_lastError.insert(id, phase);
        } else if (lastStatus == Transaction::CancelledStatus) {
            m_cancelled.insert(id);
        }
        Q_EMIT stateChanged(id);
    });
}

void LibDiscoverBackend::fail(const QString &id, const QString &errorKind)
{
    m_lastError.insert(id, errorKind);
    Q_EMIT stateChanged(id);
}
