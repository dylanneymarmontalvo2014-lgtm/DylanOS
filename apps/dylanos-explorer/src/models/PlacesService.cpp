#include "PlacesService.h"

#include "services/FileOperations.h"
#include "services/Formatters.h"

#include <QDir>
#include <QFileInfo>
#include <QSet>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QtConcurrent>

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

PlacesService::PlacesService(QObject *parent)
    : QObject(parent)
{
    auto fav = [this](const QString &name, const QString &icon, const QString &path) {
        m_favorites.append(QVariantMap{{"name", name}, {"icon", icon}, {"path", path}});
    };
    fav(QStringLiteral("Inicio"), QStringLiteral("home"), QStringLiteral("home://"));
    fav(QStringLiteral("Escritorio"), QStringLiteral("desktop"), standardDir(QStandardPaths::DesktopLocation, "Escritorio"));
    fav(QStringLiteral("Documentos"), QStringLiteral("doc"), standardDir(QStandardPaths::DocumentsLocation, "Documentos"));
    fav(QStringLiteral("Descargas"), QStringLiteral("download"), standardDir(QStandardPaths::DownloadLocation, "Descargas"));
    fav(QStringLiteral("Imágenes"), QStringLiteral("image"), standardDir(QStandardPaths::PicturesLocation, "Imágenes"));
    fav(QStringLiteral("Música"), QStringLiteral("music"), standardDir(QStandardPaths::MusicLocation, "Música"));
    fav(QStringLiteral("Videos"), QStringLiteral("video"), standardDir(QStandardPaths::MoviesLocation, "Videos"));
    fav(QStringLiteral("Papelera"), QStringLiteral("trash"), FileOperations::trashFilesDir());

    m_network.append(QVariantMap{{"name", QStringLiteral("Red local")}, {"icon", QStringLiteral("desktop")}, {"kind", QStringLiteral("local")}});
    m_network.append(QVariantMap{{"name", QStringLiteral("Servidor DLN")}, {"icon", QStringLiteral("server")}, {"kind", QStringLiteral("server")}});

    connect(&m_recentWatcher, &QFutureWatcher<QVariantList>::finished, this, [this] {
        m_recent = m_recentWatcher.result();
        emit recentFilesChanged();
    });
    m_deviceTimer.setInterval(10000);
    connect(&m_deviceTimer, &QTimer::timeout, this, &PlacesService::refreshDevices);
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
    QVariantList list;
    QSet<QByteArray> seen;
    const auto volumes = QStorageInfo::mountedVolumes();
    for (const QStorageInfo &s : volumes) {
        if (!s.isValid() || !s.isReady())
            continue;
        const QString mp = s.rootPath();
        if (!s.isRoot()) {
            const QByteArray dev = s.device();
            if (!dev.startsWith("/dev/") || seen.contains(dev))
                continue;
            static const QStringList skip = {"/boot", "/snap", "/var/lib", "/sys", "/proc", "/dev"};
            bool hidden = false;
            for (const QString &pre : skip)
                if (mp == pre || mp.startsWith(pre + QLatin1Char('/')))
                    hidden = true;
            if (hidden)
                continue;
        }
        seen.insert(s.device());
        QString name = s.isRoot() ? QStringLiteral("DylanOS") : s.name();
        if (name.isEmpty())
            name = QFileInfo(mp).fileName();
        const qint64 total = s.bytesTotal();
        const qint64 avail = s.bytesAvailable();
        QVariantMap m;
        m["name"] = name;
        m["path"] = mp;
        m["usedFraction"] = total > 0 ? 1.0 - double(avail) / double(total) : 0.0;
        m["text"] = QStringLiteral("%1 disponibles de %2").arg(Formatters::capacity(avail), Formatters::capacity(total));
        list.append(m);
    }
    if (list != m_devices) {
        m_devices = list;
        emit devicesChanged();
    }
}

void PlacesService::refreshHomeFolders()
{
    struct Def {
        const char *name;
        const char *icon;
        QString path;
    };
    const QList<Def> defs = {
        {"Escritorio", "desktop", standardDir(QStandardPaths::DesktopLocation, "Escritorio")},
        {"Documentos", "doc", standardDir(QStandardPaths::DocumentsLocation, "Documentos")},
        {"Descargas", "download", standardDir(QStandardPaths::DownloadLocation, "Descargas")},
        {"Imágenes", "image", standardDir(QStandardPaths::PicturesLocation, "Imágenes")},
        {"Música", "music", standardDir(QStandardPaths::MusicLocation, "Música")},
        {"Videos", "film", standardDir(QStandardPaths::MoviesLocation, "Videos")},
        {"Plantillas", "grid", standardDir(QStandardPaths::TemplatesLocation, "Plantillas")},
        {"Proyectos", "code", projectsDir()},
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
