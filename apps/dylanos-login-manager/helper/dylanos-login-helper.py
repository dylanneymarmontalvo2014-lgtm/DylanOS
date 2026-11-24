#!/usr/bin/env python3
"""Acciones privilegiadas del DylanOS Login Manager.

El greeter corre como el usuario `sddm`: puede autenticar a cualquiera, pero no
debe poder tocar la red ni el sistema. Este helper es la única pieza con
privilegios y solo acepta acciones de una lista cerrada, invocado por polkit.

Acciones:
  red <json>        Encender/apagar Wi-Fi y Bluetooth.
  estado            Devolver el estado de red y de los adaptadores.
  foto <usuario>    Publicar ~/.face en una ruta legible por el greeter.
  sesiones          Listar las sesiones de escritorio instaladas.

Nunca ejecuta comandos arbitrarios ni acepta rutas del llamante: el usuario se
valida con `pwd` y las rutas se derivan de su carpeta personal.
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


def _ejecutar(programa: str, argumentos: list[str], timeout: int = 20) -> tuple[bool, str]:
    if not shutil.which(programa):
        return False, f"{programa} no está disponible"
    try:
        resultado = subprocess.run([programa, *argumentos], capture_output=True,
                                   text=True, timeout=timeout, check=False)
    except (OSError, subprocess.SubprocessError) as error:
        return False, str(error)
    if resultado.returncode != 0:
        return False, (resultado.stderr or resultado.stdout or "").strip()
    return True, resultado.stdout


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
        bluetooth = Path("/sys/class/bluetooth")
        estado["bluetoothDisponible"] = bluetooth.is_dir() and any(bluetooth.iterdir())
    except OSError:
        pass

    # Estado por NetworkManager (nmcli es la interfaz estable).
    ok, salida = _ejecutar("nmcli", ["-t", "-f", "WIFI", "general"])
    if ok:
        estado["wifi"] = salida.strip().lower() == "enabled"
    ok, salida = _ejecutar("nmcli", ["-t", "-f", "IN-USE,SSID", "device", "wifi"])
    if ok:
        for linea in salida.splitlines():
            if linea.startswith("*") and ":" in linea:
                estado["ssid"] = linea.split(":", 1)[1]
                break
    ok, salida = _ejecutar("nmcli", ["-t", "-f", "SSID,SIGNAL", "device", "wifi", "list"])
    if ok:
        redes: dict[str, str] = {}
        for linea in salida.splitlines():
            partes = linea.split(":")
            if len(partes) >= 2 and partes[0]:
                redes.setdefault(partes[0], partes[1])
        estado["redes"] = [{"ssid": k, "senal": v} for k, v in list(redes.items())[:8]]

    # Bluetooth por bluetoothctl.
    ok, salida = _ejecutar("bluetoothctl", ["show"])
    if ok:
        estado["bluetooth"] = "Powered: yes" in salida
    ok, salida = _ejecutar("bluetoothctl", ["devices", "Connected"])
    if ok:
        for linea in salida.splitlines():
            partes = linea.split(" ", 2)
            if len(partes) == 3:
                estado["bluetoothDispositivo"] = partes[2]
                break
    return estado


def _cambiar_red(peticion: dict) -> tuple[int, str]:
    """Aplica solo los campos permitidos; cualquier otro se rechaza."""
    desconocidos = set(peticion) - {"wifi", "bluetooth"}
    if desconocidos:
        return 2, "Campo no permitido: " + ",".join(sorted(desconocidos))

    errores = []
    if peticion.get("wifi") is not None:
        ok, salida = _ejecutar("nmcli", ["radio", "wifi", "on" if peticion["wifi"] else "off"])
        if not ok:
            errores.append("wifi: " + salida)
    if peticion.get("bluetooth") is not None:
        if peticion["bluetooth"]:
            ok, salida = _ejecutar("bluetoothctl", ["power", "on"])
            if not ok:
                ok, salida = _ejecutar("rfkill", ["unblock", "bluetooth"])
        else:
            ok, salida = _ejecutar("bluetoothctl", ["power", "off"])
            if not ok:
                ok, salida = _ejecutar("rfkill", ["block", "bluetooth"])
        if not ok:
            errores.append("bluetooth: " + salida)

    if errores:
        return 1, "; ".join(errores)
    return 0, json.dumps(_estado_red(), ensure_ascii=False)


def _publicar_foto(usuario: str) -> tuple[int, str]:
    """Copia la foto del usuario a una ruta que el greeter sí puede leer.

    Se comprueban los candidatos en el mismo orden que usa el tema. La copia es
    la única forma: `~/.face` suele estar en una carpeta 0700 que el usuario
    `sddm` no puede atravesar.
    """
    try:
        import pwd
        cuenta = pwd.getpwnam(usuario)
    except (KeyError, ImportError):
        return 2, f"El usuario no existe: {usuario}"

    casa = Path(cuenta.pw_dir)
    candidatos = [casa / ".face", casa / ".face.icon",
                  Path("/var/lib/AccountsService/icons") / usuario]
    origen = next((c for c in candidatos if c.is_file()), None)
    if origen is None:
        # Sin foto: se retira la copia anterior para que el tema dibuje su
        # silueta en vez de quedarse con una foto vieja.
        destino = RUTA_FOTOS / usuario
        try:
            destino.unlink(missing_ok=True)
        except OSError as error:
            return 1, str(error)
        return 0, ""

    RUTA_FOTOS.mkdir(parents=True, exist_ok=True)
    destino = RUTA_FOTOS / usuario
    try:
        shutil.copyfile(origen, destino)
    except OSError as error:
        return 1, str(error)
    # El fichero debe ser legible por el greeter y por nadie más.
    try:
        shutil.copymode(origen, destino)
        os.chmod(destino, 0o644)
        if os.geteuid() == 0:
            import grp
            try:
                grupo = grp.getgrnam(USUARIO_GREETER).gr_gid
                os.chown(destino, -1, grupo)
            except KeyError:
                pass
    except OSError as error:
        return 1, str(error)
    return 0, destino.as_uri()


def _sesiones() -> tuple[int, str]:
    sesiones = []
    for carpeta, tipo in (("/usr/share/xsessions", 1), ("/usr/share/wayland-sessions", 2)):
        directorio = Path(carpeta)
        if not directorio.is_dir():
            continue
        for fichero in sorted(directorio.glob("*.desktop")):
            nombre = fichero.stem
            try:
                for linea in fichero.read_text(encoding="utf-8", errors="replace").splitlines():
                    if linea.startswith("Name="):
                        nombre = linea.split("=", 1)[1].strip()
            except OSError:
                pass
            sesiones.append({"tipo": tipo, "fichero": str(fichero), "nombre": nombre})
    return 0, json.dumps(sesiones, ensure_ascii=False)


def main(argumentos: list[str]) -> int:
    if not argumentos:
        print(__doc__, file=sys.stderr)
        return 2

    accion = argumentos[0]
    if accion == "estado":
        print(json.dumps(_estado_red(), ensure_ascii=False))
        return 0
    if accion == "sesiones":
        codigo, salida = _sesiones()
        print(salida)
        return codigo
    if accion == "red":
        if len(argumentos) < 2:
            print("Falta el JSON de red", file=sys.stderr)
            return 2
        try:
            peticion = json.loads(argumentos[1])
        except ValueError:
            print("JSON inválido", file=sys.stderr)
            return 2
        if not isinstance(peticion, dict):
            print("Se esperaba un objeto JSON", file=sys.stderr)
            return 2
        codigo, salida = _cambiar_red(peticion)
        print(salida)
        if codigo:
            print(salida, file=sys.stderr)
        return codigo
    if accion == "foto":
        if len(argumentos) < 2:
            print("Falta el usuario", file=sys.stderr)
            return 2
        codigo, salida = _publicar_foto(argumentos[1])
        if salida:
            print(salida)
        return codigo

    print(f"Acción no permitida: {accion}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
