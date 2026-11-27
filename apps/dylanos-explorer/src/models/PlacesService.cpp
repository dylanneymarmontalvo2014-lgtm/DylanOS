#include "PlacesService.h"

#include "services/FileOperations.h"
#include "services/Formatters.h"

#include <QDir>
#include <QFileInfo>
#include <QSet>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QtConcurrent>
#include <KIOFileWidgets/kfileplacesmodel.h>

#include <algorithm>

namespace {

QString standardDir(QStandardPaths::StandardLocation loc, const QString &fallbackName)
{
    const QString p = QStandardPaths::writableLocation(loc);
    return p.isEmpty() ? QDir(QDir::homePath()).filePath(fallbackName) : p;
}

void walk(const QString &dir, int depth, QVector<QFileInfo> &out, int &visited)
{
    if (visited > 6000)
        return;
    const auto list = QDir(dir).entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot, QDir::NoSort);
    for (const QFileInfo &fi : list) {
        ++visited;
        if (fi.isSymLink())
            continue;
        if (fi.isDir()) {
            if (depth < 3)
                walk(fi.absoluteFilePath(), depth + 1, out, visited);
        } else {
            out.append(fi);
        }
    }
}

QVariantList scanRecent(const QStringList &roots, int limit)
{
    QVector<QFileInfo> files;
    int visited = 0;
    for (const QString &r : roots)
        if (QFileInfo(r).isDir())
            walk(r, 0, files, visited);
    std::sort(files.begin(), files.end(),
              [](const QFileInfo &a, const QFileInfo &b) { return a.lastModified() > b.lastModified(); });
    QVariantList out;
    for (const QFileInfo &fi : std::as_const(files)) {
        if (out.size() >= limit)
            break;
        QVariantMap m;
        m["name"] = fi.fileName();
        m["path"] = fi.absoluteFilePath();
        m["suffix"] = fi.suffix().toLower();
        m["location"] = fi.dir().dirName();
        m["locationPath"] = fi.absolutePath();
        m["modifiedText"] = Formatters::modified(fi.lastModified());
        m["sizeText"] = Formatters::fileSize(fi.size());
        out.append(m);
    }
    return out;
}

} // namespace

PlacesService *PlacesService::s_instance = nullptr;

PlacesService *PlacesService::instance()
{
    return s_instance;
}

