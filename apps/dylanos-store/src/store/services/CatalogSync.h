#pragma once
#include <QObject>
#include <QTemporaryFile>

class QNetworkAccessManager;
class StoreController;

// Editorial catalog shipped as SQLite. The store loads the bundled seed at
// startup and then tries to refresh it from the DylanOS repository, so the
// shelves can change with a plain git push — no ISO rebuild required.
class CatalogSync : public QObject
{
    Q_OBJECT
public:
    // Minimum required to add an app: package + package manager (apt|discover).
    // Everything else is auto-filled from the resource found in the catalog.
    static const QString RemoteUrl;

    explicit CatalogSync(StoreController *store, QObject *parent = nullptr);

    void applySeed(); // ":/data/store-seed.db" (bundled copy of the repo DB)
    void refresh(); // remote (GitHub raw); failures keep the seed quietly

private:
    bool applyFile(const QString &path);

    StoreController *m_store;
    QNetworkAccessManager *m_nam;
    QTemporaryFile m_seedCopy;
};
