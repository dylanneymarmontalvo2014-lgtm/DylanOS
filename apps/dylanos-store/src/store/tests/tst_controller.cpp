#include "MockPackageBackend.h"
#include "StoreController.h"
#include <QtTest>

class TstController : public QObject
{
    Q_OBJECT
    StoreController *c = nullptr;
    MockPackageBackend *b = nullptr;

private Q_SLOTS:
    void init()
    {
        b = new MockPackageBackend([] { return 0.5; }, false);
        c = new StoreController(b);
        QString err;
        QVERIFY2(c->loadCatalog(QStringLiteral(DEMO_JSON), &err), qPrintable(err));
    }
    void cleanup() { delete c; }

    void initialCounts()
    {
        QCOMPARE(c->updateCount(), 3);
        QCOMPARE(c->installedCount(), 7); // pending updates are counted separately
        QCOMPARE(c->backendKind(), QString("mock"));
    }
    void missingFileReportsError()
    {
        QString err;
        QVERIFY(!c->loadCatalog(QStringLiteral("/nonexistent.json"), &err));
        QVERIFY(!err.isEmpty());
    }
    void installUpdatesModelAndCounts()
    {
        AppItem *a = c->app("krita");
        QVERIFY(a);
        const int before = c->installedCount();
        QCOMPARE(a->status(), QString("none"));
        c->install("krita");
        QCOMPARE(a->status(), QString("busy"));
        for (int i = 0; i < 100 && a->status() == "busy"; ++i) b->tick();
        QCOMPARE(a->status(), QString("installed"));
        QCOMPARE(c->installedCount(), before + 1);
    }
    void updateAllClearsBadge()
    {
        c->updateAll();
        for (int i = 0; i < 200 && c->updateCount() > 0; ++i) b->tick();
        for (int i = 0; i < 100; ++i) b->tick();
        QCOMPARE(c->updateCount(), 0);
    }
    void uninstallEmitsToastAndResets()
    {
        QSignalSpy toast(c, &StoreController::toast);
        c->uninstall("vlc");
        QCOMPARE(c->app("vlc")->status(), QString("none"));
        QVERIFY(toast.count() >= 1);
    }
    void favoritesToggle()
    {
        QVERIFY(!c->favorites().contains("code"));
        c->toggleFavorite("code");
        QVERIFY(c->favorites().contains("code"));
        c->toggleFavorite("code");
        QVERIFY(!c->favorites().contains("code"));
    }
    void offlineInstallErrors()
    {
        c->setOffline(true);
        c->install("krita");
        QCOMPARE(c->app("krita")->status(), QString("error"));
        QCOMPARE(c->app("krita")->errorKind(), QString("repo"));
    }
    void openAppNeverLaunches()
    {
        QSignalSpy toast(c, &StoreController::toast);
        c->openApp("code");
        QCOMPARE(toast.count(), 1); // demo: notification only
    }
};

QTEST_MAIN(TstController)
#include "tst_controller.moc"
