#include "LoginManagerService.h"

#include <QColor>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QStandardPaths>
#include <QTimer>
#include <QHash>
#include <QUuid>

/**
 * Implementación del servicio del login.
 *
 * Dos decisiones que conviene tener presentes:
 *
 * 1. La configuración del login vive en /etc porque el greeter corre como el
 *    usuario `sddm` y no puede leer la carpeta personal de nadie. Escribir ahí
 *    requiere elevación, así que se intenta primero la escritura directa (el
 *    sistema de desarrollo y el usuario con permisos) y, si falla, se usa
 *    `pkexec`. Nunca se simula que se guardó: si no se puede, se avisa.
 *
 * 2. El fondo se COPIA al catálogo del login en vez de referenciar el archivo
 *    original: el greeter no puede leer /home y una ruta personal dejaría el
 *    login sin fondo. La copia se hace con permisos legibles (0644).
 */
namespace {

const char *kRutaAjustes = "/etc/dylanos/login-manager.json";
const char *kCarpetaFondos = "/usr/share/dylanos/login-manager/fondos";
const char *kCatalogo = "/usr/share/dylanos/login-manager/catalog/catalogo.json";
const char *kGreeter = "/usr/bin/dylanos-login-greeter";
const char *kTema = "/usr/share/sddm/themes/DylanOS-Crimson";

QString rutaDeTrabajo(const QString &sufijo)
{
    // En QA se puede apuntar a otra raíz para no tocar el sistema real.
    const QString raiz = qEnvironmentVariable("DYLANOS_LOGIN_ROOT");
    if (raiz.isEmpty() || raiz == QLatin1String("/"))
        return sufijo;
    return raiz + sufijo;
}

} // namespace

LoginManagerService::LoginManagerService(QObject *parent)
    : QObject(parent)
{
    loadCatalogo();
    loadSettings();
}

int LoginManagerService::maximumShortcuts() const
{
    // Es un límite del diseño, no una preferencia: la rejilla de atajos del
    // prototipo son dos filas de dos, y con más el dibujo se descuadra. Por eso
    // la propiedad es CONSTANT y no se lee de la configuración: una propiedad
    // CONSTANT que cambiara dejaría los bindings de QML con un valor viejo.
    return 4;
}

QString LoginManagerService::settingsPath() const
{
    return rutaDeTrabajo(QString::fromLatin1(kRutaAjustes));
}

QString LoginManagerService::backgroundPath() const
{
    const QVariantMap apariencia = m_settings.value(QStringLiteral("apariencia")).toMap();
    return apariencia.value(QStringLiteral("fondo_seleccionado")).toString();
}

