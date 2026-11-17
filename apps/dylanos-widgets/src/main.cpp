#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("DylanOS Widgets"));
    app.setApplicationVersion(QStringLiteral(DYLANOS_VERSION));
    app.setOrganizationName(QStringLiteral("DylanOS"));
    // App id Wayland: debe coincidir con el nombre del .desktop sin extensión.
    app.setDesktopFileName(QStringLiteral("org.dylanos.widgets"));
    app.setWindowIcon(QIcon::fromTheme(QStringLiteral("org.dylanos.widgets")));

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, [] { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.load(QUrl(QStringLiteral("qrc:/qt/qml/org/dylanos/widgets/qml/Main.qml")));

    return app.exec();
}
