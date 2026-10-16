#include "ExplorerController.h"

#include "services/Formatters.h"

#include <QClipboard>
#include <QCoreApplication>
#include <QDesktopServices>
#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QMimeData>
#include <QMimeDatabase>
#include <QSettings>
#include <QUrl>
#include <QtConcurrent>

namespace {

const QString kHome = QStringLiteral("home://");

QString permissionString(QFileDevice::Permissions p)
{
    QString s;
    auto add = [&](QFileDevice::Permission perm, char c) { s += (p & perm) ? QLatin1Char(c) : QLatin1Char('-'); };
    add(QFileDevice::ReadOwner, 'r');
    add(QFileDevice::WriteOwner, 'w');
    add(QFileDevice::ExeOwner, 'x');
    add(QFileDevice::ReadGroup, 'r');
    add(QFileDevice::WriteGroup, 'w');
    add(QFileDevice::ExeGroup, 'x');
    add(QFileDevice::ReadOther, 'r');
    add(QFileDevice::WriteOther, 'w');
    add(QFileDevice::ExeOther, 'x');
    return s;
}

} // namespace

ExplorerController::ExplorerController(QObject *parent)
    : QObject(parent)
    , m_model(new FileListModel(this))
{
    const QSettings s;
    m_viewMode = qBound(0, s.value("view/mode", 0).toInt(), 3);
    m_showHidden = s.value("view/showHidden", false).toBool();
    m_confirmTrash = s.value("behavior/confirmTrash", true).toBool();
    m_serverUrl = s.value("network/serverUrl").toString();
    m_model->setShowHidden(m_showHidden);
    m_model->setSortKey(s.value("view/sortKey", 0).toInt());
    m_model->setSortAscending(s.value("view/sortAscending", true).toBool());

    connect(m_model, &FileListModel::sortChanged, this, [this] {
        QSettings st;
        st.setValue("view/sortKey", m_model->sortKey());
        st.setValue("view/sortAscending", m_model->sortAscending());
    });
    connect(&m_watcher, &QFutureWatcher<FileOperations::Result>::finished, this, &ExplorerController::onJobFinished);
    connect(QGuiApplication::clipboard(), &QClipboard::dataChanged, this, &ExplorerController::clipboardChanged);

    m_location = kHome;
    m_history << kHome;

    const QStringList args = QCoreApplication::arguments();
    if (args.size() > 1 && QFileInfo(args.at(1)).isDir())
        navigate(args.at(1));
}

ExplorerController::~ExplorerController()
{
    m_cancel = true;
    m_watcher.waitForFinished();
}

bool ExplorerController::isHome() const
{
    return m_location == kHome;
}

bool ExplorerController::inTrash() const
{
    return !isHome() && FileOperations::isInTrash(m_location);
}

QString ExplorerController::title() const
{
    if (isHome())
        return QStringLiteral("Inicio");
    if (QDir::cleanPath(m_location) == FileOperations::trashFilesDir())
        return QStringLiteral("Papelera");
    if (m_location == QLatin1String("/"))
        return QStringLiteral("Sistema de archivos");
    return QFileInfo(m_location).fileName();
}

bool ExplorerController::canGoUp() const
{
    return !isHome() && m_location != QLatin1String("/");
}

void ExplorerController::setViewMode(int mode)
{
    mode = qBound(0, mode, 3);
    if (mode == m_viewMode)
        return;
    m_viewMode = mode;
    QSettings().setValue("view/mode", mode);
    emit viewModeChanged();
}

void ExplorerController::setShowHidden(bool v)
{
    if (v == m_showHidden)
        return;
    m_showHidden = v;
    QSettings().setValue("view/showHidden", v);
    m_model->setShowHidden(v);
    emit showHiddenChanged();
}

void ExplorerController::setConfirmTrash(bool v)
{
    if (v == m_confirmTrash)
        return;
    m_confirmTrash = v;
    QSettings().setValue("behavior/confirmTrash", v);
    emit confirmTrashChanged();
}

void ExplorerController::setServerUrl(const QString &url)
{
    if (url == m_serverUrl)
        return;
    m_serverUrl = url.trimmed();
    QSettings().setValue("network/serverUrl", m_serverUrl);
    emit serverUrlChanged();
}

void ExplorerController::setSearchText(const QString &text)
{
    if (text == m_search)
        return;
    // Searching from "Inicio" searches the user's home directory.
    if (isHome() && !text.trimmed().isEmpty())
        navigateInternal(QDir::homePath(), true);
    m_search = text;
    m_model->setSearchText(text);
    emit searchTextChanged();
}

// ---------------------------------------------------------------- navigation

void ExplorerController::navigate(const QString &target)
{
    navigateInternal(target, true);
}

