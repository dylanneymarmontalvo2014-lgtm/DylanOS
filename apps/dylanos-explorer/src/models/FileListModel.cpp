#include "FileListModel.h"

#include "services/Formatters.h"

#include <QDir>
#include <QDirIterator>
#include <QElapsedTimer>
#include <QFileInfo>
#include <QMimeDatabase>

#include <algorithm>

namespace {
constexpr int kMaxSearchResults = 5000;
constexpr int kSearchBudgetMs = 600;
} // namespace

FileListModel::FileListModel(QObject *parent)
    : QAbstractListModel(parent)
{
    m_collator.setNumericMode(true);
    m_collator.setCaseSensitivity(Qt::CaseInsensitive);

    m_reloadTimer.setSingleShot(true);
    m_reloadTimer.setInterval(200);
    connect(&m_reloadTimer, &QTimer::timeout, this, &FileListModel::reload);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] { m_reloadTimer.start(); });
}

int FileListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(m_entries.size());
}

QHash<int, QByteArray> FileListModel::roleNames() const
{
    return {
        {NameRole, "name"},
        {PathRole, "path"},
        {IsDirRole, "isDir"},
        {SizeRole, "size"},
        {SizeTextRole, "sizeText"},
        {ModifiedRole, "modified"},
        {ModifiedTextRole, "modifiedText"},
        {SuffixRole, "suffix"},
        {HiddenRole, "hidden"},
        {SelectedRole, "selected"},
        {ItemCountRole, "itemCount"},
        {LocationRole, "location"},
        {KindRole, "kind"},
        {ReadableRole, "readable"},
        {SymlinkRole, "symlink"},
    };
}

QVariant FileListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_entries.size())
        return {};
    const Entry &e = m_entries.at(index.row());
    switch (role) {
    case NameRole:
        return e.name;
    case PathRole:
        return e.path;
    case IsDirRole:
        return e.isDir;
    case SizeRole:
        return e.size;
    case SizeTextRole:
        return e.isDir ? QStringLiteral("—") : Formatters::fileSize(e.size);
    case ModifiedRole:
        return e.modified;
    case ModifiedTextRole:
        return Formatters::modified(e.modified);
    case SuffixRole:
        return e.suffix;
    case HiddenRole:
        return e.hidden;
    case SelectedRole:
        return m_selected.contains(e.path);
    case LocationRole:
        return e.location;
    case ReadableRole:
        return e.readable;
    case SymlinkRole:
        return e.symlink;
    case KindRole: {
        if (e.isDir)
            return QStringLiteral("Carpeta");
        static const QMimeDatabase db;
        return db.mimeTypeForFile(e.path, QMimeDatabase::MatchExtension).comment();
    }
    case ItemCountRole: {
        if (!e.isDir)
            return -1;
        auto it = m_countCache.constFind(e.path);
        if (it != m_countCache.constEnd())
            return it.value();
        QDir::Filters f = QDir::AllEntries | QDir::NoDotAndDotDot | QDir::System;
        if (m_showHidden)
            f |= QDir::Hidden;
        const int n = int(QDir(e.path).entryList(f).size());
        m_countCache.insert(e.path, n);
        return n;
    }
    default:
        return {};
    }
}

void FileListModel::setPath(const QString &path)
{
    const QString clean = path.isEmpty() ? QString() : QDir::cleanPath(path);
    if (clean == m_path)
        return;
    const auto watched = m_watcher.directories();
    if (!watched.isEmpty())
        m_watcher.removePaths(watched);
    m_path = clean;
    m_selected.clear();
    m_anchor = -1;
    if (!m_path.isEmpty())
        m_watcher.addPath(m_path);
    emit pathChanged();
    reload();
    emit selectionChanged();
}

void FileListModel::setShowHidden(bool v)
{
    if (v == m_showHidden)
        return;
    m_showHidden = v;
    emit showHiddenChanged();
    reload();
}

void FileListModel::setSearchText(const QString &text)
{
    if (text == m_search)
        return;
    m_search = text;
    emit searchTextChanged();
    reload();
}

void FileListModel::setSortKey(int key)
{
    if (key == m_sortKey)
        return;
    m_sortKey = key;
    emit sortChanged();
    reload();
}

void FileListModel::setSortAscending(bool asc)
{
    if (asc == m_ascending)
        return;
    m_ascending = asc;
    emit sortChanged();
    reload();
}

FileListModel::Entry FileListModel::makeEntry(const QFileInfo &fi)
{
    Entry e;
    e.name = fi.fileName();
    e.path = fi.absoluteFilePath();
    e.symlink = fi.isSymLink();
    e.isDir = fi.isDir();
    e.hidden = fi.isHidden();
    e.readable = fi.isReadable();
    e.size = e.isDir ? 0 : fi.size();
    e.modified = fi.lastModified();
    e.suffix = e.isDir ? QString() : fi.suffix().toLower();
    return e;
}

