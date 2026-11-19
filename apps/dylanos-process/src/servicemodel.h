// Servicios reales de systemd para la pestaña "Servicios".
//
// La lista se relee del sistema bajo demanda (al entrar en la pestaña o al
// accionar una unidad); no se refresca en cada tick para no lanzar procesos
// cada 1,4 s.

#pragma once

#include <QAbstractListModel>
#include <QString>
#include <QVector>

class ServiceModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(bool available READ available NOTIFY countChanged)
    Q_PROPERTY(QString errorText READ errorText NOTIFY countChanged)

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        DescriptionRole,
        ActiveRole,
        ScopeRole,
        StateLabelRole,
    };
    Q_ENUM(Roles)

    explicit ServiceModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return m_items.size(); }
    bool available() const { return m_available; }
    QString errorText() const { return m_errorText; }

    // Relee las unidades del sistema.
    Q_INVOKABLE void reload();
    // Inicia o detiene una unidad; devuelve true si systemd lo aceptó.
    Q_INVOKABLE bool setActive(int row, bool active);
    // Solo para tests de interfaz en entornos sin systemd: inyecta unidades
    // para verificar el pintado. Nunca se usa en una sesión real, y las
    // acciones siguen intentando hablar con systemd de verdad.
    Q_INVOKABLE void setTestUnits(const QVariantList &units);
    Q_INVOKABLE void clearTestUnits();

signals:
    void countChanged();
    void notice(const QString &text, bool success);

private:
    struct Item {
        QString name;
        QString description;
        bool active = false;
        QString scope;
    };

    QVector<Item> m_items;
    bool m_available = false;
    QString m_errorText;
};
