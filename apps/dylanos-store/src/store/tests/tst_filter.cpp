#include "AppFilterModel.h"
#include "MockPackageBackend.h"
#include "StoreController.h"
#include <QtTest>

class TstFilter : public QObject
{
    Q_OBJECT
    StoreController *c = nullptr;

private Q_SLOTS:
    void initTestCase()
    {
        c = new StoreController(new MockPackageBackend(nullptr, false));
        QString err;
        QVERIFY2(c->loadCatalog(QStringLiteral(DEMO_JSON), &err), qPrintable(err));
    }
    void cleanupTestCase() { delete c; }

    void catalogLoaded() { QCOMPARE(c->appModel()->rowCount(), 23); }

    void categoryFilter()
    {
        AppFilterModel m;
        m.setSourceModel(c->appModel());
        m.setCategory("dev");
        QCOMPARE(m.count(), 2);
        m.setCategory("all");
        QCOMPARE(m.count(), 23);
    }
    void searchIsCaseInsensitive()
    {
        AppFilterModel m;
        m.setSourceModel(c->appModel());
        m.setQuery("vídeo");
        const int n = m.count();
        QVERIFY(n > 0);
        m.setQuery("VÍDEO"); // same semantics as the React prototype: case-insensitive, accent-sensitive
        QCOMPARE(m.count(), n);
    }
    void searchNoMatch()
    {
        AppFilterModel m;
        m.setSourceModel(c->appModel());
        m.setQuery("zzzzqqq");
        QCOMPARE(m.count(), 0);
    }
    void statusFilter()
    {
        AppFilterModel m;
        m.setSourceModel(c->appModel());
        m.setStatusFilter("installed");
        const int inst = m.count();
        m.setStatusFilter("available");
        QCOMPARE(inst + m.count() + c->updateCount(), 23);
    }
    void idsRestriction()
    {
        AppFilterModel m;
        m.setSourceModel(c->appModel());
        m.setIds({"krita", "code"});
        m.setRestrictToIds(true);
        QCOMPARE(m.count(), 2);
    }
};

QTEST_MAIN(TstFilter)
#include "tst_filter.moc"