void FileListModel::sortEntries(QVector<Entry> &entries) const
{
    std::stable_sort(entries.begin(), entries.end(), [this](const Entry &a, const Entry &b) {
        if (a.isDir != b.isDir)
            return a.isDir;
        int r = 0;
        switch (m_sortKey) {
        case 1:
            r = a.size < b.size ? -1 : (a.size > b.size ? 1 : 0);
            break;
        case 2:
            r = a.modified < b.modified ? -1 : (a.modified > b.modified ? 1 : 0);
            break;
        case 3:
            r = m_collator.compare(a.suffix, b.suffix);
            break;
        default:
            r = m_collator.compare(a.name, b.name);
        }
        if (!m_ascending)
            r = -r;
        if (r == 0)
            r = m_collator.compare(a.name, b.name);
        return r < 0;
    });
}

void FileListModel::reload()
{
    QVector<Entry> entries;
    QString errorKind;
    bool truncated = false;

    if (!m_path.isEmpty()) {
        const QFileInfo di(m_path);
        if (!di.exists()) {
            errorKind = QStringLiteral("missing");
        } else if (!di.isDir()) {
            errorKind = QStringLiteral("notdir");
        } else if (!di.isReadable() || !di.isExecutable()) {
            errorKind = QStringLiteral("permission");
        } else {
            QDir::Filters f = QDir::AllEntries | QDir::NoDotAndDotDot | QDir::System;
            if (m_showHidden)
                f |= QDir::Hidden;
            const QString needle = m_search.trimmed();
            if (needle.isEmpty()) {
                const auto list = QDir(m_path).entryInfoList(f, QDir::NoSort);
                entries.reserve(int(list.size()));
                for (const QFileInfo &fi : list)
                    entries.append(makeEntry(fi));
            } else {
                const QDir base(m_path);
                QDirIterator it(m_path, f, QDirIterator::Subdirectories);
                QElapsedTimer timer;
                timer.start();
                while (it.hasNext()) {
                    it.next();
                    const QFileInfo fi = it.fileInfo();
                    if (fi.fileName().contains(needle, Qt::CaseInsensitive)) {
                        Entry e = makeEntry(fi);
                        const QString rel = base.relativeFilePath(fi.absolutePath());
                        e.location = rel == QLatin1String(".") ? QString() : rel;
                        entries.append(e);
                    }
                    if (entries.size() >= kMaxSearchResults || timer.elapsed() > kSearchBudgetMs) {
                        truncated = true;
                        break;
                    }
                }
            }
            sortEntries(entries);
        }
    }

    beginResetModel();
    m_entries = entries;
    m_countCache.clear();
    m_errorKind = errorKind;
    m_truncated = truncated;
    QSet<QString> keep;
    for (const Entry &e : std::as_const(m_entries))
        if (m_selected.contains(e.path))
            keep.insert(e.path);
    const bool selectionShrank = keep.size() != m_selected.size();
    m_selected = keep;
    m_anchor = -1;
    endResetModel();

    emit loaded();
    if (selectionShrank)
        emit selectionChanged();
}

void FileListModel::notifySelection()
{
    if (!m_entries.isEmpty())
        emit dataChanged(index(0), index(int(m_entries.size()) - 1), {SelectedRole});
    emit selectionChanged();
}

void FileListModel::select(int row, bool additive, bool range)
{
    if (row < 0 || row >= m_entries.size())
        return;
    const QString p = m_entries.at(row).path;
    if (range && m_anchor >= 0 && m_anchor < m_entries.size()) {
        if (!additive)
            m_selected.clear();
        const int a = qMin(m_anchor, row);
        const int b = qMax(m_anchor, row);
        for (int i = a; i <= b; ++i)
            m_selected.insert(m_entries.at(i).path);
    } else if (additive) {
        if (!m_selected.remove(p))
            m_selected.insert(p);
        m_anchor = row;
    } else {
        m_selected.clear();
        m_selected.insert(p);
        m_anchor = row;
    }
    notifySelection();
}

void FileListModel::selectOnly(const QString &path)
{
    m_selected.clear();
    m_anchor = -1;
    for (int i = 0; i < m_entries.size(); ++i) {
        if (m_entries.at(i).path == path) {
            m_selected.insert(path);
            m_anchor = i;
            break;
        }
    }
    notifySelection();
}

void FileListModel::selectAll()
{
    m_selected.clear();
    for (const Entry &e : std::as_const(m_entries))
        m_selected.insert(e.path);
    notifySelection();
}

void FileListModel::clearSelection()
{
    if (m_selected.isEmpty())
        return;
    m_selected.clear();
    m_anchor = -1;
    notifySelection();
}

bool FileListModel::isSelected(int row) const
{
    return row >= 0 && row < m_entries.size() && m_selected.contains(m_entries.at(row).path);
}

QStringList FileListModel::selectedPaths() const
{
    QStringList out;
    for (const Entry &e : m_entries)
        if (m_selected.contains(e.path))
            out << e.path;
    return out;
}

QString FileListModel::pathAt(int row) const
{
    return row >= 0 && row < m_entries.size() ? m_entries.at(row).path : QString();
}

bool FileListModel::isDirAt(int row) const
{
    return row >= 0 && row < m_entries.size() && m_entries.at(row).isDir;
}
