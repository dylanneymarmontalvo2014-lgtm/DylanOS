#!/usr/bin/env python3
"""Acciones privilegiadas del DylanOS Login Manager.

El greeter corre como el usuario `sddm`: puede autenticar a cualquiera, pero no
debe poder tocar la red ni el sistema. Este helper es la única pieza con
privilegios y solo acepta acciones de una lista cerrada, invocado por polkit.

Acciones:
  red <json>        Encender/apagar Wi-Fi y Bluetooth.
  foto <usuario>    Copiar ~/.face a una ruta legible por el greeter.
  estado            Devolver el estado de red y de los adaptadores.

Nunca ejecuta comandos arbitrarios ni acepta rutas del llamante.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

RUTA_FOTOS = Path("/var/lib/dylanos/login-manager/fotos")
USUARIO_GREETER = "sddm"


def _ejecutar(programa: str, argumentos: list[str], timeout: int = 20) -> bool:
    if not shutil.which(programa):
        return False
    try:
        resultado = subprocess.run([programa, *argumentos], capture_output=True,
                                   text=True, timeout=timeout, check=False)
        return resultado.returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def _estado_red() -> dict:
    estado = {"wifi": False, "bluetooth": False, "ssid": "", "redes": [],
              "bluetoothDispositivo": "", "wifiDisponible": False,
              "bluetoothDisponible": False}

    # Adaptadores presentes, según el kernel.
    try:
        estado["wifiDisponible"] = any(
            (Path("/sys/class/net") / nombre / "wireless").exists()
            for nombre in os.listdir("/sys/class/net"))
    except OSError:
        pass
    try:
        estado["bluetoothDisponible"] = Path("/sys/class/bluetooth").is_dir() and any(
            Path("/sys/class/bluetooth").iterdir())
    except OSError:
        pass

    # Estado por NetworkManager (nmcli es la interfaz estable).
    if shutil.which("nmcli"):
        try:
            salida = subprocess.run(["nmcli", "-t", "-f", "WIFI", "general"],
                                    capture_output=True, text=True, timeout=10)
            if salida.returncode == 0:
                estado["wifi"] = salida.stdout.strip().lower() == "enabled"
        except (OSError, subprocess.SubprocessError):
            pass
        try:
            salida = subprocess.run(["nmcli", "-t", "-f", "IN-USE,SSID", "device", "wifi"],
                                    capture_output=True, text=True, timeout=10)
            if salida.returncode == 0:
                for linea in salida.stdout.splitlines():
                    if linea.startswith("*"):
                        estado["ssid"] = linea.split(":", 1)[1] if ":" in linea else ""
        except (OSError, subprocess.SubprocessError):
            pass
        try:
            salida = subprocess.run(["nmcli", "-t", "-f", "SSID,SIGNAL", "device", "wifi", "list"],
                                    capture_output=True, text=True, timeout=10)
            if salida.returncode == 0:
                redes = []
                for linea in salida.stdout.splitlines():
                    partes = linea.split(":")
                    if len(partes) >= 2 and partes[0]:
                        redes.append({"ssid": partes[0], "senal": partes[1]})
                estado["redes"] = redes[:8]
        except (OSError, subprocess.SubprocessError):
            pass

    # Bluetooth por bluetoothctl.
    if shutil.which("bluetoothctl"):
        try:
            salida = subprocess.run(["bluetoothctl", "show"], capture_output=True,
                                    text=True, timeout=10)
            if salida.returncode == 0:
                estado["bluetooth"] = "Powered: yes" in salida.stdout
        except (OSError, subprocess.SubprocessError):
            pass
        try:
            salida = subprocess.run(["bluetoothctl", "devices", "Connected"],
                                    capture_output=True, text=True, timeout=10)
            if salida.returncode == 0 and salida.stdout.strip():
                estado["bluetoothDispositivo"] = salida.stdout.strip().splitlines()[0].split(" ", 2)[-1]
        except (OSError, subprocess.SubprocessError):
            pass

    return estado


def accion_red(datos: str) -> int:
    try:
        peticion = json.loads(datos)
    except ValueError:
        return 2
    if not isinstance(peticion, dict):
        return 2
    if not set(peticion) <= {"wifi", "bluetooth"}:
        return 2

    wifi = peticion.get("wifi")
    if isinstance(wifi, bool) and shutil.which("nmcli"):
        _ejecutar("nmcli", ["radio", "wifi", "on" if wifi else "off"])

    bluetooth = peticion.get("bluetooth")
    if isinstance(bluetooth, bool) and shutil.which("bluetoothctl"):
        _ejecutar("bluetoothctl", ["power", "on" if bluetooth else "off"])

    print(json.dumps(_estado_red(), ensure_ascii=False))
    return 0


def accion_estado() -> int:
    print(json.dumps(_estado_red(), ensure_ascii=False))
    return 0


def accion_foto(usuario: str) -> int:
    """Publica ~/.face en una carpeta legible por el greeter.

    La foto es del usuario: se copia, nunca se enlaza, para que el greeter no
    pueda leer por accidente el resto de su carpeta personal. La ruta de
    destino se deriva del nombre validado, jamás de una ruta del llamante.
    """
    if not usuario or "/" in usuario or usuario.startswith("."):
        return 2
    try:
        import pwd
        cuenta = pwd.getpwnam(usuario)
    except KeyError:
        return 3

    origen = Path(cuenta.pw_dir) / ".face"
    if not origen.is_file():
        origen = Path("/var/lib/AccountsService/icons") / usuario
    if not origen.is_file():
        print("", end="")
        return 4

    destino = RUTA_FOTOS / usuario
    try:
        RUTA_FOTOS.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(origen, destino)
        os.chmod(destino, 0o644)
        if os.geteuid() == 0:
            try:
                import grp
                grupo = grp.getgrnam(USUARIO_GREETER).gr_gid
            except KeyError:
                grupo = -1
            os.chown(destino, -1, grupo)
    except PermissionError:
        # Sin privilegios no se puede publicar la foto: se informa y se sigue.
        # El greeter mostrará el icono por defecto, nunca una imagen falsa.
        print("sin permiso para publicar la foto", file=sys.stderr)
        return 6
    except OSError as error:
        print(str(error), file=sys.stderr)
        return 5

    print(destino.as_uri())
    return 0


def main() -> int:
    if len(sys.argv) < 2:
        print("Uso: dylanos-login-helper red|estado|foto [valor]", file=sys.stderr)
        return 2

    accion = sys.argv[1]
    if accion == "estado":
        return accion_estado()
    if accion == "red" and len(sys.argv) == 3:
        return accion_red(sys.argv[2])
    if accion == "foto" and len(sys.argv) == 3:
        return accion_foto(sys.argv[2])
    print("Acción no permitida", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
