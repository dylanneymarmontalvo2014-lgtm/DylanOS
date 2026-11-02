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
    void missingKWinDoesNotReportExternalEffects();
    void reducedMotionDisablesAnimations();
    void automaticDetectionRefreshesBeforeApply();
    void restoreRemovesOriginallyMissingKey();
    void applyWritesKWinAndToolkitMappings();
    void applyGeneratesUserSurfaceProfile();
    void lowPowerDisablesExpensiveEffects();
    void failedApplyRestoresEarlierTargets();
    void applyIsIdempotent();

private:
    std::unique_ptr<QTemporaryDir> m_root;
};

void CrimsonGlassServiceTest::init()
{
    m_root = std::make_unique<QTemporaryDir>();
    QVERIFY(m_root->isValid());
    qputenv("DYLANOS_CRIMSON_TEST_ROOT", m_root->path().toUtf8());
    qputenv("DYLANOS_CRIMSON_TEST_CAPABILITIES", "full");
    qunsetenv("DYLANOS_CRIMSON_RENDERER");
    qunsetenv("KDE_ANIMATION_DURATION_FACTOR");
}

void CrimsonGlassServiceTest::cleanup()
{
    qunsetenv("DYLANOS_CRIMSON_TEST_ROOT");
    qunsetenv("DYLANOS_CRIMSON_RENDERER");
    qunsetenv("DYLANOS_CRIMSON_TEST_CAPABILITIES");
    qunsetenv("KDE_ANIMATION_DURATION_FACTOR");
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

void CrimsonGlassServiceTest::missingKWinDoesNotReportExternalEffects()
{
    qputenv("DYLANOS_CRIMSON_TEST_CAPABILITIES", "none");
    CrimsonGlassService service;
    service.detectCapabilities();

    QCOMPARE(service.capabilities().value("kwinAvailable").toBool(), false);
    QCOMPARE(service.effectiveEffects().value("blur").toBool(), false);
    QCOMPARE(service.effectiveEffects().value("contrast").toBool(), false);
    QCOMPARE(service.effectiveEffects().value("animations").toBool(), false);
    QCOMPARE(service.effectiveEffects().value("windowEffects").toBool(), false);
}

void CrimsonGlassServiceTest::reducedMotionDisablesAnimations()
{
    qputenv("KDE_ANIMATION_DURATION_FACTOR", "0");
    CrimsonGlassService service;
    service.detectCapabilities();

    QCOMPARE(service.capabilities().value("reducedMotion").toBool(), true);
    QCOMPARE(service.effectiveEffects().value("animations").toBool(), false);
}

void CrimsonGlassServiceTest::automaticDetectionRefreshesBeforeApply()
{
    qputenv("DYLANOS_CRIMSON_RENDERER", "OpenGL 3.1");
    CrimsonGlassService service;
    QCOMPARE(service.capabilities().value("softwareRendering").toBool(), false);

    qputenv("DYLANOS_CRIMSON_RENDERER", "llvmpipe");
    QVERIFY(service.apply());
    QCOMPARE(service.capabilities().value("softwareRendering").toBool(), true);

    QVERIFY(service.setOption(QStringLiteral("autoDetect"), false));
    qputenv("DYLANOS_CRIMSON_RENDERER", "OpenGL 3.1");
    QVERIFY(service.apply());
    QCOMPARE(service.capabilities().value("softwareRendering").toBool(), true);
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

void CrimsonGlassServiceTest::applyWritesKWinAndToolkitMappings()
{
    qputenv("DYLANOS_CRIMSON_RENDERER", "OpenGL 3.1");
    CrimsonGlassService service;
    QVERIFY(service.setOption(QStringLiteral("blur"), 100));
    QVERIFY(service.setOption(QStringLiteral("animationDuration"), 240));
    QVERIFY(service.setOption(QStringLiteral("mode"), QStringLiteral("dark")));
    QVERIFY(service.setOption(QStringLiteral("accent"), QStringLiteral("#E81740")));
    QVERIFY(service.apply());

    QFile kwinrc(m_root->path() + QStringLiteral("/.config/kwinrc"));
    QVERIFY(kwinrc.open(QIODevice::ReadOnly | QIODevice::Text));
    const QString kwin = QString::fromUtf8(kwinrc.readAll());
    QVERIFY(kwin.contains(QStringLiteral("BlurStrength=15")));
    QVERIFY(kwin.contains(QStringLiteral("Duration=240")));
    QVERIFY(kwin.contains(QStringLiteral("SlideInTime=240")));
    QVERIFY(kwin.contains(QStringLiteral("glideEnabled=true")));
    QVERIFY(kwin.contains(QStringLiteral("translucencyEnabled=true")));
    QVERIFY(kwin.contains(QStringLiteral("theme=__aurorae__svg__DylanOS-Crimson-Glass")));

    QFile plasma(m_root->path() + QStringLiteral("/.config/plasmarc"));
    QVERIFY(plasma.open(QIODevice::ReadOnly | QIODevice::Text));
    QVERIFY(QString::fromUtf8(plasma.readAll()).contains(QStringLiteral("name=DylanOS-Crimson-Glass")));

    QFile globals(m_root->path() + QStringLiteral("/.config/kdeglobals"));
    QVERIFY(globals.open(QIODevice::ReadOnly | QIODevice::Text));
    const QString kde = QString::fromUtf8(globals.readAll());
    QVERIFY(kde.contains(QStringLiteral("AccentColor=#E81740")));
    QVERIFY(kde.contains(QStringLiteral("ColorScheme=DylanOSDark")));

    for (const QString &version : {QStringLiteral("gtk-3.0"), QStringLiteral("gtk-4.0")}) {
        QFile gtk(m_root->path() + QStringLiteral("/.config/") + version + QStringLiteral("/settings.ini"));
        QVERIFY(gtk.open(QIODevice::ReadOnly | QIODevice::Text));
        const QString settings = QString::fromUtf8(gtk.readAll());
        QVERIFY(settings.contains(QStringLiteral("gtk-theme-name=DylanOS-Crimson")));
        QVERIFY(settings.contains(QStringLiteral("gtk-application-prefer-dark-theme=1")));
    }
}

void CrimsonGlassServiceTest::lowPowerDisablesExpensiveEffects()
{
    qputenv("DYLANOS_CRIMSON_RENDERER", "OpenGL 3.1");
    CrimsonGlassService service;
    QVERIFY(service.setOption(QStringLiteral("lowPower"), true));
    QVERIFY(service.apply());

    QFile kwinrc(m_root->path() + QStringLiteral("/.config/kwinrc"));
    QVERIFY(kwinrc.open(QIODevice::ReadOnly | QIODevice::Text));
    const QString kwin = QString::fromUtf8(kwinrc.readAll());
    QVERIFY(kwin.contains(QStringLiteral("blurEnabled=false")));
    QVERIFY(kwin.contains(QStringLiteral("contrastEnabled=false")));
    QVERIFY(kwin.contains(QStringLiteral("glideEnabled=false")));
    QVERIFY(kwin.contains(QStringLiteral("slidingpopupsEnabled=false")));
    QCOMPARE(service.effectiveEffects().value("animations").toBool(), false);
}

void CrimsonGlassServiceTest::failedApplyRestoresEarlierTargets()
{
    const QString configDir = m_root->path() + QStringLiteral("/.config");
    QVERIFY(QDir().mkpath(configDir));
    QFile kwinrc(configDir + QStringLiteral("/kwinrc"));
    QVERIFY(kwinrc.open(QIODevice::WriteOnly | QIODevice::Text));
    kwinrc.write("[Unrelated]\nKeep=true\n");
    kwinrc.close();
    QVERIFY(QDir().mkpath(configDir + QStringLiteral("/kdeglobals")));

    CrimsonGlassService service;
    QVERIFY(!service.apply());

    QVERIFY(kwinrc.open(QIODevice::ReadOnly | QIODevice::Text));
    const QString restored = QString::fromUtf8(kwinrc.readAll());
    QVERIFY(restored.contains(QStringLiteral("Keep=true")));
    QVERIFY(!restored.contains(QStringLiteral("blurEnabled")));
    QVERIFY(service.lastMessage().contains(QStringLiteral("recuperación")));
}

void CrimsonGlassServiceTest::applyGeneratesUserSurfaceProfile()
{
    CrimsonGlassService service;
    QVERIFY(service.setOption(QStringLiteral("glassIntensity"), 100));
    QVERIFY(service.setOption(QStringLiteral("panelTransparency"), 80));
    QVERIFY(service.setOption(QStringLiteral("menuTransparency"), 60));
    QVERIFY(service.setOption(QStringLiteral("reflections"), 50));
    QVERIFY(service.setOption(QStringLiteral("shadows"), 40));
    QVERIFY(service.setOption(QStringLiteral("cornerRadius"), 24));
    QVERIFY(service.setOption(QStringLiteral("accent"), QStringLiteral("#E81740")));
    QVERIFY(service.apply());

    const QString theme = m_root->path()
        + QStringLiteral("/.local/share/plasma/desktoptheme/DylanOS-Crimson-Glass");
    QFile panel(theme + QStringLiteral("/translucent/widgets/panel-background.svg"));
    QVERIFY(panel.open(QIODevice::ReadOnly | QIODevice::Text));
    const QString panelSvg = QString::fromUtf8(panel.readAll());
    QVERIFY(panelSvg.contains(QStringLiteral("Q0,0 24,0")));
    QVERIFY(panelSvg.contains(QStringLiteral("fill-opacity=\"0.64\"")));
    QVERIFY(panelSvg.contains(QStringLiteral("fill=\"#E81740\"")));
    QVERIFY(panelSvg.contains(QStringLiteral("fill-opacity=\"0.24\"")));
    QVERIFY(panelSvg.contains(QStringLiteral("fill-opacity=\"0.33\"")));

    QFile dialogs(theme + QStringLiteral("/translucent/dialogs/background.svg"));
    QVERIFY(dialogs.open(QIODevice::ReadOnly | QIODevice::Text));
    QVERIFY(QString::fromUtf8(dialogs.readAll()).contains(QStringLiteral("fill-opacity=\"0.73\"")));
}

void CrimsonGlassServiceTest::applyIsIdempotent()
{
    CrimsonGlassService service;
    QVERIFY(service.apply());

    QFile firstFile(m_root->path() + QStringLiteral("/.config/kwinrc"));
    QVERIFY(firstFile.open(QIODevice::ReadOnly | QIODevice::Text));
    const QByteArray first = firstFile.readAll();
    firstFile.close();

    QVERIFY(service.apply());
    QVERIFY(firstFile.open(QIODevice::ReadOnly | QIODevice::Text));
    QCOMPARE(firstFile.readAll(), first);
}

QTEST_MAIN(CrimsonGlassServiceTest)
#include "tst_crimsonglass.moc"
