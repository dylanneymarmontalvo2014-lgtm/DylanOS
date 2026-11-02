#include <QFile>
#include <QDir>
#include <QTemporaryDir>
#include <QtTest>

#include "CrimsonGlassService.h"

class CrimsonGlassServiceTest : public QObject
{
    Q_OBJECT

private slots:
    void init();
    void cleanup();
    void defaultsAreComplete();
    void invalidValuesAreRejected();
    void settingsPersist();
    void softwareRenderingDegradesSafely();
    void restoreRemovesOriginallyMissingKey();

private:
    std::unique_ptr<QTemporaryDir> m_root;
};

void CrimsonGlassServiceTest::init()
{
    m_root = std::make_unique<QTemporaryDir>();
    QVERIFY(m_root->isValid());
    qputenv("DYLANOS_CRIMSON_TEST_ROOT", m_root->path().toUtf8());
    qunsetenv("DYLANOS_CRIMSON_RENDERER");
}

void CrimsonGlassServiceTest::cleanup()
{
    qunsetenv("DYLANOS_CRIMSON_TEST_ROOT");
    qunsetenv("DYLANOS_CRIMSON_RENDERER");
    m_root.reset();
}

void CrimsonGlassServiceTest::defaultsAreComplete()
{
    CrimsonGlassService service;
    const QVariantMap values = service.settings();

    QCOMPARE(values.value("enabled").toBool(), true);
    QCOMPARE(values.value("globalEffects").toBool(), true);
    QCOMPARE(values.value("glassIntensity").toInt(), 72);
    QCOMPARE(values.value("transparency").toInt(), 68);
    QCOMPARE(values.value("blur").toInt(), 70);
    QCOMPARE(values.value("reflections").toInt(), 64);
    QCOMPARE(values.value("shadows").toInt(), 66);
    QCOMPARE(values.value("cornerRadius").toInt(), 18);
    QCOMPARE(values.value("accent").toString(), QStringLiteral("#DC143C"));
    QCOMPARE(values.value("mode").toString(), QStringLiteral("automatic"));
    QCOMPARE(values.value("panelTransparency").toInt(), 72);
    QCOMPARE(values.value("dockTransparency").toInt(), 78);
    QCOMPARE(values.value("menuTransparency").toInt(), 70);
    QCOMPARE(values.value("windowEffects").toBool(), true);
    QCOMPARE(values.value("backgroundBlur").toBool(), true);
    QCOMPARE(values.value("animations").toBool(), true);
    QCOMPARE(values.value("animationDuration").toInt(), 180);
    QCOMPARE(values.value("additionalEffects").toBool(), true);
    QCOMPARE(values.value("lowPower").toBool(), false);
    QCOMPARE(values.value("autoDetect").toBool(), true);
}

void CrimsonGlassServiceTest::invalidValuesAreRejected()
{
    CrimsonGlassService service;

    QVERIFY(!service.setOption(QStringLiteral("blur"), 101));
    QVERIFY(!service.setOption(QStringLiteral("cornerRadius"), -1));
    QVERIFY(!service.setOption(QStringLiteral("animationDuration"), 40));
    QVERIFY(!service.setOption(QStringLiteral("accent"), QStringLiteral("crimson")));
    QVERIFY(!service.setOption(QStringLiteral("mode"), QStringLiteral("sepia")));
    QVERIFY(!service.setOption(QStringLiteral("unknown"), true));
    QCOMPARE(service.settings().value("blur").toInt(), 70);
}

void CrimsonGlassServiceTest::settingsPersist()
{
    {
        CrimsonGlassService service;
        QVERIFY(service.setOption(QStringLiteral("blur"), 44));
        QVERIFY(service.setOption(QStringLiteral("enabled"), false));
    }

    CrimsonGlassService restored;
    QCOMPARE(restored.settings().value("blur").toInt(), 44);
    QCOMPARE(restored.settings().value("enabled").toBool(), false);
}

void CrimsonGlassServiceTest::softwareRenderingDegradesSafely()
{
    qputenv("DYLANOS_CRIMSON_RENDERER", "llvmpipe");
    CrimsonGlassService service;
    service.detectCapabilities();

    QCOMPARE(service.capabilities().value("softwareRendering").toBool(), true);
    QCOMPARE(service.effectiveEffects().value("blur").toBool(), false);
    QCOMPARE(service.effectiveEffects().value("contrast").toBool(), false);
    QVERIFY(service.effectiveEffects().value("surfaceOpacity").toInt() >= 88);
}

void CrimsonGlassServiceTest::restoreRemovesOriginallyMissingKey()
{
    const QString configDir = m_root->path() + QStringLiteral("/.config");
    QVERIFY(QDir().mkpath(configDir));
    QFile kwinrc(configDir + QStringLiteral("/kwinrc"));
    QVERIFY(kwinrc.open(QIODevice::WriteOnly | QIODevice::Text));
    kwinrc.write("[Unrelated]\nKeep=true\n");
    kwinrc.close();

    CrimsonGlassService service;
    QVERIFY(service.apply());
    QVERIFY(service.restorePrevious());

    QVERIFY(kwinrc.open(QIODevice::ReadOnly | QIODevice::Text));
    const QString restored = QString::fromUtf8(kwinrc.readAll());
    QVERIFY(restored.contains(QStringLiteral("[Unrelated]")));
    QVERIFY(restored.contains(QStringLiteral("Keep=true")));
    QVERIFY(!restored.contains(QStringLiteral("blurEnabled")));
}

QTEST_MAIN(CrimsonGlassServiceTest)
#include "tst_crimsonglass.moc"
