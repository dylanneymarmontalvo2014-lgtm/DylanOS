#include "CatalogSync.h"
#include "../models/StoreController.h"
#include <QFile>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QTemporaryFile>
#include <QVariant>

const QString CatalogSync::RemoteUrl =
    QStringLiteral("https://raw.githubusercontent.com/dylanneymarmontalvo2014-lgtm/DylanOS/development/apps/dylanos-store/catalog/store.db");

CatalogSync::CatalogSync(StoreController *store, QObject *parent)
    : QObject(parent)
    , m_store(store)
    , m_nam(new QNetworkAccessManager(this))
{
}

void CatalogSync::applySeed()
{
    // QSql needs a file on disk: copy the embedded seed out of the resources.
    if (!m_seedCopy.isOpen()) {
        QFile seed(QStringLiteral(":/data/store-seed.db"));
        if (!seed.open(QIODevice::ReadOnly) || !m_seedCopy.open()) {
            qWarning() << "catalog seed missing from resources";
            return;
        }
        m_seedCopy.write(seed.readAll());
        m_seedCopy.flush();
    }
    if (!applyFile(m_seedCopy.fileName()))
        qWarning() << "catalog seed could not be applied (¿falta el driver QSQLITE?)";
}

void CatalogSync::refresh()
{
    QNetworkRequest request{QUrl(RemoteUrl)};
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(8000);
    QNetworkReply *reply = m_nam->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError || reply->bytesAvailable() < 32) {
            qWarning() << "catalog refresh skipped:" << reply->errorString();
            return; // sin red: seguimos con el catálogo empaquetado
        }
        auto *tmp = new QTemporaryFile(QStandardPaths::writableLocation(QStandardPaths::TempLocation) + QStringLiteral("/dylanos-store-XXXXXX.db"), this);
        if (!tmp->open() || tmp->write(reply->readAll()) == -1) {
            delete tmp;
            return;
        }
        tmp->flush();
        if (applyFile(tmp->fileName()))
            qInfo() << "catalog refreshed from" << RemoteUrl;
        delete tmp;
    });
}

bool CatalogSync::applyFile(const QString &path)
{
    const QString connection = QStringLiteral("dylanos-catalog-%1").arg(quintptr(this));
    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connection);
        db.setDatabaseName(path);
        if (!db.open()) {
            QSqlDatabase::removeDatabase(connection);
            return false;
        }

        QVariantList rows, collections;
        QSqlQuery appsQuery(db);
        appsQuery.prepare(QStringLiteral("SELECT package, backend, shelf, position,"
                                         " COALESCE(display_name, ''), COALESCE(summary, '')"
                                         " FROM apps ORDER BY shelf, position"));
        if (appsQuery.exec()) {
            while (appsQuery.next()) {
                rows << QVariantMap{{QStringLiteral("package"), appsQuery.value(0)},
                                    {QStringLiteral("backend"), appsQuery.value(1)},
                                    {QStringLiteral("shelf"), appsQuery.value(2)},
                                    {QStringLiteral("position"), appsQuery.value(3)},
                                    {QStringLiteral("display_name"), appsQuery.value(4)},
                                    {QStringLiteral("summary"), appsQuery.value(5)}};
            }
        }
        QSqlQuery collectionsQuery(db);
        collectionsQuery.prepare(QStringLiteral("SELECT name, COALESCE(descr, ''), position"
                                                " FROM collections ORDER BY position"));
        if (collectionsQuery.exec()) {
            while (collectionsQuery.next()) {
                collections << QVariantMap{{QStringLiteral("name"), collectionsQuery.value(0)},
                                            {QStringLiteral("descr"), collectionsQuery.value(1)},
                                            {QStringLiteral("ids"), QStringList{}}};
            }
        }
        db.close();
        if (rows.isEmpty())
            return false;
        m_store->applyShelfRows(rows, collections);
    }
    QSqlDatabase::removeDatabase(connection);
    return true;
}
