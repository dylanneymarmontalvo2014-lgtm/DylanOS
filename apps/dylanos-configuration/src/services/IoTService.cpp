#include "IoTService.h"

#include <QDir>
#include <QCoreApplication>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>
#include <QSettings>
#include <QTcpSocket>
#include <QSet>

IoTService::IoTService(QObject *parent) : QObject(parent)
{
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::ConfigLocation)
                       + QStringLiteral("/dylanos/iot.conf"), QSettings::IniFormat);
    m_profile = settings.value(QStringLiteral("profile"), m_profile).toString();
    m_enabled = settings.value(QStringLiteral("enabled"), false).toBool();
}

QString IoTService::dataPath(const QString &relative) const
{
    const QString override = qEnvironmentVariable("DYLANOS_IOT_DATA_PATH");
    if (!override.isEmpty()) return QDir(override).filePath(relative);
    const QString installed = QStringLiteral("/usr/share/dylanos/iot/") + relative;
    if (QFileInfo::exists(installed)) return installed;
#ifdef DYLANOS_IOT_SOURCE_DIR
    return QDir(QStringLiteral(DYLANOS_IOT_SOURCE_DIR)).filePath(relative);
#else
    return installed;
#endif
}

QString IoTService::statePath() const
{
    return QDir::homePath() + QStringLiteral("/.local/state/dylanos/iot/backup.json");
}

QVariantList IoTService::catalog() const
{
    QFile file(dataPath(QStringLiteral("catalog.json")));
    if (!file.open(QIODevice::ReadOnly)) return {};
    const auto root = QJsonDocument::fromJson(file.readAll()).object();
    QVariantList result;
    for (const auto &entry : root.value(QStringLiteral("apps")).toArray()) {
        auto app = entry.toObject().toVariantMap();
        const QString method = app.value(QStringLiteral("method")).toString();
        QStringList candidates;
        if (method == QStringLiteral("apt")) candidates = app.value(QStringLiteral("packages")).toStringList();
        else if (method == QStringLiteral("vscode-extension")) candidates = {QStringLiteral("code")};
        else candidates = app.value(QStringLiteral("binaries")).toStringList();
        bool installed = false;
        for (const auto &candidate : candidates) {
            if (QStandardPaths::findExecutable(candidate).size()) { installed = true; break; }
        }
        app.insert(QStringLiteral("installed"), installed);
        result.append(app);
    }
    return result;
}

QVariantList IoTService::profiles() const
{
    QDir dir(dataPath(QStringLiteral("profiles")));
    QVariantList result;
    for (const auto &name : dir.entryList({QStringLiteral("*.json")}, QDir::Files, QDir::Name)) {
        QFile file(dir.filePath(name));
        if (!file.open(QIODevice::ReadOnly)) continue;
        result.append(QJsonDocument::fromJson(file.readAll()).object().toVariantMap());
    }
    return result;
}

