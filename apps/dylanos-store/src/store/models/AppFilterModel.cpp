#include "AppFilterModel.h"

AppFilterModel::AppFilterModel(QObject *parent) : QSortFilterProxyModel(parent)
{
    setDynamicSortFilter(true);
    sort(0);
    auto emitCount = [this] { Q_EMIT countChanged(); };
    connect(this, &QAbstractItemModel::rowsInserted, this, emitCount);
    connect(this, &QAbstractItemModel::rowsRemoved, this, emitCount);
    connect(this, &QAbstractItemModel::modelReset, this, emitCount);
    connect(this, &QAbstractItemModel::layoutChanged, this, emitCount);
}

void AppFilterModel::refresh()
{
    invalidate();
    sort(0);
    Q_EMIT changed();
    Q_EMIT countChanged();
}

#define SETTER(Type, name, member, Name) \
    void AppFilterModel::set##Name(Type v) { if (member == v) return; member = v; refresh(); }
SETTER(const QString &, q, m_query, Query)
SETTER(bool, b, m_nameOnly, NameOnly)
SETTER(const QString &, c, m_category, Category)
SETTER(const QString &, s, m_status, StatusFilter)
SETTER(const QString &, s, m_sort, SortKey)
SETTER(const QStringList &, i, m_ids, Ids)
SETTER(bool, b, m_restrict, RestrictToIds)
#undef SETTER

AppItem *AppFilterModel::itemAt(const QModelIndex &src) const
{
    return sourceModel()->data(src, AppModel::AppRole).value<AppItem *>();
}

// 3 = name, 2 = tag, 1 = description or category, 0 = no match (mirrors the React prototype)
int AppFilterModel::score(const AppItem *a, const QString &needle)
{
    const QString n = needle.trimmed().toLower();
    if (a->m_name.toLower().contains(n))
        return 3;
    for (const auto &t : a->m_tags)
        if (t.contains(n))
            return 2;
    if (a->m_short.toLower().contains(n) || a->m_long.toLower().contains(n) || a->m_categoryLabel.toLower().contains(n))
        return 1;
    return 0;
}

bool AppFilterModel::filterAcceptsRow(int row, const QModelIndex &parent) const
{
    const AppItem *a = itemAt(sourceModel()->index(row, 0, parent));
    if (!a)
        return false;
    if (m_restrict && !m_ids.contains(a->m_id))
        return false;
    if (m_category != QLatin1String("all") && a->m_category != m_category)
        return false;
    const QString st = a->status();
    if (m_status == QLatin1String("installed") && st != QLatin1String("installed"))
        return false;
    if (m_status == QLatin1String("available") && st != QLatin1String("none"))
        return false;
    if (m_status == QLatin1String("managed") && st != QLatin1String("installed") && st != QLatin1String("update"))
        return false;
    if (!m_query.trimmed().isEmpty()) {
        if (m_nameOnly)
            return a->m_name.contains(m_query.trimmed(), Qt::CaseInsensitive);
        return score(a, m_query) > 0;
    }
    return true;
}

bool AppFilterModel::lessThan(const QModelIndex &l, const QModelIndex &r) const
{
    const AppItem *a = itemAt(l), *b = itemAt(r);
    if (!a || !b)
        return false;
    if (m_restrict && m_sort == QLatin1String("ids"))
        return m_ids.indexOf(a->m_id) < m_ids.indexOf(b->m_id);
    if (m_sort == QLatin1String("date") && a->m_date != b->m_date)
        return a->m_date > b->m_date;
    if (m_sort == QLatin1String("category")) {
        const int c = QString::localeAwareCompare(a->m_categoryLabel, b->m_categoryLabel);
        if (c)
            return c < 0;
    }
    if (m_sort == QLatin1String("relevance") && !m_query.trimmed().isEmpty()) {
        const int sa = score(a, m_query), sb = score(b, m_query);
        if (sa != sb)
            return sa > sb;
    }
    return QString::localeAwareCompare(a->m_name, b->m_name) < 0;
}

QVariant AppFilterModel::data(const QModelIndex &index, int role) const
{
    if (role == AppModel::ReasonRole) {
        const AppItem *a = itemAt(mapToSource(index));
        if (!a || m_query.trimmed().isEmpty())
            return {};
        switch (score(a, m_query)) {
        case 3: return QStringLiteral("Coincide con el nombre");
        case 2: return QStringLiteral("Etiqueta relacionada");
        default: return QStringLiteral("Coincide con la descripción");
        }
    }
    return QSortFilterProxyModel::data(index, role);
}
