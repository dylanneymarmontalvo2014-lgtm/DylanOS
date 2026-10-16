#include "FileOperations.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QUrl>

namespace {

constexpr qint64 kChunk = 1 << 20;

bool pathExists(const QString &p)
{
    const QFileInfo i(p);
    return i.exists() || i.isSymLink();
}

bool removeTree(const QString &path)
{
    const QFileInfo i(path);
    if (i.isDir() && !i.isSymLink())
        return QDir(path).removeRecursively();
    return QFile::remove(path);
}

struct Ctx {
    qint64 done = 0;
    qint64 total = 0;
    const FileOperations::Progress *progress = nullptr;
    const std::atomic_bool *cancel = nullptr;

    bool cancelled() const { return cancel && cancel->load(); }
    void report() const
    {
        if (progress && *progress)
            (*progress)(done, total);
    }
};

bool copyFile(const QFileInfo &src, const QString &dst, Ctx &c, QString *err)
{
    QFile in(src.absoluteFilePath());
    if (!in.open(QIODevice::ReadOnly)) {
        *err = QStringLiteral("No se puede leer «%1» (permisos insuficientes)").arg(src.fileName());
        return false;
    }
    QFile out(dst);
    if (!out.open(QIODevice::WriteOnly | QIODevice::NewOnly)) {
        *err = QStringLiteral("No se puede escribir «%1» en el destino").arg(src.fileName());
        return false;
    }
    QByteArray buf(kChunk, Qt::Uninitialized);
    while (true) {
        if (c.cancelled()) {
            out.close();
            QFile::remove(dst);
            *err = QStringLiteral("Operación cancelada");
            return false;
        }
        const qint64 n = in.read(buf.data(), buf.size());
        if (n < 0) {
            out.close();
            QFile::remove(dst);
            *err = QStringLiteral("Error de lectura en «%1»").arg(src.fileName());
            return false;
        }
        if (n == 0)
            break;
        if (out.write(buf.constData(), n) != n) {
            out.close();
            QFile::remove(dst);
            *err = QStringLiteral("No hay espacio suficiente o error de escritura en «%1»").arg(src.fileName());
            return false;
        }
        c.done += n;
        c.report();
    }
    out.close();
    QFile::setPermissions(dst, src.permissions());
    return true;
}

bool copyEntry(const QFileInfo &src, const QString &dst, Ctx &c, QString *err)
{
    if (src.isSymLink()) {
        if (!QFile::link(src.symLinkTarget(), dst)) {
            *err = QStringLiteral("No se pudo copiar el enlace «%1»").arg(src.fileName());
            return false;
        }
        return true;
    }
    if (src.isDir()) {
        if (!QDir().mkdir(dst)) {
            *err = QStringLiteral("No se pudo crear la carpeta «%1» en el destino").arg(src.fileName());
            return false;
        }
        const auto entries = QDir(src.absoluteFilePath())
                                 .entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System,
                                                QDir::NoSort);
        for (const QFileInfo &e : entries) {
            if (c.cancelled()) {
                *err = QStringLiteral("Operación cancelada");
                return false;
            }
            if (!copyEntry(e, QDir(dst).filePath(e.fileName()), c, err))
                return false;
        }
        QFile::setPermissions(dst, src.permissions());
        return true;
    }
    return copyFile(src, dst, c, err);
}

FileOperations::Result finish(QStringList errors, FileOperations::Result r)
{
    r.ok = errors.isEmpty() && !r.cancelled;
    if (errors.size() > 3) {
        const int more = errors.size() - 3;
        errors = errors.mid(0, 3);
        errors << QStringLiteral("…y %1 errores más").arg(more);
    }
    r.error = errors.join(QLatin1Char('\n'));
    return r;
}

FileOperations::Result fail(const QString &message)
{
    FileOperations::Result r;
    r.error = message;
    return r;
}

QString readTrashInfoPath(const QString &infoFile)
{
    QFile f(infoFile);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    while (!f.atEnd()) {
        const QString line = QString::fromUtf8(f.readLine()).trimmed();
        if (line.startsWith(QLatin1String("Path=")))
            return QUrl::fromPercentEncoding(line.mid(5).toUtf8());
    }
    return {};
}

} // namespace