QVariantList IoTService::devices() const
{
    QVariantList result;
    QStringList paths;
    QDir byId(QStringLiteral("/dev/serial/by-id"));
    for (const auto &name : byId.entryList(QDir::System | QDir::Files, QDir::Name))
        paths.append(byId.filePath(name));
    QDir ports(QStringLiteral("/dev"));
    for (const auto &name : ports.entryList({QStringLiteral("ttyACM*"), QStringLiteral("ttyUSB*"), QStringLiteral("ttyAMA*")}, QDir::System | QDir::Files, QDir::Name))
        paths.append(ports.filePath(name));
    QSet<QString> seen;
    for (const auto &listedPath : paths) {
        const QString path = QFileInfo(listedPath).canonicalFilePath();
        if (path.isEmpty() || seen.contains(path)) continue;
        seen.insert(path);
        QFileInfo info(path);
        if (!info.exists()) continue;
        QString manufacturer;
        QString model;
        const QString devicePath = QFileInfo(QStringLiteral("/sys/class/tty/") + info.fileName() + QStringLiteral("/device")).canonicalFilePath();
        QDir sysfs(devicePath);
        for (int depth = 0; depth < 6 && !sysfs.absolutePath().startsWith(QStringLiteral("/sys/class")); ++depth) {
            QFile vendorFile(sysfs.filePath(QStringLiteral("manufacturer")));
            if (vendorFile.open(QIODevice::ReadOnly)) manufacturer = QString::fromUtf8(vendorFile.readAll()).trimmed();
            QFile productFile(sysfs.filePath(QStringLiteral("product")));
            if (productFile.open(QIODevice::ReadOnly)) model = QString::fromUtf8(productFile.readAll()).trimmed();
            if (!manufacturer.isEmpty() || !model.isEmpty()) break;
            if (!sysfs.cdUp()) break;
        }
        QVariantMap device{{QStringLiteral("port"), path}, {QStringLiteral("connected"), true},
                           {QStringLiteral("interface"), QStringLiteral("UART/serial")},
                           {QStringLiteral("manufacturer"), manufacturer}, {QStringLiteral("model"), model},
                           {QStringLiteral("rates"), QVariantList{9600, 19200, 38400, 57600, 115200}}};
        result.append(device);
    }
    return result;
}

QVariantMap IoTService::status() const
{
    auto probe = [](const QString &host, quint16 port) {
        QTcpSocket socket;
        socket.connectToHost(host, port);
        const bool connected = socket.waitForConnected(200);
        if (connected) socket.disconnectFromHost();
        return connected;
    };
    return {{QStringLiteral("enabled"), m_enabled}, {QStringLiteral("profile"), m_profile},
            {QStringLiteral("devices"), devices()}, {QStringLiteral("mqttLocal"), probe(QStringLiteral("127.0.0.1"), 1883)},
            {QStringLiteral("nodeRedLocal"), probe(QStringLiteral("127.0.0.1"), 1880)},
            {QStringLiteral("homeAssistantLocal"), probe(QStringLiteral("127.0.0.1"), 8123)}};
}

bool IoTService::save(const QString &profile, bool enabled) const
{
    const QString configPath = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation)
        + QStringLiteral("/dylanos/iot.conf");
    QDir().mkpath(QFileInfo(configPath).absolutePath());
    QSettings settings(configPath, QSettings::IniFormat);
    settings.setValue(QStringLiteral("profile"), profile);
    settings.setValue(QStringLiteral("enabled"), enabled);
    settings.sync();
    return settings.status() == QSettings::NoError;
}

bool IoTService::setProfile(const QString &id)
{
    bool known = false;
    for (const auto &profile : profiles()) if (profile.toMap().value(QStringLiteral("id")).toString() == id) known = true;
    if (!known || !save(id, m_enabled)) return false;
    m_profile = id;
    emit changed();
    return true;
}

bool IoTService::setEnabled(bool enabled)
{
    if (!QFileInfo::exists(statePath())) {
        QDir().mkpath(QFileInfo(statePath()).absolutePath());
        QFile backup(statePath());
        if (!backup.open(QIODevice::WriteOnly)) return false;
        backup.write(QJsonDocument(QJsonObject{{QStringLiteral("profile"), m_profile},
                                                {QStringLiteral("enabled"), m_enabled}}).toJson());
    }
    if (!save(m_profile, enabled)) return false;
    m_enabled = enabled;
    emit changed();
    return true;
}

bool IoTService::restore()
{
    QFile backup(statePath());
    if (!backup.open(QIODevice::ReadOnly)) return false;
    const auto previous = QJsonDocument::fromJson(backup.readAll()).object();
    const QString profile = previous.value(QStringLiteral("profile")).toString(QStringLiteral("iot-development"));
    const bool enabled = previous.value(QStringLiteral("enabled")).toBool(false);
    if (!save(profile, enabled)) return false;
    m_profile = profile;
    m_enabled = enabled;
    backup.remove();
    emit changed();
    return true;
}
