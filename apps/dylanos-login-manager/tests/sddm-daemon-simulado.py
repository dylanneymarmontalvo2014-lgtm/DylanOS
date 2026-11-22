#!/usr/bin/env python3
"""Servidor que imita al daemon de SDDM para probar el greeter.

No autentica de verdad: su objetivo es verificar que el host habla el
protocolo correcto (orden de mensajes, tipos y serialización de la sesión)
sin necesitar root ni una TTY gráfica. Lo usan los tests; nunca se instala.
"""
from __future__ import annotations

import argparse
import os
import sys
import time
from pathlib import Path

from PySide6.QtCore import (QBuffer, QByteArray, QDataStream, QIODevice,
                            QObject, QTimer)
from PySide6.QtNetwork import QLocalServer, QLocalSocket

CONNECT, LOGIN, POWEROFF, REBOOT, SUSPEND, HIBERNATE, HYBRIDSLEEP = range(7)
HOSTNAME, CAPABILITIES, LOGINSUCCEEDED, LOGINFAILED, INFORMATION = range(5)

CAPACIDADES_COMPLETAS = 0x1 | 0x2 | 0x4 | 0x8 | 0x10


class Lector:
    """Mensajes completos sobre un socket local.

    Un QDataStream sobre un socket puede leer menos bytes de los que necesita;
    entonces el identificador queda en 0 y 0 es `Connect`, lo que producía un
    bucle de conexiones. Aquí se acumula y solo se consume un mensaje entero.

    `quint32` se escribe con 4 bytes big-endian, que es el formato de
    `quint32` en el flujo por defecto de Qt (el que usa SDDM). QString es
    longitud (4 bytes) + UTF-16.
    """

    def __init__(self, socket):
        self._socket = socket
        self._datos = bytearray()

    def recibir(self) -> None:
        # readAll() devuelve lo que haya pendiente y vacía el búfer del
        # socket; el acumulador es el que conserva los mensajes incompletos.
        while self._socket.bytesAvailable() > 0:
            trozo = bytes(self._socket.read(4096))
            if not trozo:
                break
            self._datos.extend(trozo)

    def disponible(self) -> int:
        return len(self._datos)

    def u32(self, vistazo: bool = False):
        if len(self._datos) < 4:
            return None
        valor = int.from_bytes(bytes(self._datos[:4]), "big")
        if vistazo:
            return valor
        del self._datos[:4]
        return valor

    def bytes_u32(self) -> int:
        return 4

    def cadena(self, vistazo: bool = False):
        if len(self._datos) < 4:
            return None
        largo = int.from_bytes(bytes(self._datos[:4]), "big")
        if largo == 0xFFFFFFFF:
            total = 4
            texto = ""
        else:
            total = 4 + largo
            if len(self._datos) < total:
                return None
            texto = bytes(self._datos[4:total]).decode("utf-16-be")
        if vistazo:
            return texto
        del self._datos[:total]
        return texto

    def mensaje_login_completo(self) -> bool:
        """True si hay un Login entero (identificador + 2 cadenas + tipo + cadena).

        Se recorre el mensaje contando bytes; si en algún punto falta, el
        mensaje aún no ha llegado completo y se espera al siguiente aviso.
        """
        datos = bytes(self._datos)
        pos = 4  # identificador
        for _ in range(2):  # usuario y contraseña
            if len(datos) < pos + 4:
                return False
            largo = int.from_bytes(datos[pos:pos + 4], "big")
            pos += 4
            if largo != 0xFFFFFFFF:
                if largo % 2:
                    return False
                if len(datos) < pos + largo:
                    return False
                pos += largo
        if len(datos) < pos + 4:
            return False
        pos += 4  # tipo de sesión
        if len(datos) < pos + 4:
            return False
        largo = int.from_bytes(datos[pos:pos + 4], "big")
        pos += 4
        if largo != 0xFFFFFFFF:
            if len(datos) < pos + largo:
                return False
            pos += largo
        return len(datos) >= pos


