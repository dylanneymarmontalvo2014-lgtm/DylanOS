#pragma once
#include "AppModel.h"
#include "services/PackageBackend.h"
#include <QHash>
#include <QJsonObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

class QQmlEngine;
class QJSEngine;
class ResourcesModel;
class AbstractResource;

// Single entry point QML talks to. It owns the catalog, translates backend events into
// AppItem updates and exposes user intents (install, update...) without any shell access.
class StoreController : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Store)
    QML_SINGLETON

    Q_PROPERTY(QString storeName READ storeName CONSTANT)
    Q_PROPERTY(QString storeVersion READ storeVersion CONSTANT)
    Q_PROPERTY(QString backendKind READ backendKind CONSTANT)
    Q_PROPERTY(AppModel *appModel READ appModel CONSTANT)
    Q_PROPERTY(QVariantList categories READ categories CONSTANT)
    Q_PROPERTY(QVariantList collections READ collections CONSTANT)
    Q_PROPERTY(QStringList favorites READ favorites NOTIFY favoritesChanged)
    Q_PROPERTY(bool offline READ offline WRITE setOffline NOTIFY offlineChanged)
    Q_PROPERTY(int updateCount READ updateCount NOTIFY countsChanged)
    Q_PROPERTY(int installedCount READ installedCount NOTIFY countsChanged)

public:
    explicit StoreController(PackageBackend *backend, QObject *parent = nullptr);
    static StoreController *s_instance; // set by main() / tests before QML loads
    static StoreController *create(QQmlEngine *, QJSEngine *);

    bool loadCatalog(const QString &path, QString *error = nullptr);
    bool loadCatalog(const QJsonObject &root, QString *error = nullptr);
    bool loadFromResources(ResourcesModel *model); // real catalog via libdiscover backends

    QString storeName() const { return m_storeName; }
    QString storeVersion() const { return m_storeVersion; }
    QString backendKind() const { return m_backend->kind(); }
    AppModel *appModel() { return &m_model; }
    QVariantList categories() const { return m_categories; }
    QVariantList collections() const { return m_collections; }
    QStringList favorites() const { return m_favorites; }
    bool offline() const { return m_offline; }
    void setOffline(bool b);
    int updateCount() const { return m_updateCount; }
    int installedCount() const { return m_installedCount; }

    QVariant resourceIcon(const QString &id) const { return m_backend->resourceIcon(id); }

    Q_INVOKABLE AppItem *app(const QString &id) const { return m_items.value(id); }
    Q_INVOKABLE QStringList list(const QString &name) const; // featured|popular|newest|essential|recommended|updates
    Q_INVOKABLE int categoryCount(const QString &id) const;
    Q_INVOKABLE QVariantMap category(const QString &id) const;
    Q_INVOKABLE QStringList recentInstalls(int n) const;

    Q_INVOKABLE void install(const QString &id) { m_backend->install(id); }
    Q_INVOKABLE void update(const QString &id) { m_backend->update(id); }
    Q_INVOKABLE void updateAll() { m_backend->updateAll(); }
    Q_INVOKABLE void retry(const QString &id) { m_backend->retry(id); }
    Q_INVOKABLE void cancel(const QString &id);
    Q_INVOKABLE void uninstall(const QString &id);
    Q_INVOKABLE void toggleFavorite(const QString &id);
    Q_INVOKABLE void openApp(const QString &id);
    Q_INVOKABLE void notify(const QString &text, const QString &tone = QStringLiteral("info")) { Q_EMIT toast(text, tone); }

Q_SIGNALS:
    void toast(const QString &text, const QString &tone);
    void favoritesChanged();
    void offlineChanged();
    void countsChanged();
    void catalogReady();

private:
    void onBackendState(const QString &id);
    void recount();
    void rebuildLists();
    void addResources(const QVector<AbstractResource *> &resources);
    bool loadStoreConfig();
    QString mapCategory(AbstractResource *resource) const;

    PackageBackend *m_backend;
    AppModel m_model;
    QHash<QString, AppItem *> m_items;
    QHash<QString, QStringList> m_lists;
    QHash<QString, QString> m_installedOnDates;
    QVariantList m_categories, m_collections, m_collectionDefs;
    QStringList m_favorites;
    QStringList m_curatedFeatured, m_curatedPopular, m_curatedEssential, m_curatedRecommended;
    QString m_storeName, m_storeVersion;
    bool m_offline = false;
    bool m_storeConfigLoaded = false;
    int m_updateCount = 0, m_installedCount = 0;
    int m_pendingStreams = 0;
};