QVariantMap LoginManagerService::defaultSettings() const
{
    // Los valores del prototipo: con estos el login es idéntico al diseño.
    QVariantMap apariencia;
    apariencia.insert(QStringLiteral("fondo_seleccionado"),
                      QStringLiteral("assets/fondo-seleccionado.png"));
    apariencia.insert(QStringLiteral("color_primario"), QStringLiteral("#DC143C"));
    apariencia.insert(QStringLiteral("usar_acento_del_sistema"), true);
    apariencia.insert(QStringLiteral("crimson_glass"), true);

    QVariantMap composicion;
    composicion.insert(QStringLiteral("variante"), QStringLiteral("completa"));
    composicion.insert(QStringLiteral("posicion_paneles"), QStringLiteral("clasica"));
    composicion.insert(QStringLiteral("tamano_reloj"), 1.0);
    composicion.insert(QStringLiteral("tamano_bloque_acceso"), 1.0);

    QVariantMap widgets;
    widgets.insert(QStringLiteral("columna_izquierda"),
                   QVariantList{QStringLiteral("clima"), QStringLiteral("proximo-evento"),
                                QStringLiteral("reproduccion"), QStringLiteral("sistema")});
    widgets.insert(QStringLiteral("columna_derecha"),
                   QVariantList{QStringLiteral("calendario"), QStringLiteral("recordatorios"),
                                QStringLiteral("atajos")});

    QVariantMap atajos;
    atajos.insert(QStringLiteral("maximo"), 4);
    atajos.insert(QStringLiteral("activos"),
                  QVariantList{QStringLiteral("tema"), QStringLiteral("no-molestar"),
                               QStringLiteral("wifi"), QStringLiteral("bluetooth")});

    QVariantMap clima;
    clima.insert(QStringLiteral("latitud"), QVariant());
    clima.insert(QStringLiteral("longitud"), QVariant());
    clima.insert(QStringLiteral("ciudad"), QString());

    QVariantMap agenda;
    agenda.insert(QStringLiteral("ics"), QString());

    QVariantMap mensaje;
    mensaje.insert(QStringLiteral("texto"), QString());
    mensaje.insert(QStringLiteral("usuario"), QString());

    QVariantMap relojMundial;
    relojMundial.insert(QStringLiteral("zonas"), QVariantList());

    QVariantMap raiz;
    raiz.insert(QStringLiteral("version"), 2);
    raiz.insert(QStringLiteral("apariencia"), apariencia);
    raiz.insert(QStringLiteral("composicion"), composicion);
    raiz.insert(QStringLiteral("widgets"), widgets);
    raiz.insert(QStringLiteral("atajos"), atajos);
    raiz.insert(QStringLiteral("clima"), clima);
    raiz.insert(QStringLiteral("agenda"), agenda);
    raiz.insert(QStringLiteral("recordatorios"), QVariantList());
    raiz.insert(QStringLiteral("reloj_mundial"), relojMundial);
    raiz.insert(QStringLiteral("mensaje"), mensaje);
    raiz.insert(QStringLiteral("usuario_predeterminado"), QString());
    raiz.insert(QStringLiteral("sesion"), QString());
    return raiz;
}

bool LoginManagerService::loadSettings()
{
    const QString ruta = settingsPath();
    QFile fichero(ruta);
    if (!fichero.exists()) {
        m_settings = defaultSettings();
        return true;
    }
    if (!fichero.open(QIODevice::ReadOnly)) {
        emit actionFailed(tr("No se pudo leer %1").arg(ruta));
        m_settings = defaultSettings();
        return false;
    }
    QJsonParseError error{};
    const QJsonDocument documento = QJsonDocument::fromJson(fichero.readAll(), &error);
    fichero.close();
    if (error.error != QJsonParseError::NoError || !documento.isObject()) {
        emit actionFailed(tr("La configuración del login está dañada: %1").arg(error.errorString()));
        m_settings = defaultSettings();
        return false;
    }
    // Se parte de los valores por defecto y se superpone lo guardado: así una
    // actualización que añada claves nuevas no deja huecos.
    QVariantMap base = defaultSettings();
    const QVariantMap guardado = documento.object().toVariantMap();
    for (auto it = guardado.constBegin(); it != guardado.constEnd(); ++it) {
        if (it.value().toMap().isEmpty() || !base.value(it.key()).toMap().isEmpty()) {
            QVariantMap fusion = base.value(it.key()).toMap();
            const QVariantMap parcial = it.value().toMap();
            for (auto jt = parcial.constBegin(); jt != parcial.constEnd(); ++jt)
                fusion.insert(jt.key(), jt.value());
            base.insert(it.key(), fusion);
        } else {
            base.insert(it.key(), it.value());
        }
    }
    m_settings = base;
    emit settingsChanged();
    return true;
}