bool FileOperations::isValidName(const QString &name, QString *reason)
{
    auto bad = [&](const QString &why) {
        if (reason)
            *reason = why;
        return false;
    };
    if (name.trimmed().isEmpty())
        return bad(QStringLiteral("El nombre no puede estar vacío"));
    if (name == QLatin1String(".") || name == QLatin1String(".."))
        return bad(QStringLiteral("Ese nombre no es válido"));
    if (name.contains(QLatin1Char('/')) || name.contains(QChar(0)))
        return bad(QStringLiteral("El nombre no puede contener «/»"));
    if (name.toUtf8().size() > 255)
        return bad(QStringLiteral("El nombre es demasiado largo"));
    return true;
}

bool FileOperations::isProtectedPath(const QString &path)
{
    const QString p = QDir::cleanPath(QFileInfo(path).absoluteFilePath());
    if (p.isEmpty() || p == QLatin1String("/"))
        return true;
    if (QFileInfo(p).dir().absolutePath() == QLatin1String("/"))
        return true;
    if (p == QDir::cleanPath(QDir::homePath()))
        return true;
    static const QList<QStandardPaths::StandardLocation> locs = {
        QStandardPaths::DesktopLocation,   QStandardPaths::DocumentsLocation, QStandardPaths::DownloadLocation,
        QStandardPaths::PicturesLocation,  QStandardPaths::MusicLocation,     QStandardPaths::MoviesLocation,
        QStandardPaths::TempLocation, // never trash the temp root itself
    };
    for (auto loc : locs) {
        const QString l = QStandardPaths::writableLocation(loc);
        if (!l.isEmpty() && QDir::cleanPath(l) == p)
            return true;
    }
    return false;
}

QString FileOperations::uniqueName(const QString &dir, const QString &name, bool isDir)
{
    const QDir d(dir);
    if (!pathExists(d.filePath(name)))
        return name;
    QString base = name;
    QString suffix;
    if (!isDir) {
        suffix = QFileInfo(name).suffix();
        if (!suffix.isEmpty()) {
            base = name.left(name.size() - suffix.size() - 1);
            if (base.isEmpty()) { // dotfile such as ".bashrc"
                base = name;
                suffix.clear();
            }
        }
    }
    for (int i = 1;; ++i) {
        const QString tag = i == 1 ? QStringLiteral(" (copia)") : QStringLiteral(" (copia %1)").arg(i);
        const QString cand = base + tag + (suffix.isEmpty() ? QString() : QLatin1Char('.') + suffix);
        if (!pathExists(d.filePath(cand)))
            return cand;
    }
}

qint64 FileOperations::totalSize(const QStringList &paths)
{
    qint64 total = 0;
    for (const QString &p : paths) {
        const QFileInfo fi(p);
        if (fi.isSymLink())
            continue;
        if (fi.isDir()) {
            QDirIterator it(p, QDir::Files | QDir::Hidden | QDir::System | QDir::NoDotAndDotDot,
                            QDirIterator::Subdirectories);
            while (it.hasNext()) {
                it.next();
                const QFileInfo f = it.fileInfo();
                if (!f.isSymLink())
                    total += f.size();
            }
        } else {
            total += fi.size();
        }
    }
    return total;
}

FileOperations::Result FileOperations::createFolder(const QString &parentDir, const QString &name)
{
    QString why;
    if (!isValidName(name, &why))
        return fail(why);
    const QFileInfo pi(parentDir);
    if (!pi.isDir())
        return fail(QStringLiteral("La carpeta de destino no existe"));
    if (!pi.isWritable())
        return fail(QStringLiteral("No tienes permisos para crear elementos en esta carpeta"));
    const QString target = QDir(parentDir).filePath(name);
    if (pathExists(target))
        return fail(QStringLiteral("Ya existe un elemento llamado «%1»").arg(name));
    if (!QDir(parentDir).mkdir(name))
        return fail(QStringLiteral("No se pudo crear la carpeta «%1»").arg(name));
    Result r;
    r.ok = true;
    r.createdPaths << target;
    return r;
}

