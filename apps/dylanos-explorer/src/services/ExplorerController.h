#pragma once

#include "models/FileListModel.h"
#include "services/FileOperations.h"

#include <QFutureWatcher>
#include <QObject>
#include <QStringList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

#include <atomic>
#include <functional>

// QML-facing application controller: navigation history, view settings,
// clipboard (shared with other file managers through the system clipboard),
// background jobs with progress/cancel, and user notifications.
class ExplorerController : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(FileListModel *model READ model CONSTANT)
    Q_PROPERTY(QString location READ location NOTIFY locationChanged)
    Q_PROPERTY(bool isHome READ isHome NOTIFY locationChanged)
    Q_PROPERTY(bool inTrash READ inTrash NOTIFY locationChanged)
    Q_PROPERTY(QString title READ title NOTIFY locationChanged)
    Q_PROPERTY(bool canGoBack READ canGoBack NOTIFY historyChanged)
    Q_PROPERTY(bool canGoForward READ canGoForward NOTIFY historyChanged)
    Q_PROPERTY(bool canGoUp READ canGoUp NOTIFY locationChanged)
    // 0 grid, 1 list, 2 columns, 3 grid + preview panel
    Q_PROPERTY(int viewMode READ viewMode WRITE setViewMode NOTIFY viewModeChanged)
    Q_PROPERTY(bool showHidden READ showHidden WRITE setShowHidden NOTIFY showHiddenChanged)
    Q_PROPERTY(bool confirmTrash READ confirmTrash WRITE setConfirmTrash NOTIFY confirmTrashChanged)
    Q_PROPERTY(QString serverUrl READ serverUrl WRITE setServerUrl NOTIFY serverUrlChanged)
    Q_PROPERTY(QString searchText READ searchText WRITE setSearchText NOTIFY searchTextChanged)
    Q_PROPERTY(bool canPaste READ canPaste NOTIFY clipboardChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(double progress READ progress NOTIFY progressChanged) // -1 = indeterminate
    Q_PROPERTY(QString progressText READ progressText NOTIFY busyChanged)

public:
    explicit ExplorerController(QObject *parent = nullptr);
    ~ExplorerController() override;

    FileListModel *model() const { return m_model; }
    QString location() const { return m_location; }
    bool isHome() const;
    bool inTrash() const;
    QString title() const;
    bool canGoBack() const { return m_pos > 0; }
    bool canGoForward() const { return m_pos + 1 < m_history.size(); }
    bool canGoUp() const;
    int viewMode() const { return m_viewMode; }
    void setViewMode(int mode);
    bool showHidden() const { return m_showHidden; }
    void setShowHidden(bool v);
    bool confirmTrash() const { return m_confirmTrash; }
    void setConfirmTrash(bool v);
    QString serverUrl() const { return m_serverUrl; }
    void setServerUrl(const QString &url);
    QString searchText() const { return m_search; }
    void setSearchText(const QString &text);
    bool canPaste() const;
    bool busy() const { return m_busy; }
    double progress() const { return m_progress; }
    QString progressText() const { return m_progressText; }

    // navigation
    Q_INVOKABLE void navigate(const QString &target);
    Q_INVOKABLE void goBack();
    Q_INVOKABLE void goForward();
    Q_INVOKABLE void goUp();
    Q_INVOKABLE void goHome();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void openItem(const QString &path);
    Q_INVOKABLE void openSelection();
    Q_INVOKABLE void showInFolder(const QString &path);
    Q_INVOKABLE void openNetwork(const QString &kind);

    // operations on the current selection / folder
    Q_INVOKABLE void copySelection();
    Q_INVOKABLE void cutSelection();
    Q_INVOKABLE void paste();
    Q_INVOKABLE void createFolder(const QString &name);
    Q_INVOKABLE void renameItem(const QString &path, const QString &newName);
    Q_INVOKABLE void trashSelection();
    Q_INVOKABLE void deleteSelection();
    Q_INVOKABLE void restoreSelection();
    Q_INVOKABLE void emptyTrash();
    Q_INVOKABLE void cancelOperation();

    // properties dialog
    Q_INVOKABLE QVariantMap properties(const QString &path) const;
    Q_INVOKABLE int requestSize(const QStringList &paths);

signals:
    void locationChanged();
    void historyChanged();
    void viewModeChanged();
    void showHiddenChanged();
    void confirmTrashChanged();
    void serverUrlChanged();
    void searchTextChanged();
    void clipboardChanged();
    void busyChanged();
    void progressChanged();
    void notify(const QString &kind, const QString &message); // kind: success | error | info
    void sizeComputed(int token, qint64 bytes);

private:
    using JobFn = std::function<FileOperations::Result(const FileOperations::Progress &, const std::atomic_bool *)>;
    using DoneFn = std::function<void(const FileOperations::Result &)>;

    bool navigateInternal(const QString &target, bool pushHistory);
    void setLocation(const QString &loc);
    void runJob(const QString &label, JobFn job, DoneFn done);
    void onJobFinished();
    void setClipboard(bool cut);
    QStringList selectionOrNotify(const QString &emptyMessage);
    QStringList clipboardPaths(bool *cut) const;

    FileListModel *m_model;
    QString m_location;
    QStringList m_history;
    int m_pos = 0;

    int m_viewMode = 0;
    bool m_showHidden = false;
    bool m_confirmTrash = true;
    QString m_serverUrl;
    QString m_search;

    bool m_busy = false;
    double m_progress = 0;
    QString m_progressText;
    std::atomic_bool m_cancel{false};
    QFutureWatcher<FileOperations::Result> m_watcher;
    DoneFn m_onDone;
    int m_sizeToken = 0;
};
