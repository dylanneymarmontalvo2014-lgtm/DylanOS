#include "DylanIcon.h"

#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QIcon>
#include <QPainter>
#include <QTimer>
#include <QQuickWindow>
#include <QSettings>

namespace {
// La clave del tema de iconos vive en kdeglobals: [Icons] Theme.
QString currentIconThemeName()
{
    QSettings settings(QDir::homePath() + QStringLiteral("/.config/kdeglobals"),
                       QSettings::IniFormat);
    return settings.value(QStringLiteral("Icons/Theme")).toString();
}
} // namespace

// Vigila kdeglobals y notifica los cambios de tema de iconos: los items
// DylanIcon se repintan sin reiniciar la aplicación, como el resto del
// escritorio. Reutiliza el patrón de SystemService (DylanOS Configuration)
// frente a reescrituras atómicas de plasma.
DylanIconTheme::DylanIconTheme()
{
    m_themeName = currentIconThemeName();
    if (!m_themeName.isEmpty())
        QIcon::setThemeName(m_themeName);
    const QString configDir = QDir::homePath() + QStringLiteral("/.config");
    const QString configPath = configDir + QStringLiteral("/kdeglobals");
    m_watcher.addPath(configDir);
    m_watcher.addPath(configPath);
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &DylanIconTheme::refresh);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &DylanIconTheme::refresh);
}

DylanIconTheme *DylanIconTheme::instance()
{
    static DylanIconTheme singleton;
    return &singleton;
}

bool DylanIconTheme::hasThemeIcon(const QString &name) const
{
    return QIcon::hasThemeIcon(name);
}

void DylanIconTheme::refresh()
{
    // plasma-apply-colorscheme / kcm reescriben kdeglobals de forma atómica:
    // si el watcher perdió la ruta al reescribirse el archivo, se repone.
    const QString configDir = QDir::homePath() + QStringLiteral("/.config");
    const QString path = configDir + QStringLiteral("/kdeglobals");
    const bool fileMissing = !QFileInfo::exists(path);
    if (!m_watcher.directories().contains(configDir))
        m_watcher.addPath(configDir);
    if (!m_watcher.files().contains(path))
        m_watcher.addPath(path);

    const QString name = currentIconThemeName();
    if (name.isEmpty()) {
        if (!m_themeName.isEmpty()) {
            m_themeName.clear();
            QIcon::setThemeName(QString());
            emit themeChanged();
        }
        // El archivo puede estar temporalmente ausente durante el rename
        // atómico. Reintentar permite volver a registrar la ruta.
        if (fileMissing)
            QTimer::singleShot(50, this, &DylanIconTheme::refresh);
        return;
    }
    if (name == m_themeName)
        return;
    m_themeName = name;
    QIcon::setThemeName(name);
    emit themeChanged();
}

DylanIcon::DylanIcon(QQuickItem *parent)
    : QQuickPaintedItem(parent)
{
    connect(DylanIconTheme::instance(), &DylanIconTheme::themeChanged, this, [this] { update(); });
}

void DylanIcon::setName(const QString &name)
{
    if (m_name == name)
        return;
    m_name = name;
    emit nameChanged();
    update();
}

void DylanIcon::setFallback(const QString &fallback)
{
    if (m_fallback == fallback)
        return;
    m_fallback = fallback;
    emit fallbackChanged();
    update();
}

void DylanIcon::paint(QPainter *painter)
{
    QIcon icon = QIcon::fromTheme(m_name);
    if (icon.isNull() && !m_fallback.isEmpty())
        icon = QIcon::fromTheme(m_fallback);
    if (icon.isNull())
        return;

    // QIcon::paint ajusta manteniendo el aspecto y centrando; SVG = nítido a
    // cualquier tamaño. No se cachea nada propio: la caché ya la lleva Qt.
    const QRect rect(0, 0, int(width()), int(height()));
    if (rect.isEmpty())
        return;
    const QIcon::Mode mode = isEnabled() ? QIcon::Normal : QIcon::Disabled;
    icon.paint(painter, rect, Qt::AlignCenter, mode, QIcon::Off);
}
