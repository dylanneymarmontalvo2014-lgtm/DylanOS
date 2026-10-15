#include "AppModel.h"

void AppModel::setItems(const QList<AppItem *> &items)
{
    beginResetModel();
    m_items = items;
    endResetModel();
    for (int i = 0; i < m_items.size(); ++i)
        connect(m_items[i], &AppItem::stateChanged, this, [this, i] {
            Q_EMIT dataChanged(index(i), index(i), {AppRole});
        });
}

void AppModel::appendItems(const QList<AppItem *> &items)
{
    if (items.isEmpty())
        return;
    const int first = m_items.size();
    beginInsertRows({}, first, first + items.size() - 1);
    m_items += items;
    endInsertRows();
    for (int i = first; i < m_items.size(); ++i)
        connect(m_items[i], &AppItem::stateChanged, this, [this, i] {
            Q_EMIT dataChanged(index(i), index(i), {AppRole});
        });
}

QVariant AppModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_items.size())
        return {};
    if (role == AppRole)
        return QVariant::fromValue(m_items.at(index.row()));
    return {};
}

QHash<int, QByteArray> AppModel::roleNames() const
{
    return {{AppRole, "app"}, {ReasonRole, "reason"}};
}
