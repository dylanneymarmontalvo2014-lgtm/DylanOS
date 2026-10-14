#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QUrl>
#include <QIcon>
#include "appmodel.h"
#include "iconprovider.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    app.setApplicationName("DylanOS App Center");
    app.setOrganizationName("DylanOS");
    app.setDesktopFileName("dylanos-app-center");
    QIcon::setFallbackThemeName(QStringLiteral("breeze"));

    AppModel appModel;

    QQmlApplicationEngine engine;
    engine.addImageProvider("icon", new IconProvider());
    engine.rootContext()->setContextProperty("appModel", &appModel);
    engine.load(QUrl(QStringLiteral("qrc:/DylanOS/AppCenter/qml/Main.qml")));

    if (engine.rootObjects().isEmpty()) return -1;
    return app.exec();
}
