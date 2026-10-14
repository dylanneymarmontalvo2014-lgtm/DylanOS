#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("Calculadora"));
    app.setOrganizationName(QStringLiteral("DylanOS"));
    app.setDesktopFileName(QStringLiteral("org.dylanos.calculator"));
    app.setWindowIcon(QIcon::fromTheme(QStringLiteral("org.dylanos.calculator")));

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, [] { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

        engine.load(QUrl(QStringLiteral("qrc:/org/dylanos/calculator/qml/Main.qml")));

    return app.exec();
}