bool ExplorerController::navigateInternal(const QString &target, bool pushHistory)
{
    QString loc = target;
    if (loc != kHome) {
        if (loc.startsWith(QLatin1String("file://")))
            loc = QUrl(loc).toLocalFile();
        loc = QDir::cleanPath(QDir(loc).absolutePath());
        const QFileInfo fi(loc);
        if (!fi.exists()) {
            emit notify("error", QStringLiteral("La carpeta «%1» no existe").arg(fi.fileName().isEmpty() ? loc : fi.fileName()));
            return false;
        }
        if (!fi.isDir()) {
            openItem(loc);
            return false;
        }
    }
    if (pushHistory) {
        m_history = m_history.mid(0, m_pos + 1);
        if (m_history.last() != loc)
            m_history << loc;
        m_pos = int(m_history.size()) - 1;
        emit historyChanged();
    }
    setLocation(loc);
    return true;
}

void ExplorerController::setLocation(const QString &loc)
{
    if (!m_search.isEmpty()) {
        m_search.clear();
        m_model->setSearchText(QString());
        emit searchTextChanged();
    }
    m_location = loc;
    m_model->setPath(loc == kHome ? QString() : loc);
    emit locationChanged();
}

void ExplorerController::goBack()
{
    if (!canGoBack())
        return;
    const int old = m_pos;
    --m_pos;
    if (!navigateInternal(m_history.at(m_pos), false))
        m_pos = old;
    emit historyChanged();
}

void ExplorerController::goForward()
{
    if (!canGoForward())
        return;
    const int old = m_pos;
    ++m_pos;
    if (!navigateInternal(m_history.at(m_pos), false))
        m_pos = old;
    emit historyChanged();
}

void ExplorerController::goUp()
{
    if (canGoUp())
        navigateInternal(QFileInfo(m_location).dir().absolutePath(), true);
}

void ExplorerController::goHome()
{
    navigateInternal(kHome, true);
}

void ExplorerController::refresh()
{
    m_model->reload();
}

void ExplorerController::openItem(const QString &path)
{
    const QFileInfo fi(path);
    if (!fi.exists()) {
        emit notify("error", QStringLiteral("«%1» ya no existe").arg(fi.fileName()));
        return;
    }
    if (fi.isDir()) {
        if (!fi.isReadable() || !fi.isExecutable()) {
            // Still navigate: the directory page shows the permission-denied state.
        }
        navigateInternal(path, true);
        return;
    }
    if (!QDesktopServices::openUrl(QUrl::fromLocalFile(fi.absoluteFilePath())))
        emit notify("error", QStringLiteral("No hay ninguna aplicación para abrir «%1»").arg(fi.fileName()));
}

void ExplorerController::openSelection()
{
    const QStringList sel = m_model->selectedPaths();
    if (sel.size() == 1)
        openItem(sel.first());
    else
        for (const QString &p : sel)
            if (!QFileInfo(p).isDir())
                openItem(p);
}

void ExplorerController::showInFolder(const QString &path)
{
    const QFileInfo fi(path);
    navigateInternal(fi.absolutePath(), true);
    m_model->selectOnly(fi.absoluteFilePath());
}

void ExplorerController::openNetwork(const QString &kind)
{
    if (kind == QLatin1String("server")) {
        if (m_serverUrl.isEmpty()) {
            emit notify("info", QStringLiteral("Configura la dirección del Servidor DLN en Configuración"));
            return;
        }
        const QUrl url = QUrl::fromUserInput(m_serverUrl);
        if (url.isLocalFile()) {
            navigateInternal(url.toLocalFile(), true);
            return;
        }
        if (!QDesktopServices::openUrl(url))
            emit notify("error", QStringLiteral("No se pudo abrir %1").arg(m_serverUrl));
        return;
    }
    // Network browsing is delegated to the desktop's KIO/gvfs handlers.
    if (!QDesktopServices::openUrl(QUrl(QStringLiteral("remote:/"))))
        emit notify("error", QStringLiteral("No hay un explorador de red disponible en este sistema"));
}

// ----------------------------------------------------------------- clipboard

bool ExplorerController::canPaste() const
{
    bool cut = false;
    return !clipboardPaths(&cut).isEmpty();
}

QStringList ExplorerController::clipboardPaths(bool *cut) const
{
    QStringList out;
    const QMimeData *md = QGuiApplication::clipboard()->mimeData();
    if (!md || !md->hasUrls())
        return out;
    for (const QUrl &u : md->urls())
        if (u.isLocalFile())
            out << u.toLocalFile();
    *cut = md->data(QStringLiteral("application/x-kde-cutselection")) == "1";
    return out;
}

