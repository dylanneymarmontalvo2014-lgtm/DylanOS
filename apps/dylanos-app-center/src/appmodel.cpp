#include "appmodel.h"
#include <KService>
#include <QProcess>
#include <KIO/ApplicationLauncherJob>
#include <KIO/JobUiDelegateFactory>
#include <algorithm>

AppModel::AppModel(QObject *parent) : QAbstractListModel(parent) { loadApps(); }

void AppModel::loadApps()
{
    beginResetModel();
    m_apps.clear();

    const KService::List services = KService::allServices();
    for (const KService::Ptr &s : services) {
        if (s->noDisplay() || !s->isApplication() || s->exec().isEmpty())
            continue;
        m_apps.append(s);
    }
    std::sort(m_apps.begin(), m_apps.end(), [](const KService::Ptr &a, const KService::Ptr &b) {
        return a->name().compare(b->name(), Qt::CaseInsensitive) < 0;
    });

    m_visibleAppIndexes.clear();
    m_visibleAppsDirty = true;
    endResetModel();
}

void AppModel::refresh() { loadApps(); }

void AppModel::rebuildVisibleApps() const
{
    if (!m_visibleAppsDirty)
        return;

    m_visibleAppIndexes.clear();
    m_visibleAppIndexes.reserve(m_apps.size());
    for (int i = 0; i < m_apps.size(); ++i) {
        const auto &service = m_apps.at(i);
        if (m_filter.isEmpty() || service->name().contains(m_filter, Qt::CaseInsensitive)
            || service->comment().contains(m_filter, Qt::CaseInsensitive))
            m_visibleAppIndexes.append(i);
    }
    m_visibleAppsDirty = false;
}

void AppModel::setFilter(const QString &text)
{
    const QString filter = text.trimmed();
    if (m_filter == filter)
        return;
    m_filter = filter;
    m_visibleAppsDirty = true;
}

int AppModel::pageCount(int pageSize) const
{
    if (pageSize <= 0) return 0;
    rebuildVisibleApps();
    return (m_visibleAppIndexes.count() + pageSize - 1) / pageSize;
}

QVariantList AppModel::itemsForPage(int page, int pageSize) const
{
    QVariantList result;
    if (pageSize <= 0 || page < 0) return result;

    rebuildVisibleApps();
    const int start = page * pageSize;
    const int end = qMin(start + pageSize, m_visibleAppIndexes.count());

    for (int i = start; i < end; ++i) {
        const KService::Ptr &s = m_apps.at(m_visibleAppIndexes.at(i));
        QVariantMap item;
        item["name"] = s->name();
        item["icon"] = s->icon();
        item["desktopId"] = s->storageId();
        result.append(item);
    }
    return result;
}

void AppModel::launchApp(const QString &desktopId)
{
    if (desktopId.isEmpty())
        return;

    const auto it = std::find_if(m_apps.cbegin(), m_apps.cend(),
                                 [&desktopId](const KService::Ptr &service) {
                                     return service->storageId() == desktopId;
                                 });
    if (it == m_apps.cend())
        return;

    auto *job = new KIO::ApplicationLauncherJob(*it);
    job->setUiDelegate(KIO::createDefaultJobUiDelegate(
        KJobUiDelegate::AutoHandlingEnabled, nullptr));
    connect(job, &KJob::result, this, [this](KJob *finished) {
        if (finished->error()) emit launchFailed(finished->errorString());
        else emit launchSucceeded();
    });
    job->start();
}

int AppModel::rowCount(const QModelIndex &p) const { return p.isValid() ? 0 : m_apps.count(); }

QVariant AppModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_apps.count()) return QVariant();
    const auto &s = m_apps.at(index.row());
    switch (role) {
        case NameRole: return s->name();
        case IconRole: return s->icon();
        case ExecRole: return s->exec();
        case CommentRole: return s->comment();
        case DesktopIdRole: return s->storageId();
        default: return QVariant();
    }
}

QHash<int, QByteArray> AppModel::roleNames() const
{
    return { {NameRole,"name"}, {IconRole,"icon"}, {ExecRole,"exec"}, {CommentRole,"comment"}, {DesktopIdRole,"desktopId"} };
}