bool LoginManagerService::saveSettings()
{
    const QString ruta = settingsPath();
    const QByteArray contenido = QJsonDocument(QJsonObject::fromVariantMap(m_settings))
                                     .toJson(QJsonDocument::Indented);
    QDir().mkpath(QFileInfo(ruta).absolutePath());

    // Primer intento: escritura directa (desarrollo, o usuario con permiso).
    QFile fichero(ruta);
    if (fichero.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        fichero.write(contenido);
        fichero.close();
        return true;
    }

    // Segundo intento: elevación por polkit. El contenido va por entrada
    // estándar para no construirlo dentro de un shell.
    if (QStandardPaths::findExecutable(QStringLiteral("pkexec")).isEmpty()) {
        emit actionFailed(tr("No se pudo guardar %1 y pkexec no está disponible").arg(ruta));
        return false;
    }
    const QString temporal = QDir::tempPath() + QStringLiteral("/dylanos-login-XXXXXX.json");
    QFile copia(temporal);
    if (!copia.open(QIODevice::WriteOnly)) {
        emit actionFailed(tr("No se pudo preparar el archivo temporal"));
        return false;
    }
    copia.write(contenido);
    copia.close();

    QProcess proceso;
    proceso.start(QStringLiteral("pkexec"),
                  {QStringLiteral("/bin/sh"), QStringLiteral("-c"),
                   QStringLiteral("install -m 644 %1 %2").arg(temporal, ruta)});
    if (!proceso.waitForFinished(60000) || proceso.exitStatus() != QProcess::NormalExit
        || proceso.exitCode() != 0) {
        QFile::remove(temporal);
        emit actionFailed(tr("No se pudo guardar la configuración del login"));
        return false;
    }
    QFile::remove(temporal);
    return true;
}

void LoginManagerService::loadCatalogo()
{
    m_widgets.clear();
    m_shortcuts.clear();
    m_variants.clear();

    QFile fichero(QString::fromLatin1(kCatalogo));
    if (!fichero.open(QIODevice::ReadOnly)) {
        // Sin catálogo instalado se ofrece lo mínimo para no dejar la página
        // vacía, pero se avisa: no se inventan widgets.
        emit actionFailed(tr("No se encontró el catálogo del login en %1")
                              .arg(QString::fromLatin1(kCatalogo)));
        return;
    }
    const QJsonDocument documento = QJsonDocument::fromJson(fichero.readAll());
    fichero.close();
    const QJsonObject raiz = documento.object();

    for (const QJsonValue &valor : raiz.value(QStringLiteral("widgets")).toArray()) {
        const QJsonObject objeto = valor.toObject();
        QVariantMap widget;
        widget.insert(QStringLiteral("id"), objeto.value(QStringLiteral("id")).toString());
        widget.insert(QStringLiteral("nombre"), objeto.value(QStringLiteral("nombre")).toString());
        widget.insert(QStringLiteral("columna"), objeto.value(QStringLiteral("columna")).toString());
        widget.insert(QStringLiteral("fuente"), objeto.value(QStringLiteral("fuente")).toString());
        widget.insert(QStringLiteral("requiere"), objeto.value(QStringLiteral("requiere")).toString());
        widget.insert(QStringLiteral("sinDatos"), objeto.value(QStringLiteral("sin_datos")).toString());
        widget.insert(QStringLiteral("nota"), objeto.value(QStringLiteral("nota")).toString());
        widget.insert(QStringLiteral("porDefecto"), objeto.value(QStringLiteral("por_defecto")).toBool());
        m_widgets.append(widget);
    }
    for (const QJsonValue &valor : raiz.value(QStringLiteral("atajos")).toArray()) {
        const QJsonObject objeto = valor.toObject();
        QVariantMap atajo;
        atajo.insert(QStringLiteral("id"), objeto.value(QStringLiteral("id")).toString());
        atajo.insert(QStringLiteral("nombre"), objeto.value(QStringLiteral("nombre")).toString());
        atajo.insert(QStringLiteral("descripcion"), objeto.value(QStringLiteral("descripcion")).toString());
        atajo.insert(QStringLiteral("fuente"), objeto.value(QStringLiteral("fuente")).toString());
        atajo.insert(QStringLiteral("porDefecto"), objeto.value(QStringLiteral("por_defecto")).toBool());
        m_shortcuts.append(atajo);
    }

    // Variantes de composición: las tres que puede elegir el usuario.
    const QVariantList completa = {QStringLiteral("clima"), QStringLiteral("proximo-evento"),
                                   QStringLiteral("reproduccion"), QStringLiteral("sistema"),
                                   QStringLiteral("calendario"), QStringLiteral("recordatorios"),
                                   QStringLiteral("atajos")};
    const QVariantList sencilla = {QStringLiteral("sistema"), QStringLiteral("calendario"),
                                   QStringLiteral("atajos")};
    for (const auto &definicion :
         QVariantList{QVariantMap{{QStringLiteral("id"), QStringLiteral("completa")},
                                  {QStringLiteral("nombre"), QStringLiteral("Completa")},
                                  {QStringLiteral("descripcion"),
                                   QStringLiteral("Los siete widgets del prototipo: clima, evento, "
                                                  "música, sistema, calendario, recordatorios y atajos.")},
                                  {QStringLiteral("widgets"), completa}},
                      QVariantMap{{QStringLiteral("id"), QStringLiteral("sencilla")},
                                  {QStringLiteral("nombre"), QStringLiteral("Sencilla")},
                                  {QStringLiteral("descripcion"),
                                   QStringLiteral("Tres widgets: sistema, calendario y atajos.")},
                                  {QStringLiteral("widgets"), sencilla}},
                      QVariantMap{{QStringLiteral("id"), QStringLiteral("minima")},
                                  {QStringLiteral("nombre"), QStringLiteral("Mínima")},
                                  {QStringLiteral("descripcion"),
                                   QStringLiteral("Solo el reloj y el acceso, sin widgets.")},
                                  {QStringLiteral("widgets"), QVariantList{}}}}) {
        m_variants.append(definicion);
    }
    emit catalogoChanged();
}

