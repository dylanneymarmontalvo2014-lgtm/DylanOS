#pragma once
#include "AppModel.h"
#include <QSortFilterProxyModel>
#include <QtQml/qqmlregistration.h>

// Filtering + sorting for every list in the UI (categories, search, installed, library...).
class AppFilterModel : public QSortFilterProxyModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString query READ query WRITE setQuery NOTIFY changed)
    Q_PROPERTY(bool nameOnly READ nameOnly WRITE setNameOnly NOTIFY changed)
    Q_PROPERTY(QString category READ category WRITE setCategory NOTIFY changed)
    Q_PROPERTY(QString statusFilter READ statusFilter WRITE setStatusFilter NOTIFY changed) // all|available|installed|managed
    Q_PROPERTY(QString sortKey READ sortKey WRITE setSortKey NOTIFY changed)               // name|date|category|relevance
    Q_PROPERTY(QStringList ids READ ids WRITE setIds NOTIFY changed)
    Q_PROPERTY(bool restrictToIds READ restrictToIds WRITE setRestrictToIds NOTIFY changed)
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    explicit AppFilterModel(QObject *parent = nullptr);
    QString query() const { return m_query; }
    bool nameOnly() const { return m_nameOnly; }
    QString category() const { return m_category; }
    QString statusFilter() const { return m_status; }
    QString sortKey() const { return m_sort; }
    QStringList ids() const { return m_ids; }
    bool restrictToIds() const { return m_restrict; }
    int count() const { return rowCount(); }
    void setQuery(const QString &q);
    void setNameOnly(bool b);
    void setCategory(const QString &c);
    void setStatusFilter(const QString &s);
    void setSortKey(const QString &s);
    void setIds(const QStringList &ids);
    void setRestrictToIds(bool b);

    QVariant data(const QModelIndex &index, int role) const override;
    static int score(const AppItem *a, const QString &needle);

Q_SIGNALS:
    void changed();
    void countChanged();

protected:
    bool filterAcceptsRow(int row, const QModelIndex &parent) const override;
    bool lessThan(const QModelIndex &l, const QModelIndex &r) const override;

private:
    void refresh();
    AppItem *itemAt(const QModelIndex &sourceIndex) const;
    QString m_query, m_category = QStringLiteral("all"), m_status = QStringLiteral("all"), m_sort = QStringLiteral("name");
    QStringList m_ids;
    bool m_restrict = false, m_nameOnly = false;
};
