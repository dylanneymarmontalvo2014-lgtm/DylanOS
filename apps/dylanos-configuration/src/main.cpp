#include <QCommandLineParser>
#include <QGuiApplication>
#include <QImage>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QTimer>

#include "services/LucideProvider.h"
#include "services/SystemService.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName("DylanOS Configuration");
    QGuiApplication::setApplicationVersion("1.0");
    QGuiApplication::setOrganizationName("DylanOS");
    QGuiApplication::setDesktopFileName("org.dylanos.configuration");

    QCommandLineParser parser;
    parser.setApplicationDescription("DylanOS Configuration");
    parser.addHelpOption();
    QCommandLineOption pageOption("page", "Abrir una sección concreta (system, network, sound, display…).", "page");
    QCommandLineOption smokeOption("smoke", "Cargar la interfaz sin interacción y salir (QA).");
    QCommandLineOption screenshotOption("screenshot", "Guardar una captura de una sección y salir (QA).", "screenshot");
    QCommandLineOption sizeOption("size", "Tamaño de la ventana para capturas (WxH).", "size");
    parser.addOptions({pageOption, smokeOption, screenshotOption, sizeOption});
    parser.process(app);

    auto *service = new SystemService(&app);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("System"), service);
    engine.addImageProvider(QStringLiteral("lucide"), new LucideProvider());

    engine.rootContext()->setContextProperty(QStringLiteral("startPage"),
                                             parser.isSet(pageOption) ? parser.value(pageOption)
                                                                      : QStringLiteral("system"));

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     []() { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    // Carga por URL con el prefijo estándar /qt/qml (patrón de DylanOS
    // Explorer). El singleton Theme vive en qml/theme/, NO en el mismo
    // directorio que Main.qml: si estuviera junto a él, el qmldir implícito
    // del directorio lo registraría como tipo plano y rompería la app en
    // Qt 6.8 ("Theme was a singleton at compile time…").
    engine.load(QUrl(QStringLiteral("qrc:/qt/qml/org/dylanos/configuration/qml/Main.qml")));
    if (engine.rootObjects().isEmpty())
        return 1;

    if (parser.isSet(sizeOption)) {
        const QStringList dims = parser.value(sizeOption).split(QLatin1Char('x'));
        if (dims.size() == 2) {
            for (QObject *obj : engine.rootObjects()) {
                if (auto *window = qobject_cast<QQuickWindow *>(obj))
                    window->resize(dims.value(0).toInt(), dims.value(1).toInt());
            }
        }
    }

    if (parser.isSet(screenshotOption)) {
        const QString target = parser.value(screenshotOption);
        QTimer::singleShot(900, &app, [&engine, target]() {
            for (QObject *obj : engine.rootObjects()) {
                if (auto *window = qobject_cast<QQuickWindow *>(obj)) {
                    const QImage shot = window->grabWindow();
                    const bool ok = shot.save(target);
                    QCoreApplication::exit(ok ? 0 : 2);
                    return;
                }
            }
            QCoreApplication::exit(1);
        });
        return app.exec();
    }

    if (parser.isSet(smokeOption)) {
        QTimer::singleShot(1200, &app, []() { QCoreApplication::exit(0); });
        return app.exec();
    }

    return app.exec();
}
