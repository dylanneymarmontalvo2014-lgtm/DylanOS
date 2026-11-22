/**
 * DylanOS Configuration — servicio del login manager.
 *
 * Lee y escribe `/etc/dylanos/login-manager.json`, el fichero que consume el
 * greeter. La escritura es atómica (fichero temporal + renombrado) y pasa por
 * polkit: la aplicación corre como el usuario, no como root.
 *
 * También expone el catálogo de atajos y widgets del login y genera la vista
 * previa real: pide al host del greeter una captura con la configuración
 * actual, así lo que se ve en Configuration es exactamente lo que se verá al
 * arrancar. Si el host no puede ejecutarse, se informa y la vista previa
 * queda vacía; nunca se dibuja una maqueta distinta.
 */
#include "LoginManagerService.h"

#include <QColor>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QSaveFile>
#include <QSettings>
#include <QStandardPaths>
#include <QTimer>
#include <QVariantMap>

namespace {
const QString kAjustes = QStringLiteral("/etc/dylanos/login-manager.json");
const QString kCatalogo = QStringLiteral("/usr/share/dylanos/login-manager/catalogo.json");
const QString kPlantilla = QStringLiteral("/usr/share/dylanos/login-manager/variables.json");
const QString kHelper = QStringLiteral("/usr/bin/dylanos-login-helper");
const QString kGreeter = QStringLiteral("/usr/bin/dylanos-login-greeter");
const QString kTema = QStringLiteral("/usr/share/sddm/themes/DylanOS-Crimson/web");
const QString kNodoHub = QStringLiteral("/System/Session");
}  // namespace

LoginManagerService::LoginManagerService(QObject *parent)
    : QObject(parent)
{
    // Los cambios de otros programas (o del propio usuario) se reflejan solos.
    m_vigilancia = new QTimer(this);
    m_vigilancia->setInterval(1500);
    connect(m_vigilancia, &QTimer::timeout, this, [this] {
        const QDateTime escrito = QFileInfo(kAjustes).lastModified();
        if (escrito.isValid() && escrito != m_ultimaLectura) {
            m_ultimaLectura = escrito;
            emit settingsChanged();
        }
    });
    m_vigilancia->start();
    m_config = leerConfiguracion();
}

QVariantMap LoginManagerService::settings() const
{
    return m_config;
}

bool LoginManagerService::available() const
{
    return QFileInfo::exists(kGreeter) && QFileInfo::exists(kTema + QStringLiteral("/index.html"));
}

QVariantList LoginManagerService::shortcutCatalog() const
{
    return leerLista(QStringLiteral("atajos"));
}

QVariantList LoginManagerService::widgetCatalog() const
{
    return leerLista(QStringLiteral("widgets"));
}

QVariantList LoginManagerService::wallpapers() const
{
    QVariantList lista;
    const QStringList carpetas = {
        QStringLiteral("/usr/share/wallpapers"),
        QStringLiteral("/usr/share/backgrounds"),
        QStringLiteral("/usr/share/dylanos/wallpapers"),
        QDir::homePath() + QStringLiteral("/.local/share/wallpapers"),
    };
    for (const QString &carpeta : carpetas) {
        QDir dir(carpeta);
        if (!dir.exists())
            continue;
        const QStringList ficheros = dir.entryList({QStringLiteral("*.png"), QStringLiteral("*.jpg"),
                                                    QStringLiteral("*.jpeg"), QStringLiteral("*.webp")},
                                                   QDir::Files, QDir::Name);
        for (const QString &fichero : ficheros) {
            QVariantMap entrada;
            entrada[QStringLiteral("nombre")] = QFileInfo(fichero).completeBaseName();
            entrada[QStringLiteral("ruta")] = dir.absoluteFilePath(fichero);
            entrada[QStringLiteral("carpeta")] = QFileInfo(carpeta).fileName();
            lista.append(entrada);
        }
    }
    return lista;
}

QString LoginManagerService::fontFile() const
{
    return kTema + QStringLiteral("/fonts/inter-latin.woff2");
}

QString LoginManagerService::previewTarget() const
{
    return QDir::tempPath() + QStringLiteral("/dylanos-login-preview.png");
}