PlacesService::PlacesService(QObject *parent)
    : QObject(parent)
{
    s_instance = this;
    m_places = new KFilePlacesModel(this);
    connect(m_places, &KFilePlacesModel::rowsInserted, this, [this] { refreshDevices(); });
    connect(m_places, &KFilePlacesModel::rowsRemoved, this, [this] { refreshDevices(); });
    connect(m_places, &KFilePlacesModel::dataChanged, this, [this](const QModelIndex &, const QModelIndex &) { refreshDevices(); });
    connect(m_places, &KFilePlacesModel::setupDone, this, [this](const QModelIndex &idx, bool success) {
        refreshDevices();
        const QUrl url = m_places->url(idx);
        if (!m_pendingSetup.isEmpty()) {
            const QString done = m_pendingSetup;
            m_pendingSetup.clear();
            if (success)
                emit mounted(done.isEmpty() ? url.toString() : done);
            else
                m_lastSetupFailed = true;
        }
    });

    auto fav = [this](const QString &name, const QString &icon, const QString &path) {
        m_favorites.append(QVariantMap{{"name", name}, {"icon", icon}, {"path", path}});
    };
    // Iconos estándar del XDG icon theme: se resuelven contra el tema
    // activo del sistema, no contra trazos embebidos.
    fav(QStringLiteral("Inicio"), QStringLiteral("user-home"), QStringLiteral("home://"));
    fav(QStringLiteral("Escritorio"), QStringLiteral("user-desktop"), standardDir(QStandardPaths::DesktopLocation, "Escritorio"));
    fav(QStringLiteral("Documentos"), QStringLiteral("folder-documents"), standardDir(QStandardPaths::DocumentsLocation, "Documentos"));
    fav(QStringLiteral("Descargas"), QStringLiteral("folder-download"), standardDir(QStandardPaths::DownloadLocation, "Descargas"));
    fav(QStringLiteral("Imágenes"), QStringLiteral("folder-images"), standardDir(QStandardPaths::PicturesLocation, "Imágenes"));
    fav(QStringLiteral("Música"), QStringLiteral("folder-music"), standardDir(QStandardPaths::MusicLocation, "Música"));
    fav(QStringLiteral("Videos"), QStringLiteral("folder-videos"), standardDir(QStandardPaths::MoviesLocation, "Videos"));
    fav(QStringLiteral("Papelera"), QStringLiteral("user-trash"), FileOperations::trashFilesDir());

    m_network.append(QVariantMap{{"name", QStringLiteral("Red local")}, {"icon", QStringLiteral("network-workgroup")}, {"kind", QStringLiteral("local")}});
    m_network.append(QVariantMap{{"name", QStringLiteral("Servidor DLN")}, {"icon", QStringLiteral("network-server")}, {"kind", QStringLiteral("server")}});

    connect(&m_recentWatcher, &QFutureWatcher<QVariantList>::finished, this, [this] {
        m_recent = m_recentWatcher.result();
        emit recentFilesChanged();
    });
    m_deviceTimer.setInterval(60000);
    connect(&m_deviceTimer, &QTimer::timeout, this, &PlacesService::refreshDevices);
    // KFilePlacesModel ya avisa de altas, bajas y cambios de estado (montaje,
    // etiqueta, icono). Sondear la lista cada 10 s despertaba el proceso sin
    // necesidad; ahora solo se refresca por evento. El temporizador queda para
    // el espacio libre, que QStorageInfo no notifica, y con un periodo largo.
    connect(m_places, &QAbstractItemModel::rowsInserted, this, &PlacesService::refreshDevices);
    connect(m_places, &QAbstractItemModel::rowsRemoved, this, &PlacesService::refreshDevices);
    connect(m_places, &QAbstractItemModel::modelReset, this, &PlacesService::refreshDevices);
    connect(m_places, &QAbstractItemModel::dataChanged, this, &PlacesService::refreshDevices);
    m_deviceTimer.start();

    refreshDevices();
    refreshHomeFolders();
    refreshRecents();
}

PlacesService::~PlacesService()
{
    m_recentWatcher.waitForFinished();
}

QString PlacesService::projectsDir()
{
    const QDir home(QDir::homePath());
    for (const char *name : {"Proyectos", "Projects"})
        if (home.exists(QLatin1String(name)))
            return home.filePath(QLatin1String(name));
    return home.filePath(QStringLiteral("Proyectos"));
}

void PlacesService::refresh()
{
    refreshDevices();
    refreshHomeFolders();
    refreshRecents();
}

void PlacesService::refreshDevices()
{
    // Unidades y volúmenes exactamente como los ve Dolphin (KFilePlacesModel,
    // Solid): etiquetas correctas, entradas ocultas filtradas y estado de
    // montaje real. El espacio libre se lee del punto de montaje.
    QVariantList list;
    const auto rows = m_places->rowCount();
    for (int r = 0; r < rows; ++r) {
        const QModelIndex idx = m_places->index(r, 0);
        if (!m_places->isDevice(idx))
            continue;
        const QUrl url = m_places->url(idx);
        const bool mounted = url.isLocalFile() && QFileInfo(url.toLocalFile()).exists();
        const QString mountPoint = mounted ? url.toLocalFile() : QString();
        QVariantMap m;
        m["name"] = m_places->text(idx);
        m["path"] = url.toString();
        m["mounted"] = mounted;
        // Nombre de icono estándar de la unidad (p. ej. drive-harddisk,
        // drive-removable-media) tal como lo resuelve el tema de iconos
        // activo del sistema.
        m["icon"] = m_places->data(idx, KFilePlacesModel::IconNameRole).toString();
        if (mounted && !mountPoint.isEmpty()) {
            const QStorageInfo s(mountPoint);
            const qint64 total = s.bytesTotal();
            const qint64 avail = s.bytesAvailable();
            m["usedFraction"] = total > 0 ? 1.0 - double(avail) / double(total) : 0.0;
            m["text"] = QStringLiteral("%1 disponibles de %2").arg(Formatters::capacity(avail), Formatters::capacity(total));
        } else {
            m["usedFraction"] = 0.0;
            m["text"] = QStringLiteral("Sin montar — clic para montar");
        }
        list.append(m);
    }
    if (list != m_devices) {
        m_devices = list;
        emit devicesChanged();
    }
}

