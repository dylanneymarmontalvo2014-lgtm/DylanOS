// Modelo de procesos para QML: una fila por proceso real leída del núcleo.
//
// La lista se filtra y ordena en C++ (QSortFilterProxyModel) para que la vista
// no recorra cientos de filas desde QML en cada refresco de 1,4 s.

#pragma once

#include <QAbstractListModel>
#include <QByteArray>
#include <QHash>
#include <QIcon>
#include <QSortFilterProxyModel>
#include <QString>
#include <QVector>

struct DpSampler;

class ProcessModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    // Totales globales del último muestreo, ya formateados para la UI.
    Q_PROPERTY(qreal cpuPercent READ cpuPercent NOTIFY totalsChanged)
    Q_PROPERTY(qreal memUsedBytes READ memUsedBytes NOTIFY totalsChanged)
    Q_PROPERTY(qreal memTotalBytes READ memTotalBytes NOTIFY totalsChanged)
    Q_PROPERTY(qreal swapUsedBytes READ swapUsedBytes NOTIFY totalsChanged)
    Q_PROPERTY(qreal swapTotalBytes READ swapTotalBytes NOTIFY totalsChanged)
    Q_PROPERTY(qreal netRx READ netRx NOTIFY totalsChanged)
    Q_PROPERTY(qreal netTx READ netTx NOTIFY totalsChanged)
    Q_PROPERTY(qreal diskRead READ diskRead NOTIFY totalsChanged)
    Q_PROPERTY(qreal diskWrite READ diskWrite NOTIFY totalsChanged)
    Q_PROPERTY(qreal load1 READ load1 NOTIFY totalsChanged)
    Q_PROPERTY(qreal load5 READ load5 NOTIFY totalsChanged)
    Q_PROPERTY(qreal load15 READ load15 NOTIFY totalsChanged)
    Q_PROPERTY(int cores READ cores NOTIFY totalsChanged)
    Q_PROPERTY(int threads READ threads NOTIFY totalsChanged)
    Q_PROPERTY(int iconCount READ iconCount NOTIFY totalsChanged)

public:
    enum Roles {
        PidRole = Qt::UserRole + 1,
        NameRole,
        CommandRole,
        UserRole,
        UidRole,
        CpuRole,
        RssRole,
        IconRole,
        IconPathRole,
        StateRole,
        ThreadsRole,
        PriorityRole,
        NiceRole,
        UptimeRole,
        IoReadRole,
        IoWriteRole,
        SwapRole,
    };
    Q_ENUM(Roles)

    explicit ProcessModel(QObject *parent = nullptr);
    ~ProcessModel() override;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;
    qreal cpuPercent() const { return m_cpuPercent; }
    qreal memUsedBytes() const { return m_memUsed; }
    qreal memTotalBytes() const { return m_memTotal; }
    qreal swapUsedBytes() const { return m_swapUsed; }
    qreal swapTotalBytes() const { return m_swapTotal; }
    qreal netRx() const { return m_netRx; }
    qreal netTx() const { return m_netTx; }
    qreal diskRead() const { return m_diskRead; }
    qreal diskWrite() const { return m_diskWrite; }
    qreal load1() const { return m_load1; }
    qreal load5() const { return m_load5; }
    qreal load15() const { return m_load15; }
    int cores() const { return m_cores; }
    int threads() const { return m_threads; }
    int iconCount() const { return m_iconCount; }

    // Refresca desde el núcleo. Devuelve false si no hay muestra disponible.
    Q_INVOKABLE bool refresh();
    // Índice de la fila con ese PID, o -1.
    Q_INVOKABLE int rowForPid(int pid) const;
    Q_INVOKABLE QString stateLabelFor(int row) const;

signals:
    void countChanged();
    void totalsChanged();

private:
    struct Row {
        int pid = 0;
        int ppid = 0;
        QString name;
        QString command;
        QString user;
        uint uid = 0;
        double cpu = 0.0;
        quint64 rss = 0;
        QString icon;
        QString iconPath;
        QString state;
        int threads = 0;
        int priority = 0;
        int nice = 0;
        quint64 uptime = 0;
        quint64 ioRead = 0;
        quint64 ioWrite = 0;
        quint64 swap = 0;
    };

    void applySnapshot(const void *snapshot);
    QString resolveIconPath(const QString &icon);

    DpSampler *m_sampler = nullptr;
    QVector<Row> m_rows;
    QHash<QString, QString> m_iconCache;
    double m_cpuPercent = 0.0;
    quint64 m_memUsed = 0;
    quint64 m_memTotal = 0;
    quint64 m_swapUsed = 0;
    quint64 m_swapTotal = 0;
    double m_netRx = 0.0;
    double m_netTx = 0.0;
    double m_diskRead = 0.0;
    double m_diskWrite = 0.0;
    double m_load1 = 0.0;
    double m_load5 = 0.0;
    double m_load15 = 0.0;
    int m_cores = 1;
    int m_threads = 0;
    int m_iconCount = 0;
};

// Filtro de búsqueda + estado, con el orden que pide la tabla.
class ProcessFilterModel : public QSortFilterProxyModel
{
    Q_OBJECT
    Q_PROPERTY(QString searchText READ searchText WRITE setSearchText NOTIFY searchTextChanged)
    Q_PROPERTY(QString stateFilter READ stateFilter WRITE setStateFilter NOTIFY stateFilterChanged)
    Q_PROPERTY(QString sortRole READ sortRole WRITE setSortRole NOTIFY sortRoleChanged)
    Q_PROPERTY(bool sortDescending READ sortDescending WRITE setSortDescending NOTIFY
                   sortDescendingChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    explicit ProcessFilterModel(QObject *parent = nullptr);

    QString searchText() const { return m_searchText; }
    void setSearchText(const QString &text);
    QString stateFilter() const { return m_stateFilter; }
    void setStateFilter(const QString &state);
    QString sortRole() const { return m_sortRole; }
    void setSortRole(const QString &role);
    bool sortDescending() const { return m_sortDescending; }
    void setSortDescending(bool descending);
    int count() const;

    // Alterna el orden de una columna como en el prototipo: si ya estaba
    // ordenando por ella se invierte la dirección; si no, arranca descendente.
    Q_INVOKABLE void toggleSort(const QString &role);
    Q_INVOKABLE QVariantMap get(int row) const;

protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const override;
    bool lessThan(const QModelIndex &left, const QModelIndex &right) const override;

signals:
    void searchTextChanged();
    void stateFilterChanged();
    void sortRoleChanged();
    void sortDescendingChanged();
    void countChanged();

private:
    int roleFor(const QString &name) const;

    QString m_searchText;
    QString m_stateFilter = QStringLiteral("all");
    QString m_sortRole = QStringLiteral("cpu");
    bool m_sortDescending = true;
};
