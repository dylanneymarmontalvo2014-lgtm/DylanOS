#include "models/AppIconImageProvider.h"
#include "models/IconImageProvider.h"
#include "models/StoreController.h"
#include "services/LibDiscoverBackend.h"
#include <KAboutData>
#include <KCrash>
#include <KDBusService>
#include <KLocalizedString>
#include <QCommandLineParser>
#include <QDebug>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTimer>
#include <chrono>

#include <resources/ResourcesModel.h>
#include <resources/AbstractResourcesBackend.h>

static void runAction(const QString &action, StoreController *store, QObject *nav, QQuickWindow *win)
{
    const int colon = action.indexOf(QLatin1Char(':'));
    const QString name = colon < 0 ? action : action.left(colon);
    const QString arg = colon < 0 ? QString() : action.mid(colon + 1);
    if (name == QLatin1String("install")) store->install(arg);
    else if (name == QLatin1String("update")) store->update(arg);
    else if (name == QLatin1String("updateAll")) store->updateAll();
    else if (name == QLatin1String("offline")) store->setOffline(true);
    else if (name == QLatin1String("query")) QMetaObject::invokeMethod(nav, "setQuery", Q_ARG(QString, arg));
    else if (name == QLatin1String("open")) {
        if (QObject *o = win->findChild<QObject *>(arg))
            QMetaObject::invokeMethod(o, "open");
        else
            qWarning() << "open: no object named" << arg;
    } else qWarning() << "unknown action" << action;
}

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("dylanos-store"));
    app.setOrganizationName(QStringLiteral("DylanOS"));
    app.setWindowIcon(QIcon::fromTheme(QStringLiteral("dylanos-store")));
    QQuickStyle::setStyle(QStringLiteral("Basic")); // fully custom visuals; no platform style leaks in

    KAboutData about(QStringLiteral("dylanos-store"),
                     i18n("DylanOS Store"),
                     QStringLiteral(DYLANOS_STORE_VERSION),
                     i18n("Tienda de aplicaciones de DylanOS"),
                     KAboutLicense::GPL_V3);
    about.setOrganizationDomain(QByteArrayLiteral("org.dylanos"));
    about.setDesktopFileName(QStringLiteral("org.dylanos.store"));
    about.setProductName(QByteArrayLiteral("DylanOS Store"));
    KAboutData::setApplicationData(about);
    KCrash::initialize();

    QCommandLineParser cli;
    about.setupCommandLine(&cli);
    QCommandLineOption shot(QStringLiteral("screenshot"), QStringLiteral("Save a PNG of the window and quit."), QStringLiteral("file"));
    QCommandLineOption size(QStringLiteral("size"), QStringLiteral("Window size WxH."), QStringLiteral("WxH"));
    QCommandLineOption view(QStringLiteral("view"), QStringLiteral("Start view, e.g. home, cat:dev, app:krita."), QStringLiteral("view"));
    QCommandLineOption action(QStringLiteral("action"), QStringLiteral("Demo action applied before the screenshot (repeatable)."), QStringLiteral("action"));
    QCommandLineOption delay(QStringLiteral("delay"), QStringLiteral("Milliseconds to wait before capturing."), QStringLiteral("ms"), QStringLiteral("700"));
    QCommandLineOption mode(QStringLiteral("mode"), QStringLiteral("Start view by mode: Update, Installed, Browse."), QStringLiteral("mode"));
    QCommandLineOption search(QStringLiteral("search"), QStringLiteral("Open with the given search."), QStringLiteral("text"));
    cli.addOptions({shot, size, view, action, delay, mode, search});
    cli.process(app);

    auto *controller = new StoreController(new LibDiscoverBackend());
    StoreController::s_instance = controller;

    QQmlApplicationEngine engine;
    engine.addImageProvider(QStringLiteral("icon"), new IconImageProvider());
    engine.addImageProvider(QStringLiteral("appicon"), new AppIconImageProvider([controller](const QString &id) {
        return controller->resourceIcon(id);
    }));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);

    auto *model = ResourcesModel::global();
    bool catalogReady = false;
    QObject::connect(controller, &StoreController::catalogReady, &app, [&] {
        catalogReady = true;
        engine.loadFromModule("DylanOS", "Main");
    });
    if (model->backends().isEmpty())
        QObject::connect(model, &ResourcesModel::allInitialized, &app, [&] { controller->loadFromResources(model); });
    else
        controller->loadFromResources(model);
    // Hard watchdog: always open, even with an incomplete catalog.
    QTimer::singleShot(std::chrono::seconds(20), &app, [&] {
        if (!catalogReady) {
            qWarning() << "catalog watchdog fired";
            Q_EMIT controller->catalogReady();
        }
    });

    // Wait until the QML window exists (or fail after the watchdog).
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app, [&](QObject *obj, const QUrl &) {
        if (!obj)
            return;
        auto *win = qobject_cast<QQuickWindow *>(obj);
        if (!win)
            return;
        QObject *nav = engine.singletonInstance<QObject *>("DylanOS", "Nav");

        if (cli.isSet(mode)) {
            const QString m = cli.value(mode).toLower();
            if (m == QLatin1String("update"))
                QMetaObject::invokeMethod(nav, "go", Q_ARG(QVariant, QVariant(QStringLiteral("updates"))), Q_ARG(QVariant, QVariant()));
            else if (m == QLatin1String("installed"))
                QMetaObject::invokeMethod(nav, "go", Q_ARG(QVariant, QVariant(QStringLiteral("installed"))), Q_ARG(QVariant, QVariant()));
            else
                QMetaObject::invokeMethod(nav, "go", Q_ARG(QVariant, QVariant(QStringLiteral("cats"))), Q_ARG(QVariant, QVariant()));
        }
        if (cli.isSet(view) && nav) {
            const QStringList v = cli.value(view).split(QLatin1Char(':'));
            QMetaObject::invokeMethod(nav, "go", Q_ARG(QVariant, QVariant(v.value(0))), Q_ARG(QVariant, QVariant(v.value(1))));
        }
        if (cli.isSet(search) && nav)
            QMetaObject::invokeMethod(nav, "setQuery", Q_ARG(QString, cli.value(search)));

        if (cli.isSet(shot)) {
            if (cli.isSet(size)) {
                const QStringList wh = cli.value(size).split(QLatin1Char('x'));
                if (wh.size() == 2) win->resize(wh[0].toInt(), wh[1].toInt());
            }
            const QStringList actions = cli.values(action);
            const QString shotPath = cli.value(shot);
            const int delayMs = cli.value(delay).toInt();
            QTimer::singleShot(300, &app, [=] {
                for (const QString &a : actions)
                    runAction(a, StoreController::s_instance, nav, win);
            });
            QTimer::singleShot(delayMs, &app, [=] {
                const QImage img = win->grabWindow();
                const bool ok = img.save(shotPath);
                qInfo() << "screenshot" << shotPath << img.size() << (ok ? "ok" : "FAILED");
                QCoreApplication::exit(ok ? 0 : 2);
            });
        }
    });

    KDBusService service(KDBusService::Unique);
    QObject::connect(&service, &KDBusService::activateRequested, &engine, [&engine](const QStringList &args, const QString &) {
        if (!engine.rootObjects().isEmpty()) {
            auto *win = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
            if (win) {
                win->show();
                win->raise();
                win->requestActivate();
            }
        }
        Q_UNUSED(args)
    });

    return app.exec();
}
