#include "applicationmodel.h"

#include "processmodel.h"

#include <QSet>
#include <algorithm>

ApplicationModel::ApplicationModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

void ApplicationModel::setSource(ProcessModel *source)
{
    m_source = source;
    reload();
}

int ApplicationModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) {
        return 0;
    }
    return m_items.size();
}

QVariant ApplicationModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size()) {
        return {};
    }
    const Item &item = m_items.at(index.row());
    switch (role) {
    case KeyRole:
        return item.key;
    case NameRole:
        return item.name;
    case IconRole:
        return item.icon;
    case IconPathRole:
        return item.iconPath;
    case CpuRole:
        return item.cpu;
    case RssRole:
        return QVariant::fromValue<qulonglong>(item.rss);
    case PidCountRole:
        return item.processes;
    case StateRole:
        return item.state;
    case PidsRole:
        return QVariantList(item.pids.begin(), item.pids.end());
    default:
        return {};
    }
}

QHash<int, QByteArray> ApplicationModel::roleNames() const
{
    return {
        {KeyRole, "appKey"},
        {NameRole, "name"},
        {IconRole, "icon"},
        {IconPathRole, "iconPath"},
        {CpuRole, "cpu"},
        {RssRole, "rss"},
        {PidCountRole, "processCount"},
        {StateRole, "state"},
        {PidsRole, "pids"},
    };
}

void ApplicationModel::reload()
{
    if (!m_source) {
        beginResetModel();
        m_items.clear();
        endResetModel();
        emit countChanged();
        return;
    }

    // Iconos genéricos: agrupar por ellos juntaría procesos sin relación (un
    // mismo icono de "ejecutable" para 87 binarios distintos). No identifican
    // una aplicación, así que esas filas no se listan como app.
    static const QSet<QString> genericIcons = {
        QStringLiteral("application-x-executable"),
        QStringLiteral("application-x-executable-symbolic"),
    };

    // Se agrupa por nombre de icono: es lo que identifica a la app para el
    // usuario y suma el consumo de todos sus procesos.
    QHash<QString, Item> grouped;
    const int rows = m_source->rowCount();
    for (int i = 0; i < rows; ++i) {
        const QModelIndex idx = m_source->index(i, 0);
        const QString icon = idx.data(ProcessModel::IconRole).toString();
        if (icon.isEmpty() || genericIcons.contains(icon)) {
            continue;
        }
        const QString name = idx.data(ProcessModel::NameRole).toString();
        const double cpu = idx.data(ProcessModel::CpuRole).toDouble();
        const quint64 rss = idx.data(ProcessModel::RssRole).toULongLong();
        const int pid = idx.data(ProcessModel::PidRole).toInt();
        const QString state = idx.data(ProcessModel::StateRole).toString();

        auto it = grouped.find(icon);
        if (it == grouped.end()) {
            Item item;
            item.key = icon;
            item.name = name;
            item.icon = icon;
            item.iconPath = idx.data(ProcessModel::IconPathRole).toString();
            item.cpu = cpu;
            item.rss = rss;
            item.processes = 1;
            item.state = state;
            item.dominantCpu = cpu;
            item.pids = {pid};
            grouped.insert(icon, item);
        } else {
            it->cpu += cpu;
            it->rss += rss;
            it->processes += 1;
            it->pids.append(pid);
            // El nombre y el estado visibles son los del proceso dominante.
            if (cpu > it->dominantCpu) {
                it->dominantCpu = cpu;
                it->state = state;
                if (!name.isEmpty()) {
                    it->name = name;
                }
            }
        }
    }

    QVector<Item> items;
    items.reserve(grouped.size());
    for (const Item &item : grouped) {
        items.append(item);
    }
    std::sort(items.begin(), items.end(), [](const Item &a, const Item &b) {
        if (!qFuzzyCompare(a.cpu + 1.0, b.cpu + 1.0)) {
            return a.cpu > b.cpu;
        }
        return a.name.localeAwareCompare(b.name) < 0;
    });

    beginResetModel();
    m_items = items;
    endResetModel();
    emit countChanged();
}

QVariantList ApplicationModel::pidsAt(int row) const
{
    if (row < 0 || row >= m_items.size()) {
        return {};
    }
    QVariantList pids;
    for (int pid : m_items.at(row).pids) {
        pids.append(pid);
    }
    return pids;
}
