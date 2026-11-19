#include "iconprovider.h"

#include <QDir>
#include <QIcon>
#include <QImage>
#include <QPixmap>

namespace {
// Las rutas XDG estándar de iconos. Sin esto Qt solo busca en ":/icons" cuando
// no hay sesión de escritorio (QA offscreen) y todo icono del sistema aparece
// como ausente.
void ensureThemeSearchPaths()
{
    static bool done = false;
    if (done) {
        return;
    }
    done = true;
    QStringList paths = QIcon::themeSearchPaths();
    for (const QString &extra : {QStringLiteral("/usr/share/icons"),
                                 QStringLiteral("/usr/local/share/icons"),
                                 QDir::homePath() + QStringLiteral("/.local/share/icons")}) {
        if (!paths.contains(extra)) {
            paths.append(extra);
        }
    }
    QIcon::setThemeSearchPaths(paths);
    if (QIcon::themeName().isEmpty()) {
        for (const char *candidate : {"DylanIcons-Crimson", "breeze", "hicolor"}) {
            if (QDir(QStringLiteral("/usr/share/icons/") + QLatin1String(candidate)).exists()) {
                QIcon::setThemeName(QString::fromLatin1(candidate));
                break;
            }
        }
    }
    QIcon::setFallbackThemeName(QStringLiteral("hicolor"));
}
} // namespace

IconImageProvider::IconImageProvider()
    : QQuickImageProvider(QQuickImageProvider::Image)
{
    ensureThemeSearchPaths();
}

QImage IconImageProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    const QSize target = requestedSize.isValid() ? requestedSize : QSize(24, 24);
    const QString key = id + QLatin1Char('@') + QString::number(target.width()) + QLatin1Char('x')
        + QString::number(target.height());

    const auto cached = m_cache.constFind(key);
    if (cached != m_cache.constEnd()) {
        if (size) {
            *size = cached->size();
        }
        return *cached;
    }

    // QIcon::fromTheme consulta el tema configurado (KDE/Breeze/DylanIcons) y
    // devuelve un icono vacío si el nombre no existe: la UI cae a la inicial.
    ensureThemeSearchPaths();
    const QIcon icon = QIcon::fromTheme(id);
    QImage image;
    if (!icon.isNull()) {
        const int edge = qMax(target.width(), target.height());
        image = icon.pixmap(QSize(edge, edge)).toImage();
        if (image.format() != QImage::Format_ARGB32_Premultiplied) {
            image = image.convertToFormat(QImage::Format_ARGB32_Premultiplied);
        }
    }

    m_cache.insert(key, image);
    if (size) {
        *size = image.size();
    }
    return image;
}