QVariantMap LoginManagerService::effective() const
{
    QVariantMap mapa;
    const QVariantMap apariencia = m_config.value(QStringLiteral("apariencia")).toMap();
    const QVariantMap composicion = m_config.value(QStringLiteral("composicion")).toMap();
    mapa[QStringLiteral("fondo")] = apariencia.value(QStringLiteral("fondo_seleccionado"),
                                                     QStringLiteral("assets/fondo-seleccionado.png"));
    mapa[QStringLiteral("crimsonGlass")] = apariencia.value(QStringLiteral("crimson_glass"), true);
    mapa[QStringLiteral("colorPrimario")] = apariencia.value(QStringLiteral("color_primario"),
                                                              QStringLiteral("#dc143c"));
    mapa[QStringLiteral("posicion")] = composicion.value(QStringLiteral("posicion_paneles"),
                                                          QStringLiteral("clasica"));
    mapa[QStringLiteral("escalaReloj")] = composicion.value(QStringLiteral("tamano_reloj"), 1.0);
    mapa[QStringLiteral("escalaAcceso")] = composicion.value(QStringLiteral("tamano_bloque_acceso"), 1.0);
    return mapa;
}

QVariantMap LoginManagerService::leerConfiguracion() const
{
    QVariantMap vacio;
    QFile fichero(kAjustes);
    if (fichero.open(QIODevice::ReadOnly)) {
        const QJsonDocument documento = QJsonDocument::fromJson(fichero.readAll());
        if (documento.isObject())
            return documento.object().toVariantMap();
    }
    // Sin fichero del sistema se parte de la plantilla del tema: así los
    // valores que ve el usuario son los reales del prototipo.
    QFile plantilla(kPlantilla);
    if (plantilla.open(QIODevice::ReadOnly)) {
        const QJsonDocument documento = QJsonDocument::fromJson(plantilla.readAll());
        if (documento.isObject())
            return documento.object().toVariantMap();
    }
    return vacio;
}

bool LoginManagerService::escribirConfiguracion(const QVariantMap &configuracion)
{
    const QByteArray contenido = QJsonDocument(QJsonObject::fromVariantMap(configuracion))
                                     .toJson(QJsonDocument::Indented);
    // Con permisos se escribe directo; sin ellos, polkit pide autorización.
    QSaveFile directo(kAjustes);
    if (directo.open(QIODevice::WriteOnly)) {
        directo.write(contenido);
        if (directo.commit()) {
            m_config = configuracion;
            m_ultimaLectura = QFileInfo(kAjustes).lastModified();
            emit settingsChanged();
            return true;
        }
    }

    const QString temporal = QDir::tempPath() + QStringLiteral("/dylanos-login-manager.json");
    QFile copia(temporal);
    if (!copia.open(QIODevice::WriteOnly)) {
        emit error(QStringLiteral("No se pudo preparar la configuración"));
        return false;
    }
    copia.write(contenido);
    copia.close();

    QProcess proceso;
    proceso.start(QStringLiteral("pkexec"), {QStringLiteral("/bin/sh"), QStringLiteral("-c"),
        QStringLiteral("install -d -m 755 /etc/dylanos && "
                       "install -m 644 '%1' '%2'").arg(temporal, kAjustes)});
    if (!proceso.waitForFinished(60000) || proceso.exitCode() != 0) {
        emit error(QStringLiteral("La configuración del login no se pudo guardar"));
        return false;
    }
    QFile::remove(temporal);
    m_config = configuracion;
    m_ultimaLectura = QFileInfo(kAjustes).lastModified();
    emit settingsChanged();
    return true;
}

bool LoginManagerService::setOption(const QString &seccion, const QString &clave,
                                    const QVariant &valor)
{
    if (seccion.isEmpty() || clave.isEmpty()) {
        emit error(QStringLiteral("Ajuste no válido"));
        return false;
    }
    QVariantMap configuracion = m_config;
    QVariantMap bloque = configuracion.value(seccion).toMap();
    bloque[clave] = valor;
    configuracion[seccion] = bloque;
    return escribirConfiguracion(configuracion);
}

