#pragma once

#include <QFileInfo>
#include <QAbstractListModel>
#include <QCollator>
#include <QDateTime>
#include <QFileSystemWatcher>
#include <QHash>
#include <QSet>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

// Lists one directory (or a recursive name search below it), with sorting,
// hidden-file filtering, multi-selection and live refresh via QFileSystemWatcher.
class FileListModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("FileListModel is owned by ExplorerController")

    Q_PROPERTY(QString path READ path WRITE setPath NOTIFY pathChanged)
    Q_PROPERTY(bool showHidden READ showHidden WRITE setShowHidden NOTIFY showHiddenChanged)
    Q_PROPERTY(QString searchText READ searchText WRITE setSearchText NOTIFY searchTextChanged)
    // 0 = name, 1 = size, 2 = modified, 3 = type
    Q_PROPERTY(int sortKey READ sortKey WRITE setSortKey NOTIFY sortChanged)
    Q_PROPERTY(bool sortAscending READ sortAscending WRITE setSortAscending NOTIFY sortChanged)
    // "", "missing", "notdir" or "permission"
    Q_PROPERTY(QString errorKind READ errorKind NOTIFY loaded)
    Q_PROPERTY(bool truncated READ truncated NOTIFY loaded)
    Q_PROPERTY(int count READ count NOTIFY loaded)
    Q_PROPERTY(int selectedCount READ selectedCount NOTIFY selectionChanged)

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        PathRole,
        IsDirRole,
        SizeRole,
        SizeTextRole,
        ModifiedRole,
        ModifiedTextRole,
        SuffixRole,
        HiddenRole,
        SelectedRole,
        ItemCountRole,
        LocationRole,
        KindRole,
        ReadableRole,
        SymlinkRole,
    };

    explicit FileListModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString path() const { return m_path; }
    void setPath(const QString &path);
    bool showHidden() const { return m_showHidden; }
    void setShowHidden(bool v);
    QString searchText() const { return m_search; }
    void setSearchText(const QString &text);
    int sortKey() const { return m_sortKey; }
    void setSortKey(int key);
    bool sortAscending() const { return m_ascending; }
    void setSortAscending(bool asc);
    QString errorKind() const { return m_errorKind; }
    bool truncated() const { return m_truncated; }
    int count() const { return int(m_entries.size()); }
    int selectedCount() const { return int(m_selected.size()); }

    Q_INVOKABLE void reload();
    Q_INVOKABLE void select(int row, bool additive, bool range);
    Q_INVOKABLE void selectOnly(const QString &path);
    Q_INVOKABLE void selectAll();
    Q_INVOKABLE void clearSelection();
    Q_INVOKABLE bool isSelected(int row) const;
    Q_INVOKABLE QStringList selectedPaths() const;
    Q_INVOKABLE QString pathAt(int row) const;
    Q_INVOKABLE bool isDirAt(int row) const;

signals:
    void pathChanged();
    void showHiddenChanged();
    void searchTextChanged();
    void sortChanged();
    void loaded();
    void selectionChanged();

private:
    struct Entry {
        QString name;
        QString path;
        QString suffix;
        QString location; // relative parent, only meaningful for search results
        bool isDir = false;
        bool hidden = false;
        bool readable = true;
        bool symlink = false;
        qint64 size = 0;
        QDateTime modified;
    };

    static Entry makeEntry(const QFileInfo &fi);
    void sortEntries(QVector<Entry> &entries) const;
    void notifySelection();

    QVector<Entry> m_entries;
    QSet<QString> m_selected;
    int m_anchor = -1;

    QString m_path;
    QString m_search;
    QString m_errorKind;
    bool m_showHidden = false;
    bool m_truncated = false;
    int m_sortKey = 0;
    bool m_ascending = true;

    QCollator m_collator;
    QFileSystemWatcher m_watcher;
    QTimer m_reloadTimer;
    mutable QHash<QString, int> m_countCache;
};
