#include "StoreController.h"
#include <QDate>
#include <QIcon>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJSEngine>
#include <QRegularExpression>
#include <QSettings>

#include <resources/AbstractResource.h>
#include <resources/ResourcesModel.h>
#include <resources/AbstractResourcesBackend.h>

StoreController *StoreController::s_instance = nullptr;

StoreController *StoreController::create(QQmlEngine *, QJSEngine *)
{
    QJSEngine::setObjectOwnership(s_instance, QJSEngine::CppOwnership);
    return s_instance;
}

StoreController::StoreController(PackageBackend *backend, QObject *parent)
    : QObject(parent)
    , m_backend(backend)
{
    m_backend->setParent(this);
    connect(m_backend, &PackageBackend::stateChanged, this, &StoreController::onBackendState);
    connect(m_backend, &PackageBackend::operationCompleted, this, [this](const QString &id, bool wasUpdate) {
        if (auto *a = app(id)) {
            const QString date = QDate::currentDate().toString(QStringLiteral("dd/MM/yyyy"));
            a->setInstalledOn(date);
            m_installedOnDates.insert(id, date);
            QSettings settings(QStringLiteral("DylanOS"), QStringLiteral("dylanos-store"));
            settings.setValue(QStringLiteral("installedOn/%1").arg(id), date);
            Q_EMIT toast(QStringLiteral("%1: %2").arg(a->m_name, wasUpdate ? QStringLiteral("actualización completada") : QStringLiteral("instalación completada")), QStringLiteral("ok"));
        }
    });

    QSettings settings(QStringLiteral("DylanOS"), QStringLiteral("dylanos-store"));
    m_favorites = settings.value(QStringLiteral("favorites")).toStringList();
    settings.beginGroup(QStringLiteral("installedOn"));
    const auto dateKeys = settings.allKeys();
    for (const QString &k : dateKeys)
        m_installedOnDates.insert(k, settings.value(k).toString());
    settings.endGroup();
}

bool StoreController::loadCatalog(const QString &path, QString *error)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) {
        if (error) *error = f.errorString();
        return false;
    }
    QJsonParseError pe;
    const auto doc = QJsonDocument::fromJson(f.readAll(), &pe);
    if (doc.isNull()) {
        if (error) *error = pe.errorString();
        return false;
    }
    return loadCatalog(doc.object(), error);
}

static QStringList strings(const QJsonValue &v)
{
    QStringList l;
    for (const auto &x : v.toArray())
        l << x.toString();
    return l;
}