FileOperations::Result FileOperations::rename(const QString &path, const QString &newName)
{
    QString why;
    if (!isValidName(newName, &why))
        return fail(why);
    const QFileInfo fi(path);
    if (!pathExists(path))
        return fail(QStringLiteral("El elemento ya no existe"));
    if (isProtectedPath(path))
        return fail(QStringLiteral("«%1» es una ubicación protegida y no se puede renombrar").arg(fi.fileName()));
    Result r;
    if (fi.fileName() == newName) {
        r.ok = true;
        r.createdPaths << fi.absoluteFilePath();
        return r;
    }
    const QString target = fi.dir().filePath(newName);
    if (pathExists(target))
        return fail(QStringLiteral("Ya existe un elemento llamado «%1»").arg(newName));
    if (!QDir().rename(fi.absoluteFilePath(), target))
        return fail(QStringLiteral("No se pudo renombrar «%1» (permisos insuficientes)").arg(fi.fileName()));
    r.ok = true;
    r.createdPaths << target;
    return r;
}

FileOperations::Result FileOperations::transfer(const QStringList &sources, const QString &destDir, bool move,
                                                const Progress &progress, const std::atomic_bool *cancel)
{
    const QFileInfo dd(destDir);
    if (!dd.isDir())
        return fail(QStringLiteral("La carpeta de destino no existe"));
    if (!dd.isWritable())
        return fail(QStringLiteral("No tienes permisos de escritura en la carpeta de destino"));

    Ctx c;
    c.progress = &progress;
    c.cancel = cancel;
    QList<qint64> sizes;
    for (const QString &s : sources) {
        sizes << totalSize({s});
        c.total += sizes.last();
    }

    Result r;
    QStringList errors;
    const QString destCanon = dd.canonicalFilePath();

    for (int i = 0; i < sources.size(); ++i) {
        if (c.cancelled()) {
            r.cancelled = true;
            errors << QStringLiteral("Operación cancelada");
            break;
        }
        const QFileInfo si(sources.at(i));
        if (!pathExists(si.absoluteFilePath())) {
            errors << QStringLiteral("«%1» ya no existe").arg(si.fileName());
            continue;
        }
        if (move && isProtectedPath(si.absoluteFilePath())) {
            errors << QStringLiteral("«%1» es una ubicación protegida y no se puede mover").arg(si.fileName());
            continue;
        }
        const bool sameDir = QDir(si.absolutePath()).canonicalPath() == destCanon;
        if (move && sameDir)
            continue;
        if (si.isDir() && !si.isSymLink()) {
            const QString sc = si.canonicalFilePath();
            if (destCanon == sc || destCanon.startsWith(sc + QLatin1Char('/'))) {
                errors << QStringLiteral("No se puede copiar «%1» dentro de sí misma").arg(si.fileName());
                continue;
            }
        }

        const bool isDir = si.isDir() && !si.isSymLink();
        const QString dst = QDir(destDir).filePath(uniqueName(destDir, si.fileName(), isDir));

        if (move && QDir().rename(si.absoluteFilePath(), dst)) { // same filesystem: instant
            c.done += sizes.at(i);
            c.report();
            r.createdPaths << dst;
            continue;
        }

        QString e;
        if (!copyEntry(si, dst, c, &e)) {
            if (pathExists(dst))
                removeTree(dst);
            errors << e;
            if (c.cancelled()) {
                r.cancelled = true;
                break;
            }
            continue;
        }
        r.createdPaths << dst;
        if (move && !removeTree(si.absoluteFilePath()))
            errors << QStringLiteral("«%1» se copió, pero no se pudo eliminar el original").arg(si.fileName());
    }
    return finish(errors, r);
}

