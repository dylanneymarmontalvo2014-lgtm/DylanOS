#pragma once
#include <QQuickImageProvider>
#include <functional>

class AppItem;

// Serves "image://appicon/<appId>/<version>" with the real icon of the catalog
// entry (theme icon, file or QIcon from libdiscover), with a Lucide fallback.
class AppIconImageProvider : public QQuickImageProvider
{
public:
    explicit AppIconImageProvider(const std::function<QVariant(const QString &)> &iconLookup);
    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) override;

private:
    std::function<QVariant(const QString &)> m_iconLookup;
};
