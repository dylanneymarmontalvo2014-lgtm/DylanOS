#pragma once
#include "AppItem.h"
#include <QAbstractListModel>
#include <QtQml/qqmlregistration.h>

class AppModel : public QAbstractListModel
{
    Q_OBJECT
public:
    enum Roles { AppRole = Qt::UserRole + 1, ReasonRole };
    explicit AppModel(QObject *parent = nullptr) : QAbstractListModel(parent) {}

    void setItems(const QList<AppItem *> &items);
    void appendItems(const QList<AppItem *> &items);
    AppItem *at(int row) const { return m_items.value(row); }
    const QList<AppItem *> &items() const { return m_items; }

    int rowCount(const QModelIndex &parent = {}) const override { return parent.isValid() ? 0 : int(m_items.size()); }
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

private:
    QList<AppItem *> m_items;
};
