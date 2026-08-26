#include "appmodel.h"
#include <KService>
#include <QProcess>
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

    endResetModel();
}

void AppModel::refresh() { loadApps(); }

QList<KService::Ptr> AppModel::visibleApps() const
{
    if (m_filter.isEmpty()) return m_apps;
    QList<KService::Ptr> result;
    for (const auto &s : m_apps)
        if (s->name().contains(m_filter, Qt::CaseInsensitive))
            result.append(s);
    return result;
}

void AppModel::setFilter(const QString &text) { m_filter = text; }

int AppModel::pageCount(int pageSize) const
{
    if (pageSize <= 0) return 0;
    return (visibleApps().count() + pageSize - 1) / pageSize;
}

QVariantList AppModel::itemsForPage(int page, int pageSize) const
{
    QVariantList result;
    if (pageSize <= 0 || page < 0) return result;

    const auto apps = visibleApps();
    const int start = page * pageSize;
    const int end = qMin(start + pageSize, apps.count());

    for (int i = start; i < end; ++i) {
        const KService::Ptr &s = apps.at(i);
        QVariantMap item;
        item["name"] = s->name();
        item["icon"] = s->icon();
        item["desktopId"] = s->storageId();
        item["globalIndex"] = m_apps.indexOf(s);
        result.append(item);
    }
    return result;
}

void AppModel::launchApp(int index)
{
    if (index < 0 || index >= m_apps.count())
        return;

    const KService::Ptr &service = m_apps.at(index);

    QProcess::startDetached(
        QStringLiteral("sh"),
        QStringList() << QStringLiteral("-c") << service->exec()
    );
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
