"""Lectura de datos reales del sistema para el login.

Este módulo no importa Qt a propósito: lo usan tanto el host del greeter
(que además habla el protocolo de SDDM) como la vista previa, que solo
necesita los datos para dibujar el tema en un navegador. Así hay una única
fuente de verdad y la vista previa no puede mostrar algo distinto del login.

Regla que se respeta en todo el módulo: si un dato no existe, se devuelve
vacío o `None`. Nunca se rellena con una cifra de ejemplo.
"""
from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

AJUSTES = Path("/etc/dylanos/login-manager.json")
FOTOS = Path("/var/lib/dylanos/login-manager/fotos")


def leer_ajustes() -> dict:
    """Ajustes del sistema escritos por DylanOS Configuration.

    `DYLANOS_LOGIN_AJUSTES` permite apuntar a otro fichero en QA y en la vista
    previa: así se comprueba el resultado de una configuración sin tocar la
    del sistema.
    """
    ruta = Path(os.environ.get("DYLANOS_LOGIN_AJUSTES") or AJUSTES)
    try:
        return json.loads(ruta.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def leer_estado_usuario(usuario: str) -> dict:
    """Preferencias del propio usuario (tema, no molestar, atajos)."""
    try:
        import pwd
        casa = Path(pwd.getpwnam(usuario).pw_dir)
    except (KeyError, ImportError):
        return {}
    for candidato in (casa / ".local/state/dylanos/login-manager.json",
                      casa / ".config/dylanos/login-manager.json"):
        try:
            return json.loads(candidato.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
    return {}


def cuentas_del_sistema() -> list[dict]:
    """Usuarios reales con sesión interactiva, como los ve SDDM."""
    try:
        import pwd
    except ImportError:
        return []
    minimo, limite = 1000, 60000
    try:
        with open("/etc/login.defs", encoding="utf-8") as fichero:
            for linea in fichero:
                partes = linea.split()
                if len(partes) == 2 and partes[0] == "UID_MIN":
                    minimo = int(partes[1])
                elif len(partes) == 2 and partes[0] == "UID_MAX":
                    limite = int(partes[1])
    except (OSError, ValueError):
        pass

    usuarios = []
    for cuenta in pwd.getpwall():
        if not (minimo <= cuenta.pw_uid <= min(limite, 60000)):
            continue
        if cuenta.pw_shell.endswith(("nologin", "false")):
            continue
        usuarios.append({
            "usuario": cuenta.pw_name,
            "nombre": cuenta.pw_gecos.split(",")[0] or cuenta.pw_name,
            "casa": cuenta.pw_dir,
            "uid": cuenta.pw_uid,
        })
    usuarios.sort(key=lambda u: u["usuario"])
    return usuarios


def foto_del_usuario(usuario: str) -> str:
    """Foto de perfil del usuario, con prioridad a la copia publicada.

    El greeter corre como `sddm`, así que no puede leer `~/.face` (la carpeta
    personal suele ser 0700). El helper publica una copia legible en
    `FOTOS/<usuario>`; si no existe se intenta leer el original. Nunca se
    devuelve una imagen inventada: si no hay foto, el tema dibuja su icono.
    """
    publicada = FOTOS / usuario
    try:
        if publicada.is_file() and os.access(publicada, os.R_OK):
            return publicada.as_uri() + "?v=" + str(int(publicada.stat().st_mtime))
    except OSError:
        pass

    try:
        import pwd
        casa = Path(pwd.getpwnam(usuario).pw_dir)
    except (KeyError, ImportError):
        return ""
    candidatos = [casa / ".face", casa / ".face.icon",
                  Path("/var/lib/AccountsService/icons") / usuario]
    for candidato in candidatos:
        try:
            if candidato.is_file() and os.access(candidato, os.R_OK):
                return candidato.as_uri()
        except OSError:
            continue
    return ""


def sesiones_instaladas() -> list[dict]:
    """Sesiones de escritorio que ofrece el sistema (X11 y Wayland)."""
    sesiones = []
    for carpeta, tipo in ((Path("/usr/share/xsessions"), 1),
                          (Path("/usr/share/wayland-sessions"), 2)):
        if not carpeta.is_dir():
            continue
        for fichero in sorted(carpeta.glob("*.desktop")):
            nombre = fichero.stem
            visible = True
            try:
                for linea in fichero.read_text(encoding="utf-8", errors="replace").splitlines():
                    if linea.startswith("Name="):
                        nombre = linea.split("=", 1)[1].strip()
                    elif linea.startswith("NoDisplay=true"):
                        visible = False
            except OSError:
                pass
            if visible:
                sesiones.append({"tipo": tipo, "fichero": str(fichero), "nombre": nombre})
    return sesiones


def estado_bateria() -> dict:
    """Batería real desde /sys/class/power_supply."""
    base = Path("/sys/class/power_supply")
    try:
        fuentes = [base / n for n in os.listdir(base)]
    except OSError:
        return {"presente": False}
    for fuente in fuentes:
        try:
            if (fuente / "type").read_text().strip() != "Battery":
                continue
            capacidad = int((fuente / "capacity").read_text().strip())
            estado = (fuente / "status").read_text().strip()
        except (OSError, ValueError):
            continue
        # Se traduce el estado tal como lo publica el kernel, sin deducir uno
        # distinto: "Not charging" no es "descargando".
        etiquetas = {"Charging": "Cargando", "Discharging": "Descargando",
                     "Full": "Completa", "Not charging": "Sin carga",
                     "Unknown": "Desconocido"}
        detalle = etiquetas.get(estado, estado or "Desconocido")
        return {"presente": True, "porcentaje": capacidad, "estado": estado,
                "detalle": f"{detalle} · {capacidad}%"}
    return {"presente": False}


def formato_bytes(valor: int) -> str:
    unidades = ["B", "KB", "MB", "GB", "TB"]
    tamano = float(valor)
    for unidad in unidades:
        if tamano < 1024 or unidad == unidades[-1]:
            return f"{tamano:.0f} {unidad}"
        tamano /= 1024
    return f"{tamano:.0f} TB"


def estado_disco() -> dict:
    """Espacio libre real del sistema de ficheros raíz."""
    try:
        uso = os.statvfs("/")
    except OSError:
        return {}
    libre = uso.f_bavail * uso.f_frsize
    total = uso.f_blocks * uso.f_frsize
    if total == 0:
        return {}
    return {"texto": formato_bytes(libre), "libre": libre, "total": total,
            "porcentaje": round(100 * libre / total)}


def estado_teclado() -> dict:
    """Distribución configurada, leída de los ficheros del sistema."""
    for ruta in (Path("/etc/default/keyboard"), Path("/etc/vconsole.conf")):
        try:
            for linea in ruta.read_text(encoding="utf-8", errors="replace").splitlines():
                if linea.startswith(("XKBLAYOUT=", "LAYOUT=")):
                    valor = linea.split("=", 1)[1].strip().strip('"')
                    if valor:
                        return {"distribucion": valor, "disponible": True}
        except OSError:
            continue
    return {"distribucion": "", "disponible": False}


def version_sistema() -> str:
    for ruta in (Path("/etc/dylanos-release"), Path("/usr/lib/os-release")):
        try:
            for linea in ruta.read_text(encoding="utf-8", errors="replace").splitlines():
                if linea.startswith("PRETTY_NAME="):
                    return linea.split("=", 1)[1].strip().strip('"')
        except OSError:
            continue
    return ""


def _ejecutar(programa: str, argumentos: list[str], timeout: int = 10) -> str:
    import shutil
    if not shutil.which(programa):
        return ""
    try:
        resultado = subprocess.run([programa, *argumentos], capture_output=True,
                                   text=True, timeout=timeout, check=False)
        return resultado.stdout if resultado.returncode == 0 else ""
    except (OSError, subprocess.SubprocessError):
        return ""


def _leer_helper() -> dict:
    """Pregunta al helper privilegiado, si está instalado."""
    import shutil
    ruta = shutil.which("dylanos-login-helper") or "/usr/lib/dylanos/dylanos-login-helper"
    if not Path(ruta).is_file():
        return {}
    try:
        resultado = subprocess.run([ruta, "estado"], capture_output=True,
                                   text=True, timeout=15, check=False)
        if resultado.returncode == 0 and resultado.stdout.strip():
            return json.loads(resultado.stdout)
    except (OSError, ValueError, subprocess.SubprocessError):
        pass
    return {}


def estado_red() -> dict:
    """Estado real de la red, sin abrir sesión.

    Se apoya en el helper cuando existe (es el único que puede cambiar el
    estado) y, si no, en nmcli/bluetoothctl. Antes del login no hay agente de
    usuario, así que lo que se muestra es el estado del sistema.
    """
    datos = _leer_helper()
    estado = {"wifi": bool(datos.get("wifi")), "bluetooth": bool(datos.get("bluetooth")),
              "ssid": datos.get("ssid", ""), "redes": datos.get("redes", []),
              "bluetoothDispositivo": datos.get("bluetoothDispositivo", ""),
              "wifiDisponible": datos.get("wifiDisponible", False),
              "bluetoothDisponible": datos.get("bluetoothDisponible", False)}

    if not datos:
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

        salida = _ejecutar("nmcli", ["-t", "-f", "WIFI", "general"])
        if salida.strip():
            estado["wifi"] = salida.strip().lower() == "enabled"
        for linea in _ejecutar("nmcli", ["-t", "-f", "IN-USE,SSID", "device", "wifi"]).splitlines():
            if linea.startswith("*"):
                estado["ssid"] = linea.split(":", 1)[1] if ":" in linea else ""
        for linea in _ejecutar("nmcli", ["-t", "-f", "SSID,SIGNAL", "device", "wifi", "list"]).splitlines():
            partes = linea.split(":")
            if len(partes) >= 2 and partes[0]:
                estado["redes"].append({"ssid": partes[0], "senal": partes[1]})
        estado["redes"] = estado["redes"][:8]

        salida = _ejecutar("bluetoothctl", ["show"])
        if salida:
            estado["bluetooth"] = "Powered: yes" in salida
        conectados = _ejecutar("bluetoothctl", ["devices", "Connected"]).strip()
        if conectados:
            estado["bluetoothDispositivo"] = conectados.splitlines()[0].split(" ", 2)[-1]

    return estado


def mensaje_administrador(ajustes: dict, usuario: str) -> str:
    mensaje = ajustes.get("mensaje") or {}
    if not mensaje.get("texto"):
        return ""
    destinatario = (mensaje.get("usuario") or "").strip()
    if destinatario and destinatario != usuario:
        return ""
    return mensaje["texto"]


def nombre_visible(usuario: str, cuentas: list[dict]) -> str:
    for cuenta in cuentas:
        if cuenta["usuario"] == usuario:
            return cuenta["nombre"] or usuario
    return usuario or "Usuario"


def sesion_activa(ajustes: dict, sesiones: list[dict]) -> dict:
    """Sesión preseleccionada: la de ajustes o la primera disponible."""
    pedida = (ajustes.get("sesion") or "").strip()
    if pedida:
        for sesion in sesiones:
            if Path(sesion["fichero"]).stem == pedida or sesion["nombre"] == pedida:
                return sesion
    if sesiones:
        return sesiones[0]
    return {"tipo": 1, "fichero": "/usr/share/xsessions/plasmax11.desktop", "nombre": "Plasma"}


def usuario_predeterminado(ajustes: dict, cuentas: list[dict]) -> str:
    recordado = (ajustes.get("usuario") or "").strip()
    if recordado and any(u["usuario"] == recordado for u in cuentas):
        return recordado
    return cuentas[0]["usuario"] if cuentas else ""


def estado_sistema(usuario: str = "", equipo: str = "",
                   capacidades: dict | None = None) -> dict:
    """Estado completo que consume el tema."""
    ajustes = leer_ajustes()
    cuentas = cuentas_del_sistema()
    sesiones = sesiones_instaladas()
    elegido = usuario or usuario_predeterminado(ajustes, cuentas)
    return {
        "usuario": nombre_visible(elegido, cuentas),
        "usuarioId": elegido,
        "avatar": foto_del_usuario(elegido),
        "equipo": equipo or os.uname().nodename,
        "capacidades": capacidades or {"apagar": True, "reiniciar": True,
                                      "suspender": True, "hibernar": False,
                                      "hibrido": False},
        "sesiones": [{"nombre": s["nombre"], "fichero": s["fichero"]} for s in sesiones],
        "usuarios": cuentas,
        "red": estado_red(),
        "bateria": estado_bateria(),
        "almacenamiento": estado_disco(),
        "teclado": estado_teclado(),
        "version": version_sistema(),
        "mensajeAdmin": mensaje_administrador(ajustes, elegido),
        "clima": consultar_clima(),
        "evento": estado_evento(),
        "recordatorios": estado_recordatorios(),
        "preferencias": leer_estado_usuario(elegido) if elegido else {},
    }

# --- clima ---------------------------------------------------------------

CLIMA_CACHE = Path("/var/cache/dylanos/clima.json")
CLIMA_ESPERA = 4  # segundos; el login no puede quedarse esperando a la red

# Códigos WMO que devuelve open-meteo, agrupados como los entiende el tema.
CONDICIONES = {
    0: "Despejado", 1: "Mayormente despejado", 2: "Parcialmente nublado",
    3: "Nublado", 45: "Niebla", 48: "Niebla helada", 51: "Llovizna",
    53: "Llovizna", 55: "Llovizna fuerte", 56: "Llovizna helada",
    57: "Llovizna helada", 61: "Lluvia débil", 63: "Lluvia", 65: "Lluvia fuerte",
    66: "Lluvia helada", 67: "Lluvia helada", 71: "Nieve débil", 73: "Nieve",
    75: "Nieve fuerte", 77: "Granos de nieve", 80: "Chubascos",
    81: "Chubascos", 82: "Chubascos fuertes", 85: "Chubascos de nieve",
    86: "Chubascos de nieve", 95: "Tormenta", 96: "Tormenta con granizo",
    99: "Tormenta con granizo",
}
DIAS_ES = ["Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"]


def _clima_config() -> dict:
    """Proveedor de clima configurado (vacío si el usuario no eligió uno)."""
    return (leer_ajustes().get("clima") or {})


def _leer_cache_clima() -> dict:
    try:
        return json.loads(CLIMA_CACHE.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def _guardar_cache_clima(datos: dict) -> None:
    try:
        CLIMA_CACHE.parent.mkdir(parents=True, exist_ok=True)
        CLIMA_CACHE.write_text(json.dumps(datos, ensure_ascii=False), encoding="utf-8")
        CLIMA_CACHE.chmod(0o644)
    except OSError:
        pass


def consultar_clima(forzar: bool = False) -> dict:
    """Clima real de open-meteo, con caché en disco.

    Antes del login no hay proveedor propio ni clave de API: se usa
    open-meteo, que es abierto y no necesita registro. El resultado se guarda
    en `/var/cache/dylanos/clima.json` para que el greeter no dependa de la
    red al arrancar (un arranque sin red seguiría mostrando el último dato
    bueno). Sin configuración de ubicación no se consulta nada.
    """
    config = _clima_config()
    if not config.get("proveedor", "open-meteo"):
        return {}
    latitud, longitud = config.get("latitud"), config.get("longitud")
    if latitud is None or longitud is None:
        return {}

    cache = _leer_cache_clima()
    import time
    hace = time.time() - float(cache.get("momento", 0))
    if not forzar and cache.get("latitud") == latitud and cache.get("longitud") == longitud \
            and hace < 1800:
        return cache.get("datos", {})

    import urllib.parse
    import urllib.request
    consulta = urllib.parse.urlencode({
        "latitude": latitud, "longitude": longitud,
        "current": "temperature_2m,weather_code",
        "daily": "temperature_2m_max,temperature_2m_min,weather_code",
        "timezone": "auto", "forecast_days": 5,
    })
    url = "https://api.open-meteo.com/v1/forecast?" + consulta
    try:
        with urllib.request.urlopen(url, timeout=CLIMA_ESPERA) as respuesta:
            crudo = json.loads(respuesta.read().decode("utf-8"))
    except (OSError, ValueError):
        # Sin red se devuelve el último dato bueno, si existe.
        return cache.get("datos", {})

    actual = crudo.get("current") or {}
    diario = crudo.get("daily") or {}
    dias = diario.get("time") or []
    maximos = diario.get("temperature_2m_max") or []
    minimos = diario.get("temperature_2m_min") or []
    pronostico = []
    for indice, fecha in enumerate(dias[:5]):
        try:
            import datetime
            dia = datetime.date.fromisoformat(fecha)
        except (ValueError, TypeError):
            continue
        pronostico.append({
            "dia": DIAS_ES[(dia.weekday() + 1) % 7],
            "max": round(maximos[indice]) if indice < len(maximos) else None,
            "min": round(minimos[indice]) if indice < len(minimos) else None,
        })

    datos = {
        "temperatura": round(actual["temperature_2m"]) if actual.get("temperature_2m") is not None else None,
        "condicion": CONDICIONES.get(actual.get("weather_code"), "—"),
        "pronostico": pronostico,
        "lugar": config.get("lugar", ""),
    }
    if datos["temperatura"] is not None:
        _guardar_cache_clima({"momento": time.time(), "latitud": latitud,
                              "longitud": longitud, "datos": datos})
    return datos


def estado_evento() -> dict:
    """Próximo evento de un calendario .ics local, si el usuario lo indicó."""
    ruta = (leer_ajustes().get("calendario") or {}).get("ics")
    if not ruta:
        return {}
    import datetime
    try:
        texto = Path(ruta).expanduser().read_text(encoding="utf-8", errors="replace")
    except OSError:
        return {}

    ahora = datetime.datetime.now(datetime.timezone.utc)
    proximo = None
    for bloque in texto.split("BEGIN:VEVENT")[1:]:
        campos = {}
        for linea in bloque.splitlines():
            if linea.startswith(("DTSTART", "SUMMARY")):
                clave, _, valor = linea.partition(":")
                campos[clave.split(";")[0]] = valor.strip()
        inicio = campos.get("DTSTART")
        if not inicio or not campos.get("SUMMARY"):
            continue
        try:
            if inicio.endswith("Z"):
                cuando = datetime.datetime.strptime(inicio, "%Y%m%dT%H%M%SZ").replace(
                    tzinfo=datetime.timezone.utc)
            elif "T" in inicio:
                cuando = datetime.datetime.strptime(inicio, "%Y%m%dT%H%M%S").astimezone()
            else:
                cuando = datetime.datetime.strptime(inicio, "%Y%m%d").astimezone()
        except ValueError:
            continue
        if cuando < ahora:
            continue
        if proximo is None or cuando < proximo[0]:
            proximo = (cuando, campos["SUMMARY"])

    if not proximo:
        return {}
    cuando, titulo = proximo
    hora = cuando.astimezone().strftime("%H:%M")
    return {"titulo": titulo, "cuando": f"{DIAS_ES[(cuando.weekday() + 1) % 7]} · {hora}"}


def estado_recordatorios() -> list:
    """Recordatorios guardados para el login (los define la configuración)."""
    lista = leer_ajustes().get("recordatorios") or []
    if not isinstance(lista, list):
        return []
    salida = []
    for entrada in lista[:4]:
        if isinstance(entrada, str):
            salida.append({"texto": entrada, "hecho": False})
        elif isinstance(entrada, dict) and entrada.get("texto"):
            salida.append({"texto": entrada["texto"], "hecho": bool(entrada.get("hecho"))})
    return salida