bool PlacesService::isUnmountedDevice(const QString &url) const
{
    const QUrl want(url);
    const auto rows = m_places->rowCount();
    for (int r = 0; r < rows; ++r) {
        const QModelIndex idx = m_places->index(r, 0);
        if (m_places->isDevice(idx) && m_places->url(idx) == want && !(want.isLocalFile() && QFileInfo(want.toLocalFile()).exists()))
            return true;
    }
    return false;
}

void PlacesService::requestSetup(const QString &url)
{
    const QUrl want(url);
    const auto rows = m_places->rowCount();
    for (int r = 0; r < rows; ++r) {
        const QModelIndex idx = m_places->index(r, 0);
        if (m_places->isDevice(idx) && m_places->url(idx) == want && !(want.isLocalFile() && QFileInfo(want.toLocalFile()).exists())) {
            m_pendingSetup = url;
            m_places->requestSetup(idx);
            return;
        }
    }
}

void PlacesService::watchSetup(const QString &url)
{
    m_pendingSetup = url;
}

void PlacesService::refreshHomeFolders()
{
    struct Def {
        const char *name;
        const char *icon;
        QString path;
    };
    const QList<Def> defs = {
        {"Escritorio", "user-desktop", standardDir(QStandardPaths::DesktopLocation, "Escritorio")},
        {"Documentos", "folder-documents", standardDir(QStandardPaths::DocumentsLocation, "Documentos")},
        {"Descargas", "folder-download", standardDir(QStandardPaths::DownloadLocation, "Descargas")},
        {"Imágenes", "folder-images", standardDir(QStandardPaths::PicturesLocation, "Imágenes")},
        {"Música", "folder-music", standardDir(QStandardPaths::MusicLocation, "Música")},
        {"Videos", "folder-videos", standardDir(QStandardPaths::MoviesLocation, "Videos")},
        {"Plantillas", "folder-templates", standardDir(QStandardPaths::TemplatesLocation, "Plantillas")},
        {"Proyectos", "folder-code", projectsDir()},
    };
    QVariantList list;
    for (const Def &d : defs) {
        const int n = int(QDir(d.path).entryList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::System).size());
        QVariantMap m;
        m["name"] = QString::fromUtf8(d.name);
        m["icon"] = QString::fromUtf8(d.icon);
        m["path"] = d.path;
        m["countText"] = Formatters::itemCount(n);
        list.append(m);
    }
    if (list != m_homeFolders) {
        m_homeFolders = list;
        emit homeFoldersChanged();
    }
}

void PlacesService::refreshRecents()
{
    if (m_recentWatcher.isRunning())
        return;
    QStringList roots;
    for (auto loc : {QStandardPaths::DesktopLocation, QStandardPaths::DocumentsLocation, QStandardPaths::DownloadLocation,
                     QStandardPaths::PicturesLocation, QStandardPaths::MusicLocation, QStandardPaths::MoviesLocation}) {
        const QString p = QStandardPaths::writableLocation(loc);
        if (!p.isEmpty() && !roots.contains(p))
            roots << p;
    }
    roots << projectsDir();
    m_recentWatcher.setFuture(QtConcurrent::run(scanRecent, roots, 50));
}
