#include "processmodel.h"

#include "coreapi.h"

#include <QCollator>
#include <QFileInfo>
#include <QStringList>

#include <algorithm>

namespace {
// Valor de estado que representa "sin filtro" en las chips del prototipo.
const QString kAllStates = QStringLiteral("all");
}

ProcessModel::ProcessModel(QObject *parent)
    : QAbstractListModel(parent)
    , m_sampler(dp_sampler_new())
{
    m_iconCount = m_sampler ? static_cast<int>(dp_icon_count(m_sampler)) : 0;
}

ProcessModel::~ProcessModel()
{
    if (m_sampler) {
        dp_sampler_free(m_sampler);
    }
}

int ProcessModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) {
        return 0;
    }
    return m_rows.size();
}

int ProcessModel::count() const
{
    return m_rows.size();
}

QVariant ProcessModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_rows.size()) {
        return {};
    }
    const Row &row = m_rows.at(index.row());
    switch (role) {
    case PidRole:
        return row.pid;
    case NameRole:
        return row.name;
    case CommandRole:
        return row.command;
    case UserRole:
        return row.user;
    case UidRole:
        return row.uid;
    case CpuRole:
        return row.cpu;
    case RssRole:
        return QVariant::fromValue<qulonglong>(row.rss);
    case IconRole:
        return row.icon;
    case IconPathRole:
        return row.iconPath;
    case StateRole:
        return row.state;
    case ThreadsRole:
        return row.threads;
    case PriorityRole:
        return row.priority;
    case NiceRole:
        return row.nice;
    case UptimeRole:
        return QVariant::fromValue<qulonglong>(row.uptime);
    case IoReadRole:
        return QVariant::fromValue<qulonglong>(row.ioRead);
    case IoWriteRole:
        return QVariant::fromValue<qulonglong>(row.ioWrite);
    case SwapRole:
        return QVariant::fromValue<qulonglong>(row.swap);
    default:
        return {};
    }
}

QHash<int, QByteArray> ProcessModel::roleNames() const
{
    return {
        {PidRole, "pid"},
        {NameRole, "name"},
        {CommandRole, "command"},
        {UserRole, "user"},
        {UidRole, "uid"},
        {CpuRole, "cpu"},
        {RssRole, "rss"},
        {IconRole, "icon"},
        {IconPathRole, "iconPath"},
        {StateRole, "state"},
        {ThreadsRole, "threads"},
        {PriorityRole, "priority"},
        {NiceRole, "nice"},
        {UptimeRole, "uptime"},
        {IoReadRole, "ioRead"},
        {IoWriteRole, "ioWrite"},
        {SwapRole, "swap"},
    };
}

QString ProcessModel::resolveIconPath(const QString &icon)
{
    if (icon.isEmpty() || !m_sampler) {
        return {};
    }
    const auto cached = m_iconCache.constFind(icon);
    if (cached != m_iconCache.constEnd()) {
        return *cached;
    }
    const char *path = dp_icon_path(m_sampler, icon.toUtf8().constData());
    const QString resolved = path ? QString::fromUtf8(path) : QString();
    m_iconCache.insert(icon, resolved);
    return resolved;
}

bool ProcessModel::refresh()
{
    if (!m_sampler) {
        return false;
    }
    const DpSnapshot *snapshot = dp_sample(m_sampler);
    if (!snapshot) {
        return false;
    }
    applySnapshot(snapshot);
    return true;
}

