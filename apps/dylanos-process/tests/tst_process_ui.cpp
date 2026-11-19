// Ejecutor de los tests QML de DylanOS Process.
//
// Los modelos reales (procesos, aplicaciones, servicios, controlador) se
// exponen al contexto QML con los mismos nombres que en la app, para que los
// tests ejerciten el código de producción y los datos reales del sistema.

#include <QGuiApplication>
#include <QQmlContext>
#include <QQmlEngine>
#include <QtQml/qqmlextensionplugin.h>
#include <QtQuickTest>

// El módulo QML es un plugin estático: hay que registrarlo para poder cargar
// la ventana de producción desde los tests.
Q_IMPORT_QML_PLUGIN(org_dylanos_processPlugin)

#include "applicationmodel.h"
#include "iconprovider.h"
#include "processcontroller.h"
#include "processmodel.h"
#include "servicemodel.h"

class ProcessTestSetup : public QObject
{
    Q_OBJECT

public:
    ProcessTestSetup() = default;

public slots:
    void qmlEngineAvailable(QQmlEngine *engine)
    {
        engine->addImageProvider(QStringLiteral("icon"), new IconImageProvider);

        m_processModel.refresh();
        m_filterModel.setSourceModel(&m_processModel);
        m_applicationModel.setSource(&m_processModel);
        m_serviceModel.reload();

        engine->rootContext()->setContextProperty(QStringLiteral("processModel"),
                                                  &m_processModel);
        engine->rootContext()->setContextProperty(QStringLiteral("processFilter"),
                                                  &m_filterModel);
        engine->rootContext()->setContextProperty(QStringLiteral("applicationModel"),
                                                  &m_applicationModel);
        engine->rootContext()->setContextProperty(QStringLiteral("serviceModel"),
                                                  &m_serviceModel);
        engine->rootContext()->setContextProperty(QStringLiteral("processController"),
                                                  &m_controller);
        engine->rootContext()->setContextProperty(QStringLiteral("initialPage"),
                                                  QStringLiteral("processes"));
        engine->rootContext()->setContextProperty(QStringLiteral("screenshotPath"),
                                                  QString());
        engine->rootContext()->setContextProperty(QStringLiteral("screenshotSize"),
                                                  QSize(1280, 800));
        engine->rootContext()->setContextProperty(QStringLiteral("screenshotDelay"), 0);
    }

private:
    ProcessModel m_processModel;
    ProcessFilterModel m_filterModel;
    ApplicationModel m_applicationModel;
    ServiceModel m_serviceModel;
    ProcessController m_controller;
};

    QUICK_TEST_MAIN_WITH_SETUP(process_ui, ProcessTestSetup)

#include "tst_process_ui.moc"
