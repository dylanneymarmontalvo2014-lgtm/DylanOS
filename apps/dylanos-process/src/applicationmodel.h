// Agrupación de procesos por aplicación para la pestaña "Aplicaciones".
//
// Una "app" es un ejecutable con icono propio: se suma el consumo de todos sus
// procesos (un navegador con varios procesos es una sola app) para que la
// tarjeta muestre el uso real agregado.

#pragma once

#include <QAbstractListModel>
#include <QHash>
#include <QString>
#include <QVector>

class ProcessModel;

class ApplicationModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Roles {
        KeyRole = Qt::UserRole + 1,
        NameRole,
        IconRole,
        IconPathRole,
        CpuRole,
        RssRole,
        PidCountRole,
        StateRole,
        PidsRole,
    };
    Q_ENUM(Roles)

    explicit ApplicationModel(QObject *parent = nullptr);

    // Recalcula la agrupación a partir del modelo de procesos.
    void setSource(ProcessModel *source);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return m_items.size(); }

    // Relee del modelo de procesos y recalcula agregados.
    Q_INVOKABLE void reload();
    // PIDs agregados de la app en esa fila (para cerrarla).
    Q_INVOKABLE QVariantList pidsAt(int row) const;

signals:
    void countChanged();

private:
    struct Item {
        QString key;
        QString name;
        QString icon;
        QString iconPath;
        double cpu = 0.0;
        quint64 rss = 0;
        int processes = 0;
        QString state;
        /// CPU del proceso dominante; define qué nombre/estado se muestra.
        double dominantCpu = 0.0;
        QList<int> pids;
    };

    ProcessModel *m_source = nullptr;
    QVector<Item> m_items;
};