void ExplorerController::setClipboard(bool cut)
{
    const QStringList sel = selectionOrNotify(QStringLiteral("Selecciona al menos un elemento"));
    if (sel.isEmpty())
        return;
    QList<QUrl> urls;
    QByteArray gnome = cut ? "cut" : "copy";
    for (const QString &p : sel) {
        const QUrl u = QUrl::fromLocalFile(p);
        urls << u;
        gnome += "\n" + u.toEncoded();
    }
    auto *md = new QMimeData;
    md->setUrls(urls);
    md->setText(sel.join(QLatin1Char('\n')));
    md->setData(QStringLiteral("application/x-kde-cutselection"), cut ? "1" : "0");
    md->setData(QStringLiteral("x-special/gnome-copied-files"), gnome);
    QGuiApplication::clipboard()->setMimeData(md);
    emit notify("info", cut ? QStringLiteral("%1 elemento(s) cortado(s)").arg(sel.size())
                            : QStringLiteral("%1 elemento(s) copiado(s)").arg(sel.size()));
}

void ExplorerController::copySelection()
{
    setClipboard(false);
}

void ExplorerController::cutSelection()
{
    if (inTrash()) {
        emit notify("error", QStringLiteral("No se puede cortar desde la papelera; usa Restaurar"));
        return;
    }
    setClipboard(true);
}

QStringList ExplorerController::selectionOrNotify(const QString &emptyMessage)
{
    const QStringList sel = m_model->selectedPaths();
    if (sel.isEmpty())
        emit notify("info", emptyMessage);
    return sel;
}

// --------------------------------------------------------------------- jobs

void ExplorerController::runJob(const QString &label, JobFn job, DoneFn done)
{
    if (m_busy) {
        emit notify("error", QStringLiteral("Hay otra operación en curso"));
        return;
    }
    m_cancel = false;
    m_busy = true;
    m_progress = -1;
    m_progressText = label;
    m_onDone = std::move(done);
    emit busyChanged();
    emit progressChanged();

    FileOperations::Progress cb = [this](qint64 done, qint64 total) {
        QMetaObject::invokeMethod(
            this,
            [this, done, total] {
                m_progress = total > 0 ? double(done) / double(total) : -1;
                emit progressChanged();
            },
            Qt::QueuedConnection);
    };
    m_watcher.setFuture(QtConcurrent::run([job = std::move(job), cb, this] { return job(cb, &m_cancel); }));
}

void ExplorerController::onJobFinished()
{
    const FileOperations::Result r = m_watcher.result();
    m_busy = false;
    m_progress = 0;
    emit busyChanged();
    emit progressChanged();
    m_model->reload();
    auto done = std::move(m_onDone);
    m_onDone = nullptr;
    if (done)
        done(r);
}

void ExplorerController::cancelOperation()
{
    m_cancel = true;
}

void ExplorerController::paste()
{
    if (isHome()) {
        emit notify("info", QStringLiteral("Abre una carpeta para pegar los elementos"));
        return;
    }
    if (inTrash()) {
        emit notify("error", QStringLiteral("No se puede pegar dentro de la papelera"));
        return;
    }
    bool cut = false;
    const QStringList sources = clipboardPaths(&cut);
    if (sources.isEmpty()) {
        emit notify("info", QStringLiteral("El portapapeles no contiene archivos"));
        return;
    }
    const QString dest = m_location;
    runJob(cut ? QStringLiteral("Moviendo elementos…") : QStringLiteral("Copiando elementos…"),
           [=](const FileOperations::Progress &p, const std::atomic_bool *c) {
               return FileOperations::transfer(sources, dest, cut, p, c);
           },
           [this, cut, n = sources.size()](const FileOperations::Result &r) {
               if (r.ok) {
                   if (cut)
                       QGuiApplication::clipboard()->clear();
                   emit notify("success", cut ? QStringLiteral("%1 elemento(s) movido(s)").arg(n)
                                              : QStringLiteral("%1 elemento(s) copiado(s)").arg(n));
               } else if (r.cancelled) {
                   emit notify("info", QStringLiteral("Operación cancelada"));
               } else {
                   emit notify("error", r.error);
               }
           });
}

void ExplorerController::createFolder(const QString &name)
{
    if (isHome() || inTrash()) {
        emit notify("error", QStringLiteral("No se pueden crear carpetas aquí"));
        return;
    }
    const auto r = FileOperations::createFolder(m_location, name);
    if (!r.ok) {
        emit notify("error", r.error);
        return;
    }
    m_model->reload();
    m_model->selectOnly(r.createdPaths.value(0));
    emit notify("success", QStringLiteral("Carpeta «%1» creada").arg(name));
}