bool StoreController::loadCatalog(const QJsonObject &root, QString *error)
{
    if (!root.contains(QLatin1String("apps"))) {
        if (error) *error = QStringLiteral("catalog has no 'apps'");
        return false;
    }
    const auto store = root.value(QLatin1String("store")).toObject();
    m_storeName = store.value(QLatin1String("name")).toString(QStringLiteral("DylanOS Store"));
    m_storeVersion = store.value(QLatin1String("version")).toString(QStringLiteral("x.y.z"));

    m_categories.clear();
    QHash<QString, QString> labels;
    for (const auto &c : root.value(QLatin1String("categories")).toArray()) {
        const auto o = c.toObject();
        labels.insert(o[QLatin1String("id")].toString(), o[QLatin1String("label")].toString());
        m_categories << QVariantMap{{QStringLiteral("id"), o[QLatin1String("id")].toString()}, {QStringLiteral("label"), o[QLatin1String("label")].toString()}, {QStringLiteral("desc"), o[QLatin1String("desc")].toString()}, {QStringLiteral("icon"), o[QLatin1String("icon")].toString()}};
    }
    m_collections.clear();
    for (const auto &c : root.value(QLatin1String("collections")).toArray()) {
        const auto o = c.toObject();
        m_collections << QVariantMap{{QStringLiteral("name"), o[QLatin1String("name")].toString()}, {QStringLiteral("desc"), o[QLatin1String("desc")].toString()}, {QStringLiteral("ids"), strings(o[QLatin1String("ids")])}};
    }

    qDeleteAll(m_items);
    m_items.clear();
    QList<AppItem *> items;
    QList<CatalogEntry> entries;
    QStringList updates;
    for (const auto &v : root.value(QLatin1String("apps")).toArray()) {
        const auto o = v.toObject();
        auto *a = new AppItem(this);
        a->m_id = o[QLatin1String("id")].toString();
        a->m_name = o[QLatin1String("name")].toString();
        a->m_glyph = o[QLatin1String("glyph")].toString();
        a->m_color = o[QLatin1String("color")].toString();
        a->m_category = o[QLatin1String("cat")].toString();
        a->m_categoryLabel = labels.value(a->m_category);
        a->m_short = o[QLatin1String("short")].toString();
        a->m_long = o[QLatin1String("long")].toString();
        a->m_dev = o[QLatin1String("dev")].toString();
        a->m_license = o[QLatin1String("license")].toString();
        a->m_version = o[QLatin1String("v")].toString();
        a->m_newVersion = o[QLatin1String("nv")].toString();
        a->m_size = o[QLatin1String("size")].toString();
        a->m_date = o[QLatin1String("date")].toString();
        a->m_installedOn = o[QLatin1String("installedOn")].toString();
        a->m_initial = o[QLatin1String("initial")].toString(QStringLiteral("none"));
        a->m_tags = strings(o[QLatin1String("tags")]);
        a->m_changes = strings(o[QLatin1String("changes")]);
        a->m_unknown = o[QLatin1String("unknown")].toBool();
        a->m_failsOnce = o[QLatin1String("failsOnce")].toString();
        m_items.insert(a->m_id, a);
        items << a;
        entries.append({a->m_id, a->m_initial, a->m_version, a->m_newVersion, a->m_failsOnce});
        if (a->m_initial == QLatin1String("update"))
            updates << a->m_id;
    }
    m_backend->setCatalog(entries);
    for (auto *a : std::as_const(items)) {
        const auto s = m_backend->state(a->m_id);
        a->setLive(s.status, s.progress, s.isUpdate, s.errorKind, s.version);
    }
    m_model.setItems(items);

    m_lists.clear();
    for (const char *k : {"featured", "popular", "newest", "essential", "recommended"})
        m_lists.insert(QLatin1String(k), strings(root.value(QLatin1String(k))));
    m_lists.insert(QStringLiteral("updates"), updates);
    recount();
    return true;
}

// ─── Real catalog (libdiscover) ─────────────────────────────────────────────

static QStringList changelogLines(const QString &html)
{
    QStringList out;
    QString text = html;
    text.remove(QRegularExpression(QStringLiteral("<[^>]*>")));
    text.replace(QString::fromLatin1("&"), QLatin1String("&"));
    text.replace(QString::fromLatin1("<"), QLatin1String("<"));
    text.replace(QString::fromLatin1(">"), QLatin1String(">"));
    const auto lines = text.split(QRegularExpression(QStringLiteral("[\n\r]+")), Qt::SkipEmptyParts);
    for (const QString &l : lines) {
        const QString t = l.trimmed();
        if (!t.isEmpty() && t.size() < 400)
            out << t;
        if (out.size() >= 6)
            break;
    }
    return out;
}

static bool iconUsable(const QVariant &v)
{
    if (!v.isValid() || v.isNull())
        return false;
    if (v.metaType() == QMetaType::fromType<QString>()) {
        const QString s = v.toString();
        return !s.isEmpty() && s != QLatin1String("package-x-generic") && s != QLatin1String("applications-other");
    }
    if (v.canConvert<QIcon>())
        return !v.value<QIcon>().isNull();
    if (v.canConvert<QUrl>())
        return v.toUrl().isValid() && !v.toUrl().toString().isEmpty();
    return false;
}

