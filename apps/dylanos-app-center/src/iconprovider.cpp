#include "iconprovider.h"

#include <QIcon>
#include <QSize>
#include <QPainter>

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

    QIcon icon = QIcon::fromTheme(id, QIcon::fromTheme(QStringLiteral("application-x-executable")));
    QImage image = icon.pixmap(iconSize, iconSize).toImage();
    if (image.isNull()) {
        image = QImage(iconSize, iconSize, QImage::Format_ARGB32_Premultiplied);
        image.fill(Qt::transparent);
        QPainter painter(&image);
        painter.setRenderHint(QPainter::Antialiasing);
        painter.setPen(Qt::NoPen);
        painter.setBrush(QColor("#DC143C"));
        painter.drawRoundedRect(QRectF(1, 1, iconSize - 2, iconSize - 2), iconSize / 4.0, iconSize / 4.0);
        painter.setBrush(Qt::white);
        const qreal unit = iconSize / 7.0;
        for (int x = 0; x < 2; ++x)
            for (int y = 0; y < 2; ++y)
                painter.drawRoundedRect(QRectF((1.5 + x * 2.5) * unit, (1.5 + y * 2.5) * unit, unit * 1.5, unit * 1.5), 2, 2);
    }

    if (size)
        *size = image.size();

    return image;
}