FileOperations::Result FileOperations::trash(const QStringList &paths)
{
    QStringList errors;
    Result r;
    for (const QString &p : paths) {
        const QFileInfo fi(p);
        if (!pathExists(p)) {
            errors << QStringLiteral("«%1» ya no existe").arg(fi.fileName());
            continue;
        }
        if (isProtectedPath(p)) {
            errors << QStringLiteral("«%1» es una ubicación protegida del sistema").arg(fi.fileName());
            continue;
        }
        QString inTrash;
        if (!QFile::moveToTrash(p, &inTrash))
            errors << QStringLiteral("No se pudo mover «%1» a la papelera (¿permisos insuficientes?)").arg(fi.fileName());
        else
            r.createdPaths << inTrash;
    }
    return finish(errors, r);
}

FileOperations::Result FileOperations::removePermanently(const QStringList &paths)
{
    QStringList errors;
    Result r;
    for (const QString &p : paths) {
        const QFileInfo fi(p);
        if (!pathExists(p)) {
            errors << QStringLiteral("«%1» ya no existe").arg(fi.fileName());
            continue;
        }
        if (isProtectedPath(p)) {
            errors << QStringLiteral("«%1» es una ubicación protegida del sistema").arg(fi.fileName());
            continue;
        }
        if (!removeTree(fi.absoluteFilePath()))
            errors << QStringLiteral("No se pudo eliminar «%1» (permisos insuficientes)").arg(fi.fileName());
        // Keep the trash index consistent when deleting from the trash.
        else if (QDir::cleanPath(fi.absolutePath()) == trashFilesDir())
            QFile::remove(QDir(trashInfoDir()).filePath(fi.fileName() + QStringLiteral(".trashinfo")));
    }
    return finish(errors, r);
}

QString FileOperations::trashFilesDir()
{
    return QDir::cleanPath(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
                           + QStringLiteral("/Trash/files"));
}

QString FileOperations::trashInfoDir()
{
    return QDir::cleanPath(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
                           + QStringLiteral("/Trash/info"));
}

bool FileOperations::isInTrash(const QString &path)
{
    const QString p = QDir::cleanPath(path);
    const QString t = trashFilesDir();
    return p == t || p.startsWith(t + QLatin1Char('/'));
}

FileOperations::Result FileOperations::restoreFromTrash(const QStringList &paths)
{
    QStringList errors;
    Result r;
    for (const QString &p : paths) {
        const QFileInfo fi(p);
        if (QDir::cleanPath(fi.absolutePath()) != trashFilesDir()) {
            errors << QStringLiteral("«%1» no es un elemento de primer nivel de la papelera").arg(fi.fileName());
            continue;
        }
        const QString infoFile = QDir(trashInfoDir()).filePath(fi.fileName() + QStringLiteral(".trashinfo"));
        const QString orig = readTrashInfoPath(infoFile);
        if (orig.isEmpty() || QFileInfo(orig).isRelative()) {
            errors << QStringLiteral("No se conoce la ubicación original de «%1»").arg(fi.fileName());
            continue;
        }
        const QFileInfo of(orig);
        const QString parent = of.absolutePath();
        if (!QDir().mkpath(parent)) {
            errors << QStringLiteral("No se pudo recrear la carpeta original de «%1»").arg(fi.fileName());
            continue;
        }
        const QString dst = QDir(parent).filePath(uniqueName(parent, of.fileName(), fi.isDir()));
        if (!QDir().rename(fi.absoluteFilePath(), dst)) {
            errors << QStringLiteral("No se pudo restaurar «%1»").arg(fi.fileName());
            continue;
        }
        QFile::remove(infoFile);
        r.createdPaths << dst;
    }
    return finish(errors, r);
}

FileOperations::Result FileOperations::emptyTrash()
{
    QStringList errors;
    Result r;
    const QDir files(trashFilesDir());
    const auto entries = files.entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System);
    for (const QFileInfo &e : entries) {
        if (!removeTree(e.absoluteFilePath()))
            errors << QStringLiteral("No se pudo eliminar «%1»").arg(e.fileName());
    }
    const QDir infos(trashInfoDir());
    const auto infoEntries = infos.entryInfoList(QDir::Files | QDir::Hidden | QDir::NoDotAndDotDot);
    for (const QFileInfo &e : infoEntries)
        QFile::remove(e.absoluteFilePath());
    return finish(errors, r);
}
