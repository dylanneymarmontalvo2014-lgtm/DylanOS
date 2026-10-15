#pragma once
#include <QQuickImageProvider>

// Serves recoloured copies of the white-stroke icon set: image://icon/<Name>/<aarrggbb|rrggbb>.
// Done in software so icons render identically with every Qt Quick scene-graph backend.
class IconImageProvider : public QQuickImageProvider
{
public:
    IconImageProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}
    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) override;
};