class Servidor(QObject):
    def __init__(self, nombre: str, usuario: str, clave: str, sesion: Path | None = None):
        super().__init__()
        self.usuario = usuario
        self.clave = clave
        self.sesion = sesion or Path("/usr/share/xsessions/plasmax11.desktop")
        self.recibidos: list[str] = []
        self.socket: QLocalSocket | None = None
        self.lector: Lector | None = None
        self.escritor: QDataStream | None = None

        QLocalServer.removeServer(nombre)
        self.servidor = QLocalServer(self)
        if not self.servidor.listen(nombre):
            print(f"No se pudo escuchar en {nombre}", file=sys.stderr)
            raise SystemExit(2)
        self.servidor.newConnection.connect(self._nueva)

    def _nueva(self) -> None:
        self.socket = self.servidor.nextPendingConnection()
        self.lector = Lector(self.socket)
        self.escritor = QDataStream(self.socket)
        self.escritor.setVersion(QDataStream.Qt_6_8)
        self.socket.readyRead.connect(self._leer)

    def _enviar_cadena(self, texto: str) -> None:
        datos = texto.encode("utf-16-be")
        self.socket.write(QByteArray(len(datos).to_bytes(4, "big") + datos))

    def _enviar(self, mensaje: int) -> None:
        # 4 bytes big-endian, el formato con el que SDDM identifica mensajes.
        datos = QByteArray(int(mensaje).to_bytes(4, "big"))
        self.socket.write(datos)

    def _leer(self) -> None:
        self.lector.recibir()
        while True:
            identificador = self.lector.u32(vistazo=True)
            if identificador is None:
                return
            if identificador == CONNECT:
                self.lector.u32()
                self.recibidos.append("Connect")
                self._enviar(HOSTNAME)
                self._enviar_cadena(os.uname().nodename)
                self._enviar(CAPABILITIES)
                self.socket.write(QByteArray(CAPACIDADES_COMPLETAS.to_bytes(4, "big")))
                self.socket.flush()
            elif identificador == LOGIN:
                if not self.lector.mensaje_login_completo():
                    return
                self.lector.u32()
                usuario = self.lector.cadena()
                clave = self.lector.cadena()
                tipo = self.lector.u32()
                fichero = self.lector.cadena()
                self.recibidos.append(f"Login:{usuario}:{tipo}:{Path(fichero).name}")
                if usuario == self.usuario and clave == self.clave:
                    self._enviar(LOGINSUCCEEDED)
                else:
                    self._enviar(LOGINFAILED)
                self.socket.flush()
            elif identificador in (POWEROFF, REBOOT, SUSPEND, HIBERNATE, HYBRIDSLEEP):
                accion = self.lector.u32()
                self.recibidos.append({POWEROFF: "PowerOff", REBOOT: "Reboot",
                                       SUSPEND: "Suspend", HIBERNATE: "Hibernate",
                                       HYBRIDSLEEP: "HybridSleep"}[accion])
                self.socket.flush()
                return
            else:
                self.recibidos.append(f"Desconocido:{identificador}")
                return

    def cerrar(self) -> None:
        self.servidor.close()
        QLocalServer.removeServer(self.servidor.fullServerName())


def main() -> int:
    from PySide6.QtCore import QCoreApplication

    parser = argparse.ArgumentParser(description="Daemon SDDM simulado")
    parser.add_argument("--socket", required=True)
    parser.add_argument("--usuario", default="dylan")
    parser.add_argument("--clave", default="dylanos")
    parser.add_argument("--segundos", type=float, default=6.0)
    args = parser.parse_args()

    aplicacion = QCoreApplication(sys.argv)
    servidor = Servidor(args.socket, args.usuario, args.clave)

    def terminar() -> None:
        print("RECIBIDO:", ",".join(servidor.recibidos) or "(nada)")
        servidor.cerrar()
        aplicacion.quit()

    QTimer.singleShot(int(args.segundos * 1000), terminar)
    return aplicacion.exec()


if __name__ == "__main__":
    raise SystemExit(main())