bool LoginManagerService::setValue(const QString &ruta, const QVariant &valor)
{
    const QStringList partes = ruta.split(QLatin1Char('.'));
    if (partes.isEmpty()) {
        emit actionFailed(tr("Ruta de configuración vacía"));
        return false;
    }

    // Validación de lo que puede romper el login.
    if (ruta == QLatin1String("apariencia.color_primario")) {
        const QColor color(valor.toString());
        if (!color.isValid()) {
            emit actionFailed(tr("Color no válido: %1").arg(valor.toString()));
            return false;
        }
    }
    if (ruta == QLatin1String("composicion.tamano_reloj")
        || ruta == QLatin1String("composicion.tamano_bloque_acceso")) {
        const double escala = valor.toDouble();
        if (escala < 0.6 || escala > 1.6) {
            emit actionFailed(tr("La escala debe estar entre 60 % y 160 %"));
            return false;
        }
    }
    if (ruta == QLatin1String("composicion.posicion_paneles")) {
        const QString posicion = valor.toString();
        if (posicion != QLatin1String("clasica") && posicion != QLatin1String("espejo")
            && posicion != QLatin1String("solo-centro")) {
            emit actionFailed(tr("Posición de paneles no válida: %1").arg(posicion));
            return false;
        }
    }

    QVariantMap seccion = m_settings.value(partes.first()).toMap();
    if (partes.size() == 1) {
        m_settings.insert(partes.first(), valor);
    } else if (partes.size() == 2) {
        seccion.insert(partes.at(1), valor);
        m_settings.insert(partes.first(), seccion);
    } else {
        emit actionFailed(tr("Ruta de configuración no admitida: %1").arg(ruta));
        return false;
    }

    if (!saveSettings()) {
        loadSettings();  // se recupera el estado real del disco
        return false;
    }
    emit settingsChanged();
    return true;
}

bool LoginManagerService::setBackground(const QString &origen)
{
    const QFileInfo info(origen);
    if (!info.isFile()) {
        emit actionFailed(tr("El archivo de fondo no existe: %1").arg(origen));
        return false;
    }
    // Se copia al catálogo del login: el greeter no puede leer /home.
    const QString carpeta = rutaDeTrabajo(QString::fromLatin1(kCarpetaFondos));
    QDir().mkpath(carpeta);
    const QString destino = carpeta + QLatin1Char('/') + info.fileName();
    QFile::remove(destino);
    if (!QFile::copy(origen, destino)) {
        // Puede faltar permiso de escritura en el sistema instalado.
        QProcess proceso;
        proceso.start(QStringLiteral("pkexec"),
                      {QStringLiteral("install"), QStringLiteral("-Dm644"), origen, destino});
        if (!proceso.waitForFinished(60000) || proceso.exitCode() != 0) {
            emit actionFailed(tr("No se pudo copiar el fondo al catálogo del login"));
            return false;
        }
    } else {
        QFile::setPermissions(destino, QFile::ReadOwner | QFile::ReadGroup
                                           | QFile::ReadOther | QFile::WriteOwner);
    }
    return setValue(QStringLiteral("apariencia.fondo_seleccionado"), destino);
}