// Deterministic palette in the store's crimson family, keyed by app id.
static QString paletteColor(const QString &id)
{
    static const char *palette[] = {"#8e1b30", "#a12836", "#6d1030", "#86431c", "#1c6d4f", "#5a1c6d", "#1c4a6d", "#6d1c5a", "#4a4f6d", "#6d5a1c"};
    return QString::fromLatin1(palette[qHash(id) % 10]);
}

bool StoreController::loadStoreConfig()
{
    QFile f(QStringLiteral(":/data/store-config.json"));
    if (!f.open(QIODevice::ReadOnly))
        return false;
    const auto doc = QJsonDocument::fromJson(f.readAll());
    if (doc.isNull())
        return false;
    const auto root = doc.object();
    m_categories.clear();
    for (const auto &c : root.value(QLatin1String("categories")).toArray()) {
        const auto o = c.toObject();
        m_categories << QVariantMap{{QStringLiteral("id"), o[QLatin1String("id")].toString()}, {QStringLiteral("label"), o[QLatin1String("label")].toString()}, {QStringLiteral("desc"), o[QLatin1String("desc")].toString()}, {QStringLiteral("icon"), o[QLatin1String("icon")].toString()}};
    }
    m_curatedFeatured = strings(root.value(QLatin1String("featured")));
    m_curatedPopular = strings(root.value(QLatin1String("popular")));
    m_curatedEssential = strings(root.value(QLatin1String("essential")));
    m_curatedRecommended = strings(root.value(QLatin1String("recommended")));
    m_collectionDefs.clear();
    for (const auto &c : root.value(QLatin1String("collections")).toArray()) {
        const auto o = c.toObject();
        m_collectionDefs << QVariantMap{{QStringLiteral("name"), o[QLatin1String("name")].toString()}, {QStringLiteral("desc"), o[QLatin1String("desc")].toString()}, {QStringLiteral("ids"), strings(o[QLatin1String("ids")])}};
    }
    m_storeConfigLoaded = true;
    return true;
}

QString StoreController::mapCategory(AbstractResource *resource) const
{
    struct Rule {
        const char *appstream;
        const char *id;
    };
    static const Rule rules[] = {
        {"Game", "games"}, {"Development", "dev"}, {"Graphics", "gfx"}, {"Network", "net"},
        {"AudioVideo", "media"}, {"Office", "office"}, {"Education", "edu"}, {"Science", "sci"},
        {"Security", "sec"}, {"Settings", "custom"}, {"System", "sys"},
    };
    for (const auto &r : rules) {
        if (resource->hasCategory(QLatin1String(r.appstream)))
            return QLatin1String(r.id);
    }
    if (resource->hasCategory(QLatin1String("Utility")))
        return QLatin1String("acc");
    return QStringLiteral("sys");
}

void StoreController::addResources(const QVector<AbstractResource *> &resources)
{
    QList<AppItem *> batch;
    for (auto *res : resources) {
        if (!res || res->type() != AbstractResource::Application)
            continue;
        QString id = res->appstreamId();
        if (id.isEmpty())
            id = res->packageName();
        if (id.isEmpty() || m_items.contains(id))
            continue;

        auto *a = new AppItem(this);
        a->m_id = id;
        a->m_name = res->name();
        if (a->m_name.isEmpty())
            a->m_name = res->packageName();
        a->m_short = res->comment();
        a->m_long = res->longDescription();
        a->m_dev = res->author();
        if (a->m_dev.isEmpty())
            a->m_dev = res->packageName();
        const QJsonArray licenses = res->licenses();
        if (!licenses.isEmpty())
            a->m_license = licenses.first().toObject().value(QStringLiteral("name")).toString();
        a->m_version = res->installedVersion();
        if (a->m_version.isEmpty())
            a->m_version = res->availableVersion();
        a->m_newVersion = res->availableVersion();
        a->m_size = res->sizeDescription();
        const QDate released = res->releaseDate();
        if (released.isValid())
            a->m_date = released.toString(Qt::ISODate);
        a->m_category = mapCategory(res);
        for (const auto &c : m_categories) {
            if (c.toMap().value(QStringLiteral("id")).toString() == a->m_category) {
                a->m_categoryLabel = c.toMap().value(QStringLiteral("label")).toString();
                break;
            }
        }
        a->m_tags = QStringList{res->packageName(), a->m_categoryLabel};
        a->m_glyph = a->m_name.left(1).toUpper();
        a->m_color = paletteColor(id);
        a->m_installedOn = m_installedOnDates.value(id);

        m_backend->registerResource(id, res);
        a->setHasIcon(iconUsable(m_backend->resourceIcon(id)));
        connect(res, &AbstractResource::iconChanged, this, [this, id] {
            if (auto *it = app(id)) {
                it->setHasIcon(iconUsable(m_backend->resourceIcon(id)));
                it->bumpIconVersion();
            }
        });
        const auto s = m_backend->state(id);
        a->m_initial = s.status;
        a->setLive(s.status, s.progress, s.isUpdate, s.errorKind, s.version);

        m_items.insert(id, a);
        batch << a;
    }
    if (!batch.isEmpty()) {
        m_model.appendItems(batch);
        rebuildLists();
        recount();
    }
}