void ProcessModel::applySnapshot(const void *raw)
{
    const auto *snapshot = static_cast<const DpSnapshot *>(raw);
    if (!snapshot) {
        return;
    }

    QVector<Row> incoming;
    incoming.reserve(static_cast<int>(snapshot->count));
    for (size_t i = 0; i < snapshot->count; ++i) {
        const DpProcess &process = snapshot->processes[i];
        Row row;
        row.pid = process.pid;
        row.ppid = process.ppid;
        row.name = QString::fromUtf8(process.name ? process.name : "");
        row.command = QString::fromUtf8(process.command ? process.command : "");
        row.user = QString::fromUtf8(process.user ? process.user : "");
        row.uid = process.uid;
        row.cpu = process.cpu;
        row.rss = process.rss;
        row.icon = QString::fromUtf8(process.icon ? process.icon : "");
        row.iconPath = resolveIconPath(row.icon);
        row.state = QString::fromUtf8(process.state ? process.state : "");
        row.threads = static_cast<int>(process.threads);
        row.priority = process.priority;
        row.nice = process.nice;
        row.uptime = process.uptime_secs;
        row.ioRead = process.io_read;
        row.ioWrite = process.io_write;
        row.swap = process.swap_kb;
        incoming.append(row);
    }
    // El núcleo entrega las filas ordenadas por CPU; el modelo mantiene un
    // orden estable por PID para que el diff sea barato y la selección no
    // salte entre refrescos. El orden visible lo decide el proxy.
    std::sort(incoming.begin(), incoming.end(),
              [](const Row &a, const Row &b) { return a.pid < b.pid; });

    // Merge de dos listas ordenadas por PID: actualiza en sitio, inserta y
    // elimina solo lo que cambió de verdad.
    int current = 0;
    int next = 0;
    while (current < m_rows.size() || next < incoming.size()) {
        if (current >= m_rows.size()) {
            beginInsertRows(QModelIndex(), current, incoming.size() - 1);
            while (next < incoming.size()) {
                m_rows.insert(current, incoming.at(next));
                ++current;
                ++next;
            }
            endInsertRows();
        } else if (next >= incoming.size()) {
            beginRemoveRows(QModelIndex(), current, m_rows.size() - 1);
            m_rows.remove(current, m_rows.size() - current);
            endRemoveRows();
        } else if (m_rows.at(current).pid == incoming.at(next).pid) {
            m_rows[current] = incoming.at(next);
            ++current;
            ++next;
        } else if (m_rows.at(current).pid < incoming.at(next).pid) {
            beginRemoveRows(QModelIndex(), current, current);
            m_rows.remove(current);
            endRemoveRows();
        } else {
            beginInsertRows(QModelIndex(), current, current);
            m_rows.insert(current, incoming.at(next));
            ++current;
            ++next;
            endInsertRows();
        }
    }

    if (!m_rows.isEmpty()) {
        emit dataChanged(index(0, 0), index(m_rows.size() - 1, 0));
    }

    const bool totalsDiffer = !qFuzzyCompare(m_cpuPercent + 1.0, snapshot->cpu_percent + 1.0)
        || m_memUsed != snapshot->mem_used || m_memTotal != snapshot->mem_total
        || m_swapUsed != snapshot->swap_used || m_cores != static_cast<int>(snapshot->cores)
        || m_threads != static_cast<int>(snapshot->threads);

    m_cpuPercent = snapshot->cpu_percent;
    m_memUsed = snapshot->mem_used;
    m_memTotal = snapshot->mem_total;
    m_swapUsed = snapshot->swap_used;
    m_swapTotal = snapshot->swap_total;
    m_netRx = snapshot->net_rx;
    m_netTx = snapshot->net_tx;
    m_diskRead = snapshot->disk_read;
    m_diskWrite = snapshot->disk_write;
    m_load1 = snapshot->load1;
    m_load5 = snapshot->load5;
    m_load15 = snapshot->load15;
    m_cores = static_cast<int>(snapshot->cores);
    m_threads = static_cast<int>(snapshot->threads);

    emit countChanged();
    if (totalsDiffer) {
        emit totalsChanged();
    }
}

int ProcessModel::rowForPid(int pid) const
{
    // Las filas están ordenadas por PID: búsqueda binaria.
    int low = 0;
    int high = m_rows.size() - 1;
    while (low <= high) {
        const int mid = low + (high - low) / 2;
        if (m_rows.at(mid).pid == pid) {
            return mid;
        }
        if (m_rows.at(mid).pid < pid) {
            low = mid + 1;
        } else {
            high = mid - 1;
        }
    }
    return -1;
}

QString ProcessModel::stateLabelFor(int row) const
{
    if (row < 0 || row >= m_rows.size()) {
        return {};
    }
    return m_rows.at(row).state;
}

ProcessFilterModel::ProcessFilterModel(QObject *parent)
    : QSortFilterProxyModel(parent)
{
    setDynamicSortFilter(true);
    sort(0, Qt::DescendingOrder);
}

void ProcessFilterModel::setSearchText(const QString &text)
{
    if (m_searchText == text) {
        return;
    }
    m_searchText = text;
    invalidateFilter();
    emit searchTextChanged();
    emit countChanged();
}

