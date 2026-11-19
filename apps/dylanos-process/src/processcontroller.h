// Controlador de acciones reales: cerrar procesos y cambiar su prioridad.
//
// Toda respuesta proviene del kernel; el controlador nunca informa éxito sin
// comprobarlo, y traduce el error real a un mensaje en español.

#pragma once

#include <QObject>
#include <QString>

class ProcessController : public QObject
{
    Q_OBJECT

public:
    explicit ProcessController(QObject *parent = nullptr);

    // Termina el proceso con SIGTERM. Devuelve true si el kernel lo aceptó.
    Q_INVOKABLE bool terminateProcess(int pid);
    // Fuerza la terminación con SIGKILL.
    Q_INVOKABLE bool forceTerminateProcess(int pid);
    // Cambia la prioridad (0..3, como el selector del prototipo).
    Q_INVOKABLE bool setPriority(int pid, int level);
    // Nivel del selector que corresponde a un nice real.
    Q_INVOKABLE int priorityLevel(int nice) const;
    // Comprueba si el proceso sigue vivo.
    Q_INVOKABLE bool isAlive(int pid) const;

signals:
    // Resultado real de la acción: texto para la UI y si salió bien.
    void notice(const QString &text, bool success);
};