bool LoginManagerService::setWidgetEnabled(const QString &id, bool activo)
{
    QVariantMap elegidos;
    const QVariantMap actuales = m_settings.value(QStringLiteral("widgets")).toMap();
    QStringList izquierda;
    QStringList derecha;
    for (const QVariant &valor : actuales.value(QStringLiteral("columna_izquierda")).toList())
        izquierda << valor.toString();
    for (const QVariant &valor : actuales.value(QStringLiteral("columna_derecha")).toList())
        derecha << valor.toString();

    // La columna la decide el catálogo: el usuario no tiene que saber dónde va.
    QString columna;
    for (const QVariant &valor : m_widgets) {
        const QVariantMap widget = valor.toMap();
        if (widget.value(QStringLiteral("id")).toString() == id) {
            columna = widget.value(QStringLiteral("columna")).toString();
            break;
        }
    }
    if (columna.isEmpty()) {
        emit actionFailed(tr("Widget desconocido: %1").arg(id));
        return false;
    }

    QStringList &lista = (columna == QLatin1String("derecha")) ? derecha : izquierda;
    if (activo && !lista.contains(id))
        lista << id;
    else if (!activo)
        lista.removeAll(id);

    QVariantList nuevaIzquierda;
    QVariantList nuevaDerecha;
    for (const QString &elemento : izquierda)
        nuevaIzquierda << elemento;
    for (const QString &elemento : derecha)
        nuevaDerecha << elemento;

    elegidos.insert(QStringLiteral("columna_izquierda"), nuevaIzquierda);
    elegidos.insert(QStringLiteral("columna_derecha"), nuevaDerecha);
    m_settings.insert(QStringLiteral("widgets"), elegidos);
    if (!saveSettings()) {
        loadSettings();
        return false;
    }
    emit settingsChanged();
    return true;
}

bool LoginManagerService::setShortcutEnabled(const QString &id, bool activo)
{
    const QVariantMap actuales = m_settings.value(QStringLiteral("atajos")).toMap();
    QStringList activos;
    for (const QVariant &valor : actuales.value(QStringLiteral("activos")).toList())
        activos << valor.toString();

    if (activo) {
        if (activos.contains(id))
            return true;
        if (activos.size() >= maximumShortcuts()) {
            emit actionFailed(tr("El login admite %1 atajos como máximo: quita uno antes de añadir otro")
                                  .arg(maximumShortcuts()));
            return false;
        }
        activos << id;
    } else {
        activos.removeAll(id);
    }

    QVariantList lista;
    for (const QString &elemento : activos)
        lista << elemento;
    QVariantMap nuevos = actuales;
    nuevos.insert(QStringLiteral("activos"), lista);
    nuevos.insert(QStringLiteral("maximo"), maximumShortcuts());
    m_settings.insert(QStringLiteral("atajos"), nuevos);
    if (!saveSettings()) {
        loadSettings();
        return false;
    }
    emit settingsChanged();
    return true;
}