void ProcessFilterModel::setStateFilter(const QString &state)
{
    if (m_stateFilter == state) {
        return;
    }
    m_stateFilter = state;
    invalidateFilter();
    emit stateFilterChanged();
    emit countChanged();
}

void ProcessFilterModel::setSortRole(const QString &role)
{
    if (m_sortRole == role) {
        return;
    }
    m_sortRole = role;
    invalidate();
    sort(0, m_sortDescending ? Qt::DescendingOrder : Qt::AscendingOrder);
    emit sortRoleChanged();
}

void ProcessFilterModel::setSortDescending(bool descending)
{
    if (m_sortDescending == descending) {
        return;
    }
    m_sortDescending = descending;
    invalidate();
    sort(0, m_sortDescending ? Qt::DescendingOrder : Qt::AscendingOrder);
    emit sortDescendingChanged();
}

int ProcessFilterModel::count() const
{
    return rowCount();
}

int ProcessFilterModel::roleFor(const QString &name) const
{
    static const QHash<QString, int> roles = {
        {QStringLiteral("pid"), ProcessModel::PidRole},
        {QStringLiteral("name"), ProcessModel::NameRole},
        {QStringLiteral("user"), ProcessModel::UserRole},
        {QStringLiteral("cpu"), ProcessModel::CpuRole},
        {QStringLiteral("mem"), ProcessModel::RssRole},
        {QStringLiteral("status"), ProcessModel::StateRole},
    };
    return roles.value(name, ProcessModel::CpuRole);
}

bool ProcessFilterModel::filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const
{
    const QModelIndex index = sourceModel()->index(sourceRow, 0, sourceParent);
    if (!index.isValid()) {
        return false;
    }
    if (m_stateFilter != kAllStates) {
        const QString state = index.data(ProcessModel::StateRole).toString();
        if (state != m_stateFilter) {
            return false;
        }
    }
    if (!m_searchText.isEmpty()) {
        const QString name = index.data(ProcessModel::NameRole).toString();
        const QString user = index.data(ProcessModel::UserRole).toString();
        const QString command = index.data(ProcessModel::CommandRole).toString();
        // Además del nombre se busca en usuario y línea de comandos: es lo que
        // el usuario recuerda cuando no sabe cómo se llama el binario.
        if (!name.contains(m_searchText, Qt::CaseInsensitive)
            && !user.contains(m_searchText, Qt::CaseInsensitive)
            && !command.contains(m_searchText, Qt::CaseInsensitive)) {
            return false;
        }
    }
    return true;
}

bool ProcessFilterModel::lessThan(const QModelIndex &left, const QModelIndex &right) const
{
    // Comparación siempre ascendente: QSortFilterProxyModel invierte el
    // resultado cuando el orden es descendente.
    const int role = roleFor(m_sortRole);
    const QVariant l = left.data(role);
    const QVariant r = right.data(role);

    if (role == ProcessModel::NameRole || role == ProcessModel::UserRole
        || role == ProcessModel::StateRole) {
        static const QCollator collator = [] {
            QCollator c;
            c.setNumericMode(true);
            c.setCaseSensitivity(Qt::CaseInsensitive);
            return c;
        }();
        return collator.compare(l.toString(), r.toString()) < 0;
    }
    if (role == ProcessModel::CpuRole) {
        return l.toDouble() < r.toDouble();
    }
    return l.toLongLong() < r.toLongLong();
}

void ProcessFilterModel::toggleSort(const QString &role)
{
    if (m_sortRole == role) {
        setSortDescending(!m_sortDescending);
        return;
    }
    m_sortRole = role;
    m_sortDescending = true;
    invalidate();
    sort(0, Qt::DescendingOrder);
    emit sortRoleChanged();
    emit sortDescendingChanged();
    emit countChanged();
}

QVariantMap ProcessFilterModel::get(int row) const
{
    QVariantMap map;
    const QModelIndex idx = index(row, 0);
    if (!idx.isValid()) {
        return map;
    }
    const QModelIndex source = mapToSource(idx);
    const auto roles = source.model()->roleNames();
    for (auto it = roles.constBegin(); it != roles.constEnd(); ++it) {
        map.insert(QString::fromUtf8(it.value()), source.data(it.key()));
    }
    return map;
}