bool LoginManagerService::setShortcuts(const QStringList &activos)
{
    // El prototipo dibuja una rejilla de dos columnas con cuatro atajos: el
    // límite no es una restricción arbitraria, es la composición.
    if (activos.size() > 4) {
        emit error(QStringLiteral("Solo se pueden elegir 4 atajos"));
        return false;
    }
    QVariantList lista;
    const QVariantList catalogo = shortcutCatalog();
    for (const QString &id : activos) {
        bool existe = false;
        for (const QVariant &entrada : catalogo) {
            if (entrada.toMap().value(QStringLiteral("id")).toString() == id) {
                existe = true;
                break;
            }
        }
        if (!existe) {
            emit error(QStringLiteral("Atajo desconocido: %1").arg(id));
            return false;
        }
        lista.append(id);
    }
    QVariantMap configuracion = m_config;
    QVariantMap atajos = configuracion.value(QStringLiteral("atajos")).toMap();
    atajos[QStringLiteral("activos")] = lista;
    atajos[QStringLiteral("maximo")] = 4;
    configuracion[QStringLiteral("atajos")] = atajos;
    return escribirConfiguracion(configuracion);
}

bool LoginManagerService::setRecordatorios(const QVariantList &lista)
{
    // Cuatro es el límite del prototipo: su panel dibuja como máximo cuatro
    // filas, y una quinta no cabría sin cambiar la composición.
    if (lista.size() > 4) {
        emit error(QStringLiteral("El login admite 4 recordatorios como máximo"));
        return false;
    }
    QVariantList limpia;
    for (const QVariant &entrada : lista) {
        const QVariantMap mapa = entrada.toMap();
        const QString texto = mapa.value(QStringLiteral("texto")).toString().trimmed();
        if (texto.isEmpty())
            continue;
        QVariantMap item;
        item[QStringLiteral("texto")] = texto;
        item[QStringLiteral("hecho")] = mapa.value(QStringLiteral("hecho"), false).toBool();
        limpia.append(item);
    }
    QVariantMap configuracion = m_config;
    configuracion[QStringLiteral("recordatorios")] = limpia;
    return escribirConfiguracion(configuracion);
}

bool LoginManagerService::setWidgets(const QStringList &izquierda, const QStringList &derecha)
{
    QVariantMap configuracion = m_config;
    QVariantMap widgets = configuracion.value(QStringLiteral("widgets")).toMap();
    widgets[QStringLiteral("columna_izquierda")] = izquierda;
    widgets[QStringLiteral("columna_derecha")] = derecha;
    configuracion[QStringLiteral("widgets")] = widgets;
    return escribirConfiguracion(configuracion);
}

bool LoginManagerService::setWallpaper(const QString &ruta)
{
    const QFileInfo info(ruta);
    if (!info.isFile() || !info.isReadable()) {
        emit error(QStringLiteral("No se puede leer ese fondo de pantalla"));
        return false;
    }
    const QStringList formatos = {QStringLiteral("png"), QStringLiteral("jpg"),
                                 QStringLiteral("jpeg"), QStringLiteral("webp")};
    if (!formatos.contains(info.suffix().toLower())) {
        emit error(QStringLiteral("Formato de imagen no admitido"));
        return false;
    }
    // La imagen se copia junto al tema: el greeter corre como `sddm` y no
    // puede leer la carpeta personal del usuario.
    const QString destinoCarpeta = QStringLiteral("/usr/share/dylanos/login-manager/fondos");
    const QString nombre = QStringLiteral("fondo-%1.%2")
                               .arg(QString::number(info.lastModified().toSecsSinceEpoch()),
                                    info.suffix().toLower());
    const QString destino = destinoCarpeta + QLatin1Char('/') + nombre;

    QProcess proceso;
    proceso.start(QStringLiteral("pkexec"), {QStringLiteral("/bin/sh"), QStringLiteral("-c"),
        QStringLiteral("install -d -m 755 '%1' && install -m 644 '%2' '%3'")
            .arg(destinoCarpeta, info.absoluteFilePath(), destino)});
    if (!proceso.waitForFinished(60000) || proceso.exitCode() != 0) {
        emit error(QStringLiteral("No se pudo copiar el fondo de pantalla"));
        return false;
    }
    return setOption(QStringLiteral("apariencia"), QStringLiteral("fondo_seleccionado"), destino);
}

