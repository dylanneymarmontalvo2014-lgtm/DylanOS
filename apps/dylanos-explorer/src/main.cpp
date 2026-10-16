#include <QCommandLineParser>
#include <QFont>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QSurfaceFormat>
#include <QTimer>
#include <QUrl>

#include "services/ExplorerController.h"

int main(int argc, char *argv[])
{
    QSurfaceFormat fmt;
    fmt.setSamples(4); // anti-aliased Shapes (icons) and rounded corners
    QSurfaceFormat::setDefaultFormat(fmt);

    QGuiApplication app(argc, argv);
    QGuiApplication::setOrganizationName(QStringLiteral("DylanOS"));
    QGuiApplication::setApplicationName(QStringLiteral("Explorer"));
    QGuiApplication::setApplicationDisplayName(QStringLiteral("DylanOS Explorer"));
    QGuiApplication::setDesktopFileName(QStringLiteral("dylanos-explorer"));

    // The custom QML theme draws every control; Basic is the neutral base style.
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    QFont font = app.font();
    font.setFamilies({QStringLiteral("Inter"), QStringLiteral("Noto Sans"), QStringLiteral("Cantarell")});
    app.setFont(font);

    // Developer-only QA helpers (same pattern as dylanos-store): capture the
    // window without a display server. Actions are a closed list, no scripting.
    QCommandLineParser cli;
    cli.setApplicationDescription(QStringLiteral("Gestor de archivos de DylanOS"));
    QCommandLineOption shot(QStringLiteral("screenshot"), QStringLiteral("Guarda un PNG de la ventana y sale."), QStringLiteral("archivo"));
    QCommandLineOption size(QStringLiteral("size"), QStringLiteral("Tamaño de la ventana WxH."), QStringLiteral("WxH"));
    QCommandLineOption start(QStringLiteral("path"), QStringLiteral("Carpeta inicial."), QStringLiteral("ruta"));
    QCommandLineOption delay(QStringLiteral("delay"), QStringLiteral("ms antes de capturar."), QStringLiteral("ms"), QStringLiteral("700"));
    cli.addOptions({shot, size, start, delay});
    cli.addHelpOption();
    cli.process(app);

    QQmlApplicationEngine engine;
    const QString startDir = cli.value(start);
    const bool hasStart = cli.isSet(start);
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreated, &app, [&, hasStart, startDir](QObject *obj, const QUrl &) {
            if (!obj)
                return;
            auto *win = qobject_cast<QQuickWindow *>(obj);
            if (!win)
                return;
            auto *explorer = win->findChild<ExplorerController *>();
            if (hasStart && explorer) {
                QMetaObject::invokeMethod(explorer, "navigate", Q_ARG(QString, startDir));
            }
            if (cli.isSet(shot)) {
                if (cli.isSet(size)) {
                    const QStringList wh = cli.value(size).split(QLatin1Char('x'));
                    if (wh.size() == 2)
                        win->resize(wh[0].toInt(), wh[1].toInt());
                }
                const QString path = cli.value(shot);
                const int ms = cli.value(delay).toInt();
                QTimer::singleShot(ms, &app, [win, path] {
                    const QImage img = win->grabWindow();
                    const bool ok = img.save(path);
                    qInfo() << "screenshot" << path << img.size() << (ok ? "ok" : "FAILED");
                    QCoreApplication::exit(ok ? 0 : 2);
                });
            }
        });
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.load(QUrl(QStringLiteral("qrc:/qt/qml/DylanOS/Explorer/qml/Main.qml")));
    return app.exec();
}
