#pragma once

#include <QString>
#include <QStringList>

#include <atomic>
#include <functional>

// Real file-system operations. Pure Qt Core, no QObject, safe to run on worker
// threads. Paths are always handled as QString/QFileInfo/QDir — never through a
// shell — so spaces, Unicode and hidden names need no escaping.
class FileOperations
{
public:
    struct Result {
        bool ok = false;
        bool cancelled = false;
        QString error;            // human readable (Spanish), may contain several lines
        QStringList createdPaths; // destination paths created/renamed/restored
    };

    using Progress = std::function<void(qint64 done, qint64 total)>;

    static bool isValidName(const QString &name, QString *reason = nullptr);
    // "/", $HOME, top-level system dirs and the XDG user folders cannot be
    // deleted, trashed, renamed or moved.
    static bool isProtectedPath(const QString &path);
    // "a.txt" -> "a (copia).txt" -> "a (copia 2).txt" when the name is taken.
    static QString uniqueName(const QString &dir, const QString &name, bool isDir = false);
    static qint64 totalSize(const QStringList &paths);

    static Result createFolder(const QString &parentDir, const QString &name);
    static Result rename(const QString &path, const QString &newName);
    static Result transfer(const QStringList &sources, const QString &destDir, bool move,
                           const Progress &progress = {}, const std::atomic_bool *cancel = nullptr);
    static Result trash(const QStringList &paths);
    static Result removePermanently(const QStringList &paths);

    static QString trashFilesDir();
    static QString trashInfoDir();
    static bool isInTrash(const QString &path);
    static Result restoreFromTrash(const QStringList &paths);
    static Result emptyTrash();
};