bool LoginManagerService::reset()
{
    QVariantMap configuracion = m_config;
    QFile plantilla(kPlantilla);
    if (plantilla.open(QIODevice::ReadOnly)) {
        const QJsonDocument documento = QJsonDocument::fromJson(plantilla.readAll());
        if (documento.isObject())
            configuracion = documento.object().toVariantMap();
    }
    return escribirConfiguracion(configuracion);
}

QVariantList LoginManagerService::leerLista(const QString &clave) const
{
    QVariantList lista;
    QFile fichero(kCatalogo);
    if (!fichero.open(QIODevice::ReadOnly))
        return lista;
    const QJsonDocument documento = QJsonDocument::fromJson(fichero.readAll());
    if (!documento.isObject())
        return lista;
    const QJsonArray arreglo = documento.object().value(clave).toArray();
    for (const QJsonValue &valor : arreglo)
        lista.append(valor.toObject().toVariantMap());
    return lista;
}

bool LoginManagerService::refreshPreview(const QVariantMap &configuracion)
{
    if (!available()) {
        emit error(QStringLiteral("El login manager no está instalado en el sistema"));
        return false;
    }
    Q_UNUSED(configuracion)
    const QString destino = previewTarget();
    QFile::remove(destino);

    QProcess proceso;
    QStringList argumentos;
    argumentos << kGreeter << QStringLiteral("--preview")
               << QStringLiteral("--theme") << kTema
               << QStringLiteral("--screenshot") << destino
               << QStringLiteral("--size") << QStringLiteral("1440x960");
    QProcessEnvironment entorno = QProcessEnvironment::systemEnvironment();
    entorno.insert(QStringLiteral("QT_QPA_PLATFORM"), QStringLiteral("offscreen"));
    entorno.insert(QStringLiteral("QTWEBENGINE_DISABLE_SANDBOX"), QStringLiteral("1"));
    entorno.insert(QStringLiteral("QTWEBENGINE_CHROMIUM_FLAGS"),
                   QStringLiteral("--no-sandbox --disable-gpu --single-process"));
    proceso.setProcessEnvironment(entorno);
    proceso.start(QStringLiteral("python3"), argumentos);
    if (!proceso.waitForFinished(45000) || !QFileInfo::exists(destino)) {
        emit error(QStringLiteral("La vista previa no pudo generarse. "
                                  "El login seguirá usando la configuración guardada."));
        return false;
    }
    m_previsualizacion = destino;
    emit previewChanged();
    return true;
}

QString LoginManagerService::previewImage() const
{
    return m_previsualizacion;
}

QString LoginManagerService::previewUrl() const
{
    if (m_previsualizacion.isEmpty())
        return QString();
    return QUrl::fromLocalFile(m_previsualizacion).toString() + QStringLiteral("?v=")
        + QString::number(QFileInfo(m_previsualizacion).lastModified().toSecsSinceEpoch());
}

bool LoginManagerService::applyAccentColor()
{
    /**
     * El acento de DylanOS vive en `kdeglobals` (`General/AccentColor`). Si el
     * usuario elige «seguir el color de acento», el login usa ese mismo valor:
     * una sola fuente de verdad para todo el sistema.
     */
    // El acento puede estar en la configuración del usuario o en la del
    // sistema (instalaciones con ajustes globales).
    QString acento;
    const QStringList candidatos = {
        QDir::homePath() + QStringLiteral("/.config/kdeglobals"),
        QStringLiteral("/etc/xdg/kdeglobals"),
    };
    for (const QString &ruta : candidatos) {
        QSettings kdeglobals(ruta, QSettings::IniFormat);
        acento = kdeglobals.value(QStringLiteral("General/AccentColor")).toString();
        if (!acento.isEmpty())
            break;
    }
    if (acento.isEmpty() || !QColor::isValidColorName(acento)) {
        emit error(QStringLiteral("No hay un color de acento definido en DylanOS Configuration"));
        return false;
    }
    QVariantMap configuracion = m_config;
    QVariantMap apariencia = configuracion.value(QStringLiteral("apariencia")).toMap();
    apariencia[QStringLiteral("color_primario")] = QColor(acento).name();
    apariencia[QStringLiteral("seguir_color_de_acento")] = true;
    configuracion[QStringLiteral("apariencia")] = apariencia;
    return escribirConfiguracion(configuracion);
}