void ExplorerController::renameItem(const QString &path, const QString &newName)
{
    const auto r = FileOperations::rename(path, newName);
    if (!r.ok) {
        emit notify("error", r.error);
        return;
    }
    m_model->reload();
    m_model->selectOnly(r.createdPaths.value(0));
    emit notify("success", QStringLiteral("Renombrado a «%1»").arg(newName));
}

void ExplorerController::trashSelection()
{
    const QStringList sel = selectionOrNotify(QStringLiteral("Selecciona al menos un elemento"));
    if (sel.isEmpty())
        return;
    runJob(QStringLiteral("Moviendo a la papelera…"),
           [sel](const FileOperations::Progress &, const std::atomic_bool *) { return FileOperations::trash(sel); },
           [this, n = sel.size()](const FileOperations::Result &r) {
               if (r.ok)
                   emit notify("success", QStringLiteral("%1 elemento(s) movido(s) a la papelera").arg(n));
               else
                   emit notify("error", r.error);
           });
}

void ExplorerController::deleteSelection()
{
    const QStringList sel = selectionOrNotify(QStringLiteral("Selecciona al menos un elemento"));
    if (sel.isEmpty())
        return;
    runJob(QStringLiteral("Eliminando…"),
           [sel](const FileOperations::Progress &, const std::atomic_bool *) { return FileOperations::removePermanently(sel); },
           [this, n = sel.size()](const FileOperations::Result &r) {
               if (r.ok)
                   emit notify("success", QStringLiteral("%1 elemento(s) eliminado(s) permanentemente").arg(n));
               else
                   emit notify("error", r.error);
           });
}

void ExplorerController::restoreSelection()
{
    const QStringList sel = selectionOrNotify(QStringLiteral("Selecciona al menos un elemento"));
    if (sel.isEmpty())
        return;
    const auto r = FileOperations::restoreFromTrash(sel);
    m_model->reload();
    if (r.ok)
        emit notify("success", QStringLiteral("%1 elemento(s) restaurado(s)").arg(sel.size()));
    else
        emit notify("error", r.error);
}

void ExplorerController::emptyTrash()
{
    runJob(QStringLiteral("Vaciando la papelera…"),
           [](const FileOperations::Progress &, const std::atomic_bool *) { return FileOperations::emptyTrash(); },
           [this](const FileOperations::Result &r) {
               if (r.ok)
                   emit notify("success", QStringLiteral("La papelera está vacía"));
               else
                   emit notify("error", r.error);
           });
}

// --------------------------------------------------------------- properties

QVariantMap ExplorerController::properties(const QString &path) const
{
    const QFileInfo fi(path);
    QVariantMap m;
    if (!fi.exists() && !fi.isSymLink()) {
        m["error"] = QStringLiteral("El elemento ya no existe");
        return m;
    }
    static const QMimeDatabase db;
    const QMimeType mime = db.mimeTypeForFile(fi);
    const bool isDir = fi.isDir();
    const QLocale loc = QLocale::system();
    auto when = [&](const QDateTime &dt) { return dt.isValid() ? loc.toString(dt, QLocale::LongFormat) : QStringLiteral("—"); };

    m["name"] = fi.fileName().isEmpty() ? QStringLiteral("/") : fi.fileName();
    m["path"] = fi.absoluteFilePath();
    m["parent"] = fi.absolutePath();
    m["isDir"] = isDir;
    m["suffix"] = isDir ? QString() : fi.suffix().toLower();
    m["kind"] = isDir ? QStringLiteral("Carpeta") : mime.comment();
    m["mime"] = mime.name();
    m["size"] = isDir ? qint64(-1) : fi.size();
    m["sizeText"] = isDir ? QString() : QStringLiteral("%1 (%2 bytes)").arg(Formatters::fileSize(fi.size()), loc.toString(fi.size()));
    m["itemCount"] = isDir ? int(QDir(path).entryList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System).size()) : -1;
    m["created"] = when(fi.birthTime());
    m["modified"] = when(fi.lastModified());
    m["accessed"] = when(fi.lastRead());
    m["owner"] = fi.owner();
    m["group"] = fi.group();
    m["permissions"] = permissionString(fi.permissions());
    m["readable"] = fi.isReadable();
    m["writable"] = fi.isWritable();
    m["hidden"] = fi.isHidden();
    m["symlinkTarget"] = fi.isSymLink() ? fi.symLinkTarget() : QString();
    return m;
}

int ExplorerController::requestSize(const QStringList &paths)
{
    const int token = ++m_sizeToken;
    auto *w = new QFutureWatcher<qint64>(this);
    connect(w, &QFutureWatcher<qint64>::finished, this, [this, w, token] {
        emit sizeComputed(token, w->result());
        w->deleteLater();
    });
    w->setFuture(QtConcurrent::run([paths] { return FileOperations::totalSize(paths); }));
    return token;
}