bool StoreController::loadFromResources(ResourcesModel *model)
{
    m_storeName = QStringLiteral("DylanOS Store");
    m_storeVersion = QStringLiteral(DYLANOS_STORE_VERSION);
    if (!loadStoreConfig())
        return false;

    const auto backends = model->backends();
    m_pendingStreams = 0;
    for (auto *backend : backends) {
        if (!backend || !backend->hasApplications())
            continue;
        ++m_pendingStreams;
        auto *stream = backend->search(AbstractResourcesBackend::Filters{});
        connect(stream, &ResultsStream::resourcesFound, this, [this](const QVector<StreamResult> &results) {
            QVector<AbstractResource *> resources;
            resources.reserve(results.size());
            for (const auto &r : results)
                resources << r.resource;
            addResources(resources);
        });
        connect(stream, &QObject::destroyed, this, [this, model] {
            if (--m_pendingStreams <= 0) {
                const auto backends = model->backends();
                for (auto *b : backends)
                    b->checkForUpdates();
                Q_EMIT catalogReady();
            }
        });
    }
    if (m_pendingStreams == 0)
        Q_EMIT catalogReady();
    return true;
}

QStringList StoreController::list(const QString &name) const
{
    return m_lists.value(name);
}

void StoreController::rebuildLists()
{
    const auto byName = [this](AppItem *a, AppItem *b) { return a->m_name.localeAwareCompare(b->m_name) < 0; };

    auto curated = [this](const QStringList &ids) {
        QStringList out;
        for (const QString &id : ids) {
            if (m_items.contains(id) && !out.contains(id))
                out << id;
        }
        return out;
    };
    auto pad = [this, &curated, &byName](const QStringList &ids, int target) {
        QStringList out = curated(ids);
        if (out.size() >= target)
            return out.mid(0, target);
        QList<AppItem *> pool;
        for (auto *a : std::as_const(m_items))
            if (!out.contains(a->m_id) && a->m_hasIcon)
                pool << a;
        std::sort(pool.begin(), pool.end(), byName);
        for (auto *a : std::as_const(pool)) {
            out << a->m_id;
            if (out.size() >= target)
                break;
        }
        return out;
    };

    m_lists.insert(QStringLiteral("featured"), pad(m_curatedFeatured, 5));
    m_lists.insert(QStringLiteral("popular"), pad(m_curatedPopular, 5));
    m_lists.insert(QStringLiteral("essential"), pad(m_curatedEssential, 5));
    m_lists.insert(QStringLiteral("recommended"), pad(m_curatedRecommended, 12));

    // "Novedades": real release dates, newest first.
    QList<AppItem *> dated;
    for (auto *a : std::as_const(m_items))
        if (!a->m_date.isEmpty())
            dated << a;
    std::sort(dated.begin(), dated.end(), [](AppItem *x, AppItem *y) { return x->m_date > y->m_date; });
    QStringList newest;
    for (auto *a : std::as_const(dated)) {
        newest << a->m_id;
        if (newest.size() >= 12)
            break;
    }
    m_lists.insert(QStringLiteral("newest"), newest);

    // Updates shelf.
    QStringList updates;
    for (auto *a : std::as_const(m_items))
        if (a->status() == QLatin1String("update"))
            updates << a->m_id;
    m_lists.insert(QStringLiteral("updates"), updates);

    // Collections.
    m_collections.clear();
    for (const auto &def : std::as_const(m_collectionDefs)) {
        const auto m = def.toMap();
        QStringList ids;
        for (const QString &id : m.value(QStringLiteral("ids")).toStringList()) {
            if (m_items.contains(id))
                ids << id;
            if (ids.size() >= 5)
                break;
        }
        m_collections << QVariantMap{{QStringLiteral("name"), m.value(QStringLiteral("name"))}, {QStringLiteral("desc"), m.value(QStringLiteral("desc"))}, {QStringLiteral("ids"), ids}};
    }
}

