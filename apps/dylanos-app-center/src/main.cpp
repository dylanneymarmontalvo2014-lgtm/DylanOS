#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "appmodel.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName("DylanOS App Center");
    app.setOrganizationName("DylanOS");

    AppModel appModel;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("appModel", &appModel);
    engine.loadFromModule("DylanOS.AppCenter", "Main");

    if (engine.rootObjects().isEmpty()) return -1;
    return app.exec();
}
