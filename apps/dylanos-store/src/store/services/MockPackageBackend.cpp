#include "MockPackageBackend.h"
#include <QRandomGenerator>
#include <algorithm>

MockPackageBackend::MockPackageBackend(std::function<double()> rand, bool autoRun, QObject *parent)
    : PackageBackend(parent)
    , m_rand(rand ? rand : [] { return QRandomGenerator::global()->generateDouble(); })
{
    m_timer.setInterval(380);
    connect(&m_timer, &QTimer::timeout, this, &MockPackageBackend::tick);
    if (autoRun)
        m_timer.start();
}

void MockPackageBackend::setCatalog(const QList<CatalogEntry> &entries)
{
    m_catalog = entries;
    m_entries.clear();
    m_state.clear();
    for (const auto &e : entries) {
        m_entries.insert(e.id, e);
        PkgState s;
        s.status = e.initial;
        m_state.insert(e.id, s);
    }
}

void MockPackageBackend::set(const QString &id, const PkgState &s)
{
    m_state[id] = s;
    Q_EMIT stateChanged(id);
}

void MockPackageBackend::begin(const QString &id, bool isUpdate)
{
    if (!m_state.contains(id))
        return;
    PkgState s = m_state[id];
    s.isUpdate = isUpdate;
    s.errorKind.clear();
    if (m_offline) {
        s.status = QStringLiteral("error");
        s.errorKind = QStringLiteral("repo");
        s.progress = 0;
    } else {
        s.status = QStringLiteral("busy");
        s.progress = 1;
    }
    set(id, s);
}

void MockPackageBackend::updateAll()
{
    for (const auto &e : std::as_const(m_catalog))
        if (m_state.value(e.id).status == QLatin1String("update"))
            begin(e.id, true);
}

void MockPackageBackend::retry(const QString &id)
{
    begin(id, m_state.value(id).isUpdate);
}

void MockPackageBackend::remove(const QString &id)
{
    PkgState s = m_state.value(id);
    s.status = QStringLiteral("none");
    s.progress = 0;
    s.version.clear();
    set(id, s);
}

void MockPackageBackend::cancel(const QString &id)
{
    PkgState s = m_state.value(id);
    s.status = s.isUpdate ? QStringLiteral("update") : QStringLiteral("cancelled");
    s.progress = 0;
    set(id, s);
}

void MockPackageBackend::tick()
{
    for (const auto &e : std::as_const(m_catalog)) {
        PkgState s = m_state.value(e.id);
        if (s.status != QLatin1String("busy"))
            continue;
        const double np = std::min(100.0, s.progress + 3 + m_rand() * 5);
        if (!e.failsOnce.isEmpty() && !s.isUpdate && np > 60 && !m_failed.contains(e.id)) {
            m_failed.insert(e.id);
            s.status = QStringLiteral("error");
            s.errorKind = e.failsOnce;
            s.progress = np;
            set(e.id, s);
        } else if (np >= 100) {
            const bool wasUpdate = s.isUpdate;
            s.status = QStringLiteral("installed");
            s.progress = 100;
            s.isUpdate = false;
            s.version = !e.newVersion.isEmpty() ? e.newVersion : (!e.version.isEmpty() ? e.version : QStringLiteral("1.0"));
            set(e.id, s);
            Q_EMIT operationCompleted(e.id, wasUpdate);
        } else {
            s.progress = np;
            set(e.id, s);
        }
    }
}
