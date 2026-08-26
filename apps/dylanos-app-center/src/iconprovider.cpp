#include "iconprovider.h"

#include <QIcon>
#include <QSize>

IconProvider::IconProvider()
    : QQuickImageProvider(QQuickImageProvider::Image)
{
}

QImage IconProvider::requestImage(
    const QString &id,
    QSize *size,
    const QSize &requestedSize)
{
    const int iconSize = requestedSize.width() > 0
        ? requestedSize.width()
        : 64;

    QIcon icon = QIcon::fromTheme(id);

    if (icon.isNull())
        return QImage();

    QImage image = icon
        .pixmap(iconSize, iconSize)
        .toImage();

    if (size)
        *size = image.size();

    return image;
}