bool LoginManagerService::applyVariant(const QString &nombre)
{
    static const QHash<QString, QPair<QStringList, QStringList>> variantes{
        {QStringLiteral("completa"),
         {{QStringLiteral("clima"), QStringLiteral("proximo-evento"),
           QStringLiteral("reproduccion"), QStringLiteral("sistema")},
          {QStringLiteral("calendario"), QStringLiteral("recordatorios"),
           QStringLiteral("atajos")}}},
        {QStringLiteral("sencilla"),
         {{QStringLiteral("sistema")}, {QStringLiteral("calendario"), QStringLiteral("atajos")}}},
        {QStringLiteral("minima"), {{}, {}}},
    };
    if (!variantes.contains(nombre)) {
        emit actionFailed(tr("Variante desconocida: %1").arg(nombre));
        return false;
    }

    const auto &definicion = variantes.value(nombre);
    QVariantMap widgets;
    QVariantList izquierda;
    QVariantList derecha;
    for (const QString &elemento : definicion.first)
        izquierda << elemento;
    for (const QString &elemento : definicion.second)
        derecha << elemento;
    widgets.insert(QStringLiteral("columna_izquierda"), izquierda);
    widgets.insert(QStringLiteral("columna_derecha"), derecha);
    m_settings.insert(QStringLiteral("widgets"), widgets);

    QVariantMap composicion = m_settings.value(QStringLiteral("composicion")).toMap();
    composicion.insert(QStringLiteral("variante"), nombre);
    composicion.insert(QStringLiteral("posicion_paneles"),
                       nombre == QLatin1String("minima") ? QStringLiteral("solo-centro")
                                                         : QStringLiteral("clasica"));
    m_settings.insert(QStringLiteral("composicion"), composicion);

    if (nombre == QLatin1String("minima")) {
        // Sin widgets no hay rejilla de atajos que mostrar.
        QVariantMap atajos = m_settings.value(QStringLiteral("atajos")).toMap();
        atajos.insert(QStringLiteral("activos"), QVariantList{});
        atajos.insert(QStringLiteral("maximo"), maximumShortcuts());
        m_settings.insert(QStringLiteral("atajos"), atajos);
    }

    if (!saveSettings()) {
        loadSettings();
        return false;
    }
    emit settingsChanged();
    emit actionDone(tr("Variante aplicada: %1").arg(nombre));
    return true;
}

bool LoginManagerService::resetToPrototype()
{
    m_settings = defaultSettings();
    if (!saveSettings()) {
        loadSettings();
        return false;
    }
    emit settingsChanged();
    emit actionDone(tr("Pantalla de acceso restablecida al prototipo"));
    return true;
}

bool LoginManagerService::capturePreview(const QString &destino)
{
    // La vista previa es una captura del login REAL, no un dibujo aparte: se
    // ejecuta el propio host del greeter en modo --preview.
    const QString host = rutaDeTrabajo(
        QStringLiteral("/usr/share/dylanos/login-manager/host/dylanos-login-greeter.py"));
    const QString greeter = rutaDeTrabajo(QString::fromLatin1(kGreeter));
    QString programa = QStandardPaths::findExecutable(QStringLiteral("python3"));
    QStringList argumentos;
    if (QFileInfo::exists(host)) {
        argumentos << host;
    } else if (QFileInfo::exists(greeter)) {
        programa = greeter;
    } else {
        emit actionFailed(tr("No se encontró el host del login"));
        return false;
    }
    argumentos << QStringLiteral("--preview") << QStringLiteral("--theme")
               << rutaDeTrabajo(QString::fromLatin1(kTema))
               << QStringLiteral("--size") << QStringLiteral("1440x960")
               << QStringLiteral("--screenshot") << destino;

    QProcess proceso;
    QProcessEnvironment entorno = QProcessEnvironment::systemEnvironment();
    entorno.insert(QStringLiteral("QT_QPA_PLATFORM"), QStringLiteral("offscreen"));
    entorno.insert(QStringLiteral("QTWEBENGINE_DISABLE_SANDBOX"), QStringLiteral("1"));
    entorno.insert(QStringLiteral("QTWEBENGINE_CHROMIUM_FLAGS"),
                   QStringLiteral("--no-sandbox --disable-gpu"));
    proceso.setProcessEnvironment(entorno);
    proceso.start(programa, argumentos);
    if (!proceso.waitForFinished(45000) || proceso.exitCode() != 0) {
        emit actionFailed(tr("No se pudo generar la vista previa: %1")
                              .arg(QString::fromUtf8(proceso.readAllStandardError()).trimmed()));
        return false;
    }
    if (!QFileInfo::exists(destino)) {
        emit actionFailed(tr("La vista previa no se generó"));
        return false;
    }
    emit previewReady(destino);
    return true;
}

void LoginManagerService::reload()
{
    loadCatalogo();
    loadSettings();
}
