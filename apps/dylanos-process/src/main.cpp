// DylanOS Process: monitor de procesos y recursos con datos reales.
//
// El núcleo de datos es Rust (../core); aquí solo se expone a QML y se pinta la
// ventana DylanOS frameless. No hay valores simulados en ninguna capa.

#include "applicationmodel.h"
#include "iconprovider.h"
#include "processcontroller.h"
#include "processmodel.h"
#include "servicemodel.h"

#include <QDir>
#include <QGuiApplication>
#include <QIcon>
#include <QImage>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QTimer>
#include <QUrl>
#include <QVariantMap>

// El módulo QML se compila como plugin ESTÁTICO. Sin registrarlo explícitamente,
// `import org.dylanos.process` dentro de un componente del propio módulo falla
// con "plugin not found" en una app sin instalación en disco.
#include <QtQml/qqmlextensionplugin.h>
Q_IMPORT_QML_PLUGIN(org_dylanos_processPlugin)

#include <cstdio>
#include <cstring>

namespace {

// Modo QA: `--screenshot ruta.png --page <pestaña> --size 1280x800`.
//
// Se resuelve aquí (y no en QML) para que la captura ocurra después del primer
// refresco real: así la imagen muestra datos del sistema, no ceros.
struct CliOptions {
    QString screenshot;
    QString page = QStringLiteral("processes");
    QSize size{1280, 800};
    int delayMs = 1200;
};

CliOptions parseArgs(const QStringList &args)
{
    CliOptions options;
    for (int i = 1; i < args.size(); ++i) {
        const QString &arg = args.at(i);
        if (arg == QLatin1String("--screenshot") && i + 1 < args.size()) {
            options.screenshot = args.at(++i);
        } else if (arg == QLatin1String("--page") && i + 1 < args.size()) {
            options.page = args.at(++i);
        } else if (arg == QLatin1String("--size") && i + 1 < args.size()) {
            const QStringList parts = args.at(++i).split(QLatin1Char('x'));
            if (parts.size() == 2) {
                options.size = QSize(parts.at(0).toInt(), parts.at(1).toInt());
            }
        } else if (arg == QLatin1String("--delay") && i + 1 < args.size()) {
            options.delayMs = args.at(++i).toInt();
        }
    }
    return options;
}

} // namespace

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("DylanOS Process"));
    app.setApplicationVersion(QStringLiteral(DYLANOS_VERSION));
    app.setOrganizationName(QStringLiteral("DylanOS"));
    // App id Wayland: debe coincidir con el nombre del .desktop sin extensión.
    app.setDesktopFileName(QStringLiteral("org.dylanos.process"));
    app.setWindowIcon(QIcon::fromTheme(QStringLiteral("dylanos-process")));

    const CliOptions options = parseArgs(app.arguments());

    // Tema de iconos: la app se dibuja con los iconos reales del pack.
    //
    // Sin escritorio (QA offscreen, o un arranque fuera de sesión) Qt deja
    // themeSearchPaths solo en ":/icons" y QIcon::fromTheme no encuentra nada
    // del sistema. Se añaden las rutas estándar XDG para que el tema activo se
    // resuelva igual que en una sesión KDE normal.
    QStringList iconPaths = QIcon::themeSearchPaths();
    const QStringList systemIconPaths = {
        QStringLiteral("/usr/share/icons"),
        QStringLiteral("/usr/local/share/icons"),
        QDir::homePath() + QStringLiteral("/.local/share/icons"),
    };
    for (const QString &path : systemIconPaths) {
        if (!iconPaths.contains(path)) {
            iconPaths.append(path);
        }
    }
    QIcon::setThemeSearchPaths(iconPaths);
    QIcon::setFallbackThemeName(QStringLiteral("hicolor"));

    // El tema configurado por DylanOS se aplica cuando Qt no deduce ninguno.
    if (QIcon::themeName().isEmpty()) {
        for (const char *candidate : {"DylanIcons-Crimson", "breeze", "hicolor"}) {
            if (QDir(QStringLiteral("/usr/share/icons/") + QLatin1String(candidate)).exists()) {
                QIcon::setThemeName(QString::fromLatin1(candidate));
                break;
            }
        }
    }

    ProcessModel processModel;
    ProcessFilterModel filterModel;
    filterModel.setSourceModel(&processModel);
    ApplicationModel applicationModel;
    applicationModel.setSource(&processModel);
    ServiceModel serviceModel;
    ProcessController controller;

    // Primer refresco antes de crear la ventana: la tabla nunca aparece vacía.
    processModel.refresh();

    QQmlApplicationEngine engine;
    // Iconos reales del tema activo para la interfaz (image://icon/<nombre>).
    engine.addImageProvider(QStringLiteral("icon"), new IconImageProvider);
    engine.rootContext()->setContextProperty(QStringLiteral("processModel"), &processModel);
    engine.rootContext()->setContextProperty(QStringLiteral("processFilter"), &filterModel);
    engine.rootContext()->setContextProperty(QStringLiteral("applicationModel"), &applicationModel);
    engine.rootContext()->setContextProperty(QStringLiteral("serviceModel"), &serviceModel);
    engine.rootContext()->setContextProperty(QStringLiteral("processController"), &controller);
    engine.rootContext()->setContextProperty(QStringLiteral("initialPage"), options.page);
    engine.rootContext()->setContextProperty(QStringLiteral("screenshotPath"), options.screenshot);
    engine.rootContext()->setContextProperty(QStringLiteral("screenshotSize"), options.size);
    engine.rootContext()->setContextProperty(QStringLiteral("screenshotDelay"), options.delayMs);

    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
        [] {
            std::fprintf(stderr, "No se pudo crear la ventana de DylanOS Process.\n");
            QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection);

    engine.load(QUrl(QStringLiteral("qrc:/qt/qml/org/dylanos/process/qml/Main.qml")));
    if (engine.rootObjects().isEmpty()) {
        std::fprintf(stderr, "No se cargó la interfaz de DylanOS Process.\n");
        return 1;
    }

    // QA opt-in: graba la ventana real con datos ya pintados. `grabWindow()`
    // es el único camino que funciona con la plataforma offscreen.
    if (!options.screenshot.isEmpty()) {
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst());
        if (window) {
            QObject::connect(
                window, &QQuickWindow::sceneGraphInitialized, window,
                [window, options] {
                    QTimer::singleShot(options.delayMs, window, [window, options] {
                        const QImage image = window->grabWindow();
                        if (!image.save(options.screenshot)) {
                            std::fprintf(stderr, "No se pudo guardar la captura en %s\n",
                                         options.screenshot.toLocal8Bit().constData());
                        }
                        QGuiApplication::quit();
                    });
                },
                Qt::SingleShotConnection);
        }
    }

    return app.exec();
}
