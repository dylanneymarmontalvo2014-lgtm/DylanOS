#include "servicemodel.h"

#include "coreapi.h"

#include <array>
#include <QSet>

ServiceModel::ServiceModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int ServiceModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) {
        return 0;
    }
    return m_items.size();
}

QVariant ServiceModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size()) {
        return {};
    }
    const Item &item = m_items.at(index.row());
    switch (role) {
    case NameRole:
        return item.name;
    case DescriptionRole:
        return item.description;
    case ActiveRole:
        return item.active;
    case ScopeRole:
        return item.scope;
    case StateLabelRole:
        return item.active ? QStringLiteral("Activo") : QStringLiteral("Detenido");
    default:
        return {};
    }
}

QHash<int, QByteArray> ServiceModel::roleNames() const
{
    return {
        {NameRole, "name"},
        {DescriptionRole, "description"},
        {ActiveRole, "active"},
        {ScopeRole, "scope"},
        {StateLabelRole, "stateLabel"},
    };
}

void ServiceModel::reload()
{
    DpServiceList *list = dp_service_list();
    QVector<Item> items;
    if (list) {
        items.reserve(static_cast<int>(list->count));
        for (size_t i = 0; i < list->count; ++i) {
            const DpService &service = list->items[i];
            Item item;
            item.name = QString::fromUtf8(service.name ? service.name : "");
            item.description = QString::fromUtf8(service.description ? service.description : "");
            item.active = service.active == 1;
            item.scope = QString::fromUtf8(service.scope ? service.scope : "");
            items.append(item);
        }
        dp_service_list_free(list);
    }

    beginResetModel();
    m_items = items;
    m_available = !m_items.isEmpty();
    m_errorText = m_available
        ? QString()
        : QStringLiteral("systemd no reportó unidades de servicio en este sistema.");
    endResetModel();
    emit countChanged();
}

bool ServiceModel::setActive(int row, bool active)
{
    if (row < 0 || row >= m_items.size()) {
        emit notice(QStringLiteral("Unidad no válida."), false);
        return false;
    }
    const QString name = m_items.at(row).name;
    const bool userScope = m_items.at(row).scope == QStringLiteral("Usuario");
    std::array<char, 512> buffer{};
    const int rc = dp_service_set_active(name.toUtf8().constData(), active ? 1 : 0,
                                        userScope ? 1 : 0, buffer.data(), buffer.size());
    const QString message = QString::fromUtf8(buffer.data());
    if (rc == 0) {
        // El estado real se relee de systemd: no se asume el cambio.
        m_items[row].active = active;
        const QModelIndex idx = index(row, 0);
        emit dataChanged(idx, idx, {ActiveRole, StateLabelRole});
        emit notice(message, true);
        return true;
    }
    emit notice(message.isEmpty() ? QStringLiteral("systemd rechazó la operación.") : message,
                false);
    return false;
}

void ServiceModel::setTestUnits(const QVariantList &units)
{
    QVector<Item> items;
    items.reserve(units.size());
    for (const QVariant &entry : units) {
        const QVariantMap map = entry.toMap();
        Item item;
        item.name = map.value(QStringLiteral("name")).toString();
        item.description = map.value(QStringLiteral("description")).toString();
        item.active = map.value(QStringLiteral("active")).toBool();
        item.scope = map.value(QStringLiteral("scope"), QStringLiteral("Sistema")).toString();
        if (!item.name.isEmpty()) {
            items.append(item);
        }
    }
    beginResetModel();
    m_items = items;
    m_available = !m_items.isEmpty();
    m_errorText = m_available ? QString()
                              : QStringLiteral("systemd no reportó unidades de servicio en este sistema.");
    endResetModel();
    emit countChanged();
}

void ServiceModel::clearTestUnits()
{
    reload();
}
