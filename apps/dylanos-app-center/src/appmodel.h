#pragma once
#include <QAbstractListModel>
#include <QList>
#include <KService>

class AppModel : public QAbstractListModel
{
    Q_OBJECT
public:
    enum Roles { NameRole = Qt::UserRole + 1, IconRole, ExecRole, CommentRole, DesktopIdRole };

    explicit AppModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void launchApp(int index);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE int pageCount(int pageSize) const;
    Q_INVOKABLE QVariantList itemsForPage(int page, int pageSize) const;
    Q_INVOKABLE void setFilter(const QString &text);

private:
    void loadApps();
    QList<KService::Ptr> visibleApps() const;
    QList<KService::Ptr> m_apps;
    QString m_filter;
};