void StoreController::onBackendState(const QString &id)
{
    if (auto *a = app(id)) {
        const auto s = m_backend->state(id);
        a->setLive(s.status, s.progress, s.isUpdate, s.errorKind, s.version);
        recount();
        QStringList updates;
        for (auto *it : std::as_const(m_items))
            if (it->status() == QLatin1String("update"))
                updates << it->m_id;
        m_lists.insert(QStringLiteral("updates"), updates);
    }
}

void StoreController::recount()
{
    int u = 0, i = 0;
    for (auto *a : std::as_const(m_items)) {
        if (a->status() == QLatin1String("update")) ++u;
        if (a->status() == QLatin1String("installed")) ++i;
    }
    if (u != m_updateCount || i != m_installedCount) {
        m_updateCount = u;
        m_installedCount = i;
        Q_EMIT countsChanged();
    }
}

void StoreController::setOffline(bool b)
{
    if (b == m_offline) return;
    m_offline = b;
    m_backend->setOffline(b);
    Q_EMIT offlineChanged();
}

int StoreController::categoryCount(const QString &id) const
{
    int n = 0;
    for (auto *a : std::as_const(m_model.items()))
        if (a->m_category == id) ++n;
    return n;
}

QVariantMap StoreController::category(const QString &id) const
{
    for (const auto &c : m_categories)
        if (c.toMap().value(QStringLiteral("id")) == id) return c.toMap();
    return {};
}

QStringList StoreController::recentInstalls(int n) const
{
    QList<AppItem *> l;
    for (auto *a : std::as_const(m_model.items()))
        if (!a->m_installedOn.isEmpty()) l << a;
    std::sort(l.begin(), l.end(), [](AppItem *x, AppItem *y) { return x->m_installedOn > y->m_installedOn; });
    QStringList ids;
    const QList<AppItem *> top = l.mid(0, n);
    for (auto *a : std::as_const(top)) ids << a->m_id;
    return ids;
}

void StoreController::cancel(const QString &id)
{
    m_backend->cancel(id);
    Q_EMIT toast(QStringLiteral("Instalación cancelada"), QStringLiteral("info"));
}

void StoreController::uninstall(const QString &id)
{
    m_backend->remove(id);
    if (auto *a = app(id))
        Q_EMIT toast(QStringLiteral("%1 se ha desinstalado").arg(a->m_name), QStringLiteral("info"));
}

void StoreController::toggleFavorite(const QString &id)
{
    if (!m_favorites.removeOne(id))
        m_favorites << id;
    QSettings settings(QStringLiteral("DylanOS"), QStringLiteral("dylanos-store"));
    settings.setValue(QStringLiteral("favorites"), m_favorites);
    Q_EMIT favoritesChanged();
}

void StoreController::openApp(const QString &id)
{
    if (!m_backend->launch(id))
        Q_EMIT toast(QStringLiteral("No se puede ejecutar %1").arg(id), QStringLiteral("info"));
}
