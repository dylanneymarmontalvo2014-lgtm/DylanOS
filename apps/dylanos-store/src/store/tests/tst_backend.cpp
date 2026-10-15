#include "MockPackageBackend.h"
#include <QtTest>

class TstBackend : public QObject
{
    Q_OBJECT
    static QList<CatalogEntry> catalog()
    {
        return {{"a", "none", "", "1.0", ""},
                {"b", "update", "1.0", "2.0", ""},
                {"c", "installed", "3.0", "", ""},
                {"f", "none", "", "1.0", "deps"}};
    }
    // autoRun=false: tests drive the simulation with tick(); fixed random = deterministic.
    static MockPackageBackend *make() { auto *b = new MockPackageBackend([] { return 0.5; }, false); b->setCatalog(catalog()); return b; }

private Q_SLOTS:
    void initialState()
    {
        std::unique_ptr<MockPackageBackend> b(make());
        QCOMPARE(b->kind(), QString("mock"));
        QCOMPARE(b->state("a").status, QString("none"));
        QCOMPARE(b->state("b").status, QString("update"));
        QCOMPARE(b->state("c").status, QString("installed"));
    }
    void installRunsToCompletion()
    {
        std::unique_ptr<MockPackageBackend> b(make());
        QSignalSpy done(b.get(), &PackageBackend::operationCompleted);
        b->install("a");
        QCOMPARE(b->state("a").status, QString("busy"));
        for (int i = 0; i < 100 && b->state("a").status == "busy"; ++i) b->tick();
        QCOMPARE(b->state("a").status, QString("installed"));
        QCOMPARE(b->state("a").version, QString("1.0"));
        QCOMPARE(done.count(), 1);
    }
    void updateKeepsFlagAndBumpsVersion()
    {
        std::unique_ptr<MockPackageBackend> b(make());
        b->update("b");
        QVERIFY(b->state("b").isUpdate);
        for (int i = 0; i < 100 && b->state("b").status == "busy"; ++i) b->tick();
        QCOMPARE(b->state("b").status, QString("installed"));
        QCOMPARE(b->state("b").version, QString("2.0"));
        QVERIFY(!b->state("b").isUpdate);
    }
    void updateAllOnlyTouchesPending()
    {
        std::unique_ptr<MockPackageBackend> b(make());
        b->updateAll();
        QCOMPARE(b->state("b").status, QString("busy"));
        QCOMPARE(b->state("a").status, QString("none"));
        QCOMPARE(b->state("c").status, QString("installed"));
    }
    void cancelInstallVsUpdate()
    {
        std::unique_ptr<MockPackageBackend> b(make());
        b->install("a"); b->cancel("a");
        QCOMPARE(b->state("a").status, QString("cancelled"));
        b->update("b"); b->cancel("b");
        QCOMPARE(b->state("b").status, QString("update")); // an update falls back to "pending"
    }
    void failsOnceThenRetrySucceeds()
    {
        std::unique_ptr<MockPackageBackend> b(make());
        b->install("f");
        for (int i = 0; i < 100 && b->state("f").status == "busy"; ++i) b->tick();
        QCOMPARE(b->state("f").status, QString("error"));
        QCOMPARE(b->state("f").errorKind, QString("deps"));
        b->retry("f");
        for (int i = 0; i < 100 && b->state("f").status == "busy"; ++i) b->tick();
        QCOMPARE(b->state("f").status, QString("installed"));
    }
    void offlineFailsWithRepoError()
    {
        std::unique_ptr<MockPackageBackend> b(make());
        b->setOffline(true);
        b->install("a");
        QCOMPARE(b->state("a").status, QString("error"));
        QCOMPARE(b->state("a").errorKind, QString("repo"));
    }
    void removeResetsState()
    {
        std::unique_ptr<MockPackageBackend> b(make());
        b->remove("c");
        QCOMPARE(b->state("c").status, QString("none"));
        QVERIFY(b->state("c").version.isEmpty());
    }
};

QTEST_GUILESS_MAIN(TstBackend)
#include "tst_backend.moc"
