"""Lectura de datos reales del sistema para el login de DylanOS.

Este módulo no importa Qt a propósito: lo usan el host del greeter (que además
habla el protocolo de SDDM), la vista previa de Configuration y los tests. Así
hay una sola fuente de verdad y no puede haber dos lecturas distintas.

Regla que se respeta en todo el módulo: si un dato no existe se devuelve vacío
o `None`, y el tema oculta el widget. Nunca se rellena con una cifra de
ejemplo.
"""
from __future__ import annotations

import json
import math
import os
import re
import shutil
import subprocess
import time
import urllib.error
import urllib.request
from pathlib import Path

AJUSTES = Path("/etc/dylanos/login-manager.json")
FOTOS = Path("/var/lib/dylanos/login-manager/fotos")
CATALOGO = Path("/usr/share/dylanos/login-manager/catalogo.json")
CACHE_CLIMA = Path("/var/cache/dylanos/login-manager/clima.json")


# --- configuración -------------------------------------------------------

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


def leer_catalogo() -> dict:
    """Catálogo de widgets y atajos instalado con el tema."""
    for ruta in (Path(os.environ.get("DYLANOS_LOGIN_CATALOGO") or CATALOGO),
                 Path(__file__).resolve().parents[3]
                 / "apps/dylanos-login-manager/catalog/catalogo.json"):
        try:
            return json.loads(ruta.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
    return {"atajos": [], "widgets": []}


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


# --- cuentas y fotos ----------------------------------------------------

def cuentas_del_sistema() -> list[dict]:
    """Usuarios reales con sesión interactiva, como los ve SDDM."""
    try:
        import pwd
    except ImportError:
        return []
    minimo, limite = 1000, 60000
    try:
        for linea in Path("/etc/login.defs").read_text(encoding="utf-8").splitlines():
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
            "nombre": (cuenta.pw_gecos or "").split(",")[0] or cuenta.pw_name,
            "casa": cuenta.pw_dir,
            "uid": cuenta.pw_uid,
        })
    usuarios.sort(key=lambda u: u["usuario"])
    return usuarios


def usuario_predeterminado(ajustes: dict, cuentas: list[dict]) -> str:
    """Cuenta que el login deja escrita al arrancar.

    Prioridad: la que fija la configuración, la del último acceso correcto y,
    si no hay ninguna, la primera cuenta interactiva.
    """
    predeterminado = str(ajustes.get("usuario_predeterminado") or "").strip()
    if predeterminado and any(c["usuario"] == predeterminado for c in cuentas):
        return predeterminado
    ultimo = str(ajustes.get("ultimo_usuario") or "").strip()
    if ultimo and any(c["usuario"] == ultimo for c in cuentas):
        return ultimo
    return cuentas[0]["usuario"] if cuentas else ""


def foto_del_usuario(usuario: str) -> str:
    """Foto de perfil del usuario, con prioridad a `~/.face`.

    El greeter corre como `sddm` y la carpeta personal suele ser 0700, así que
    no puede leer `~/.face` directamente. El helper publica una copia legible
    en `FOTOS/<usuario>`; si no existe se intenta el original. Nunca se
    devuelve una imagen inventada: sin foto, el tema dibuja su silueta.
    """
    if not usuario:
        return ""
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
    for candidato in (casa / ".face", casa / ".face.icon",
                      Path("/var/lib/AccountsService/icons") / usuario):
        try:
            if candidato.is_file() and os.access(candidato, os.R_OK):
                return candidato.as_uri() + "?v=" + str(int(candidato.stat().st_mtime))
        except OSError:
            continue
    return ""


# --- reloj --------------------------------------------------------------

DIAS = ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"]
MESES = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
         "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
INICIALES = ["D", "L", "M", "M", "J", "V", "S"]


def reloj(momento: float | None = None) -> dict:
    """Hora, fecha y calendario del mes, calculados en el instante de la llamada."""
    ahora = time.localtime(momento if momento is not None else time.time())
    hora24 = ahora.tm_hour
    hora12 = hora24 % 12 or 12
    return {
        "hora": "%02d" % hora12,
        "minuto": "%02d" % ahora.tm_min,
        "amPm": "PM" if hora24 >= 12 else "AM",
        "horaCorta": "%d:%02d %s" % (hora12, ahora.tm_min, "PM" if hora24 >= 12 else "AM"),
        "fecha": "%s, %02d de %s" % (DIAS[(ahora.tm_wday + 1) % 7], ahora.tm_mday,
                                     MESES[ahora.tm_mon - 1]),
        "mes": "%s %d" % (MESES[ahora.tm_mon - 1].capitalize(), ahora.tm_year),
        "diasSemana": INICIALES,
        "dias": _dias_del_mes(ahora.tm_year, ahora.tm_mon),
        "hoy": ahora.tm_mday - 1,  # índice dentro de `dias` (empieza en 1)
        "dia": ahora.tm_mday,
    }


def _dias_del_mes(anio: int, mes: int) -> list[int]:
    """Días del mes con la semana que empieza en domingo, como el prototipo.

    Se incluyen los días del mes anterior y del siguiente que completan la
    rejilla de 7 columnas: el prototipo los dibuja atenuados.
    """
    import calendar

    primer_dia = calendar.monthrange(anio, mes)[0]  # 0 = lunes
    # El prototipo empieza en domingo: se convierte el índice de Python.
    hueco = (primer_dia + 1) % 7
    dias: list[int] = []
    anterior = calendar.monthrange(anio - (1 if mes == 1 else 0),
                                   12 if mes == 1 else mes - 1)[1]
    for i in range(hueco, 0, -1):
        dias.append(anterior - i + 1)
    total = calendar.monthrange(anio, mes)[1]
    dias.extend(range(1, total + 1))
    siguiente = 1
    while len(dias) % 7 != 0 or len(dias) < 35:
        dias.append(siguiente)
        siguiente += 1
    return dias


# --- energía y almacenamiento -------------------------------------------

def estado_bateria() -> dict:
    """Batería real de `/sys/class/power_supply`; sin batería, vacío.

    No se inventa un 78 %: en un equipo de escritorio no hay batería y el
    anillo no debe pintarse.
    """
    base = Path("/sys/class/power_supply")
    if not base.is_dir():
        return {}
    for dispositivo in sorted(base.iterdir()):
        try:
            tipo = (dispositivo / "type").read_text(encoding="utf-8").strip()
        except OSError:
            continue
        if tipo != "Battery":
            continue
        try:
            capacidad = int((dispositivo / "capacity").read_text(encoding="utf-8").strip())
        except (OSError, ValueError):
            continue
        estado = ""
        try:
            estado = (dispositivo / "status").read_text(encoding="utf-8").strip().lower()
        except OSError:
            pass
        restante = _tiempo_restante(dispositivo, estado)
        return {"porcentaje": max(0, min(100, capacidad)),
                "cargando": estado in ("charging", "full"),
                "estado": estado, "restante": restante}
    return {}


def _tiempo_restante(dispositivo: Path, estado: str) -> str:
    """Duración legible de `energy_now`/`power_now` (o sus variantes en µAh)."""
    try:
        ahora = float((dispositivo / "energy_now").read_text(encoding="utf-8"))
        consumo = float((dispositivo / "power_now").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        try:
            ahora = float((dispositivo / "charge_now").read_text(encoding="utf-8"))
            consumo = float((dispositivo / "current_now").read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return ""
    if consumo <= 0 or ahora <= 0:
        return ""
    horas = ahora / consumo
    if estado in ("charging", "full"):
        return ""
    total = int(round(horas * 60))
    return "%dh %02dmin" % (total // 60, total % 60)


def almacenamiento(ruta: str = "/") -> dict:
    """Espacio libre real del sistema de ficheros que contiene `ruta`."""
    try:
        uso = shutil.disk_usage(ruta)
    except OSError:
        return {}
    libres = uso.free
    unidades = [("TB", 1000 ** 4), ("GB", 1000 ** 3), ("MB", 1000 ** 2)]
    for nombre, factor in unidades:
        if libres >= factor:
            valor = libres / factor
            texto = ("%d %s" % (round(valor), nombre) if valor >= 10
                     else ("%.1f %s" % (valor, nombre)))
            return {"libre": texto, "bytes": libres, "total": uso.total}
    return {"libre": "%d MB" % (libres / 1000 ** 2), "bytes": libres, "total": uso.total}


# --- red ----------------------------------------------------------------

def estado_red() -> dict:
    """Estado de red y adaptadores según el kernel y NetworkManager."""
    estado = {"wifiDisponible": False, "bluetoothDisponible": False,
              "wifi": False, "bluetooth": False, "ssid": "", "redes": [],
              "dispositivoBluetooth": ""}
    try:
        estado["wifiDisponible"] = any(
            (Path("/sys/class/net") / n / "wireless").exists()
            for n in os.listdir("/sys/class/net"))
    except OSError:
        pass
    try:
        bluetooth = Path("/sys/class/bluetooth")
        estado["bluetoothDisponible"] = bluetooth.is_dir() and any(bluetooth.iterdir())
    except OSError:
        pass

    if shutil.which("nmcli"):
        salida = _ejecutar(["nmcli", "-t", "-f", "WIFI", "general"])
        if salida is not None:
            estado["wifi"] = salida.strip().lower() == "enabled"
        salida = _ejecutar(["nmcli", "-t", "-f", "IN-USE,SSID", "device", "wifi"])
        if salida:
            for linea in salida.splitlines():
                if linea.startswith("*") and ":" in linea:
                    estado["ssid"] = linea.split(":", 1)[1]
                    break
        salida = _ejecutar(["nmcli", "-t", "-f", "SSID,SIGNAL", "device", "wifi", "list"])
        if salida:
            redes = {}
            for linea in salida.splitlines():
                partes = linea.split(":")
                if len(partes) >= 2 and partes[0]:
                    redes.setdefault(partes[0], partes[1])
            estado["redes"] = [{"ssid": k, "senal": v} for k, v in list(redes.items())[:8]]

    if shutil.which("bluetoothctl"):
        salida = _ejecutar(["bluetoothctl", "show"])
        if salida:
            estado["bluetooth"] = "Powered: yes" in salida
        salida = _ejecutar(["bluetoothctl", "devices", "Connected"])
        if salida:
            for linea in salida.splitlines():
                partes = linea.split(" ", 2)
                if len(partes) == 3:
                    estado["dispositivoBluetooth"] = partes[2]
                    break
    return estado


def _ejecutar(orden: list[str], timeout: int = 10) -> str | None:
    """Ejecuta un programa de solo lectura y devuelve su salida, o None."""
    try:
        resultado = subprocess.run(orden, capture_output=True, text=True,
                                   timeout=timeout, check=False)
    except (OSError, subprocess.SubprocessError):
        return None
    return resultado.stdout if resultado.returncode == 0 else None


# --- sesiones -----------------------------------------------------------

def sesiones_instaladas() -> list[dict]:
    """Sesiones de escritorio que ofrece el sistema (X11 y Wayland)."""
    sesiones = []
    for carpeta, tipo in ((Path("/usr/share/xsessions"), 1),
                          (Path("/usr/share/wayland-sessions"), 2)):
        if not carpeta.is_dir():
            continue
        for fichero in sorted(carpeta.glob("*.desktop")):
            nombre, visible = fichero.stem, True
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


def sesion_activa(ajustes: dict, sesiones: list[dict]) -> dict:
    """Sesión que se iniciará: la de la configuración o la primera real."""
    preferida = str(ajustes.get("sesion") or "").strip()
    for sesion in sesiones:
        if preferida and (sesion["fichero"] == preferida
                          or Path(sesion["fichero"]).name == preferida
                          or sesion["nombre"] == preferida):
            return sesion
    return sesiones[0] if sesiones else {"tipo": 1, "fichero": "", "nombre": ""}


# --- clima --------------------------------------------------------------

def clima(ajustes: dict) -> dict:
    """Clima real por open-meteo (abierto y sin clave), con caché de 30 min.

    Sin coordenadas configuradas no se consulta nada y el widget no aparece.
    Sin red se usa el último dato bueno; si nunca hubo, tampoco se inventa.
    """
    ubicacion = ajustes.get("clima") or {}
    try:
        latitud = float(ubicacion.get("latitud"))
        longitud = float(ubicacion.get("longitud"))
    except (TypeError, ValueError):
        return {}

    guardado = _leer_cache_clima()
    if guardado and _cache_vigente(guardado):
        return guardado.get("datos") or {}

    datos = _consultar_clima(latitud, longitud)
    if datos:
        _guardar_cache_clima({"instante": time.time(), "datos": datos})
        return datos
    return (guardado or {}).get("datos") or {}


def _leer_cache_clima() -> dict:
    try:
        return json.loads(CACHE_CLIMA.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def _cache_vigente(guardado: dict) -> bool:
    try:
        return (time.time() - float(guardado.get("instante", 0))) < 1800
    except (TypeError, ValueError):
        return False


def _guardar_cache_clima(datos: dict) -> None:
    try:
        CACHE_CLIMA.parent.mkdir(parents=True, exist_ok=True)
        CACHE_CLIMA.write_text(json.dumps(datos, ensure_ascii=False), encoding="utf-8")
    except OSError:
        pass


def _consultar_clima(latitud: float, longitud: float) -> dict:
    url = ("https://api.open-meteo.com/v1/forecast?latitude=%.4f&longitude=%.4f"
           "&current=temperature_2m,weather_code"
           "&daily=temperature_2m_max,temperature_2m_min,sunrise,sunset"
           "&forecast_days=5&timezone=auto" % (latitud, longitud))
    try:
        with urllib.request.urlopen(url, timeout=6) as respuesta:
            crudo = json.loads(respuesta.read().decode("utf-8"))
    except (OSError, ValueError, urllib.error.URLError):
        return {}

    actual = crudo.get("current") or {}
    diario = crudo.get("daily") or {}
    try:
        temperatura = round(float(actual.get("temperature_2m")))
    except (TypeError, ValueError):
        return {}
    maximos = diario.get("temperature_2m_max") or []
    minimos = diario.get("temperature_2m_min") or []
    fechas = diario.get("time") or []
    pronostico = []
    for i, fecha in enumerate(fechas[:5]):
        try:
            pronostico.append({
                "etiqueta": _dia_corto(fecha),
                "maxima": round(float(maximos[i])),
                "minima": round(float(minimos[i])),
            })
        except (IndexError, TypeError, ValueError):
            continue
    return {"temperatura": temperatura,
            "condicion": _condicion(actual.get("weather_code")),
            "pronostico": pronostico,
            "amanecer": _hora_iso((diario.get("sunrise") or [None])[0]),
            "atardecer": _hora_iso((diario.get("sunset") or [None])[0])}


def _hora_iso(valor: str | None) -> str:
    """«2026-11-23T06:52» → «6:52 AM»."""
    if not valor or "T" not in valor:
        return ""
    try:
        hh, mm = valor.split("T", 1)[1][:5].split(":")
        hora = int(hh) % 12 or 12
        return "%d:%s %s" % (hora, mm, "PM" if int(hh) >= 12 else "AM")
    except (ValueError, IndexError):
        return ""


def _dia_corto(fecha: str) -> str:
    """«2026-11-22» → «Dom», con los nombres del prototipo."""
    try:
        anio, mes, dia = (int(p) for p in fecha.split("-"))
        indice = (time.localtime(time.mktime((anio, mes, dia, 12, 0, 0, 0, 0, -1))).tm_wday + 1) % 7
        return DIAS[indice][:3]
    except (ValueError, OverflowError):
        return ""


def _condicion(codigo) -> str:
    """Código WMO de open-meteo al texto en español del prototipo."""
    try:
        codigo = int(codigo)
    except (TypeError, ValueError):
        return ""
    if codigo == 0:
        return "Despejado"
    if codigo in (1, 2):
        return "Parcialmente nublado"
    if codigo == 3:
        return "Nublado"
    if codigo in (45, 48):
        return "Niebla"
    if codigo in (51, 53, 55, 56, 57):
        return "Llovizna"
    if codigo in (61, 63, 65, 66, 67, 80, 81, 82):
        return "Lluvia"
    if codigo in (71, 73, 75, 77, 85, 86):
        return "Nieve"
    if codigo in (95, 96, 99):
        return "Tormenta"
    return ""


# --- agenda (.ics local) ------------------------------------------------

def proximo_evento(ajustes: dict) -> dict:
    """Próximo evento de un `.ics` local indicado en la configuración.

    Sin fichero no hay widget: el login no tiene calendario de sistema y no se
    inventa una reunión. Se ignoran los eventos ya terminados.
    """
    ruta = str((ajustes.get("agenda") or {}).get("ics") or "").strip()
    if not ruta:
        return {}
    try:
        texto = Path(ruta).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return {}

    eventos = []
    for bloque in re.findall(r"BEGIN:VEVENT(.*?)END:VEVENT", texto, re.S):
        inicio = _campo_ics(bloque, "DTSTART")
        fin = _campo_ics(bloque, "DTEND")
        resumen = _campo_ics(bloque, "SUMMARY")
        if not inicio or not resumen:
            continue
        instante = _fecha_ics(inicio)
        if instante is None:
            continue
        final = _fecha_ics(fin) if fin else instante + 3600
        if final < time.time():
            continue
        eventos.append((instante, resumen, instante, final))

    if not eventos:
        return {}
    eventos.sort(key=lambda e: e[0])
    instante, resumen, _, final = eventos[0]
    return {"titulo": resumen, "cuando": _cuando(instante, final)}


def _campo_ics(bloque: str, nombre: str) -> str:
    """Valor de un campo, resolviendo las líneas plegadas del formato."""
    patron = re.compile(r"^%s[^:]*:(.*)$" % nombre, re.M)
    hallado = patron.search(bloque)
    if not hallado:
        return ""
    valor = hallado.group(1)
    # RFC 5545: una línea que empieza por espacio o tabulador continúa la anterior.
    resto = bloque[hallado.end():]
    for linea in resto.splitlines():
        if linea[:1] in (" ", "\t"):
            valor += linea[1:]
        else:
            break
    return valor.replace("\\,", ",").replace("\\;", ";").strip()


def _fecha_ics(valor: str) -> float | None:
    """Convierte `20261122T100000Z` (o con zona local) a instante Unix."""
    limpio = valor.strip().rstrip("Z")
    try:
        if "T" in limpio:
            base = time.strptime(limpio.split("Z")[0], "%Y%m%dT%H%M%S")
        else:
            base = time.strptime(limpio, "%Y%m%d")
        return time.mktime(base)
    except ValueError:
        return None


def _cuando(inicio: float, fin: float) -> str:
    """«Hoy · 10:00 – 11:30» / «Mañana · …», como el prototipo."""
    hoy = time.localtime()
    dia_inicio = time.localtime(inicio)
    diferencia = (time.mktime((dia_inicio.tm_year, dia_inicio.tm_mon, dia_inicio.tm_mday,
                               0, 0, 0, 0, 0, -1))
                  - time.mktime((hoy.tm_year, hoy.tm_mon, hoy.tm_mday,
                                 0, 0, 0, 0, 0, -1))) / 86400
    if diferencia < 1:
        prefijo = "Hoy"
    elif diferencia < 2:
        prefijo = "Mañana"
    else:
        prefijo = "%s, %d de %s" % (DIAS[(dia_inicio.tm_wday + 1) % 7],
                                    dia_inicio.tm_mday, MESES[dia_inicio.tm_mon - 1])
    return "%s · %s – %s" % (prefijo, _hora(inicio), _hora(fin))


def _hora(instante: float) -> str:
    t = time.localtime(instante)
    hora = t.tm_hour % 12 or 12
    return "%d:%02d %s" % (hora, t.tm_min, "PM" if t.tm_hour >= 12 else "AM")


# --- reproducción (MPRIS) -----------------------------------------------

def reproduccion() -> dict:
    """Pista del reproductor MPRIS activo, si hay alguno.

    Antes de iniciar sesión normalmente no hay reproductor, así que el widget
    se oculta. Se consulta por D-Bus con `busctl`, que no necesita Python Qt.
    """
    if not shutil.which("busctl"):
        return {}
    salida = _ejecutar(["busctl", "--user", "--list", "--no-legend", "--no-pager"])
    if not salida:
        return {}
    reproductores = [linea.split()[0] for linea in salida.splitlines()
                     if linea.startswith("org.mpris.MediaPlayer2.")]
    for servicio in reproductores:
        reproduciendo = _propiedad_mpris(servicio, "PlaybackStatus")
        if reproduciendo != "Playing":
            continue
        metadatos = _propiedad_mpris(servicio, "Metadata")
        titulo = _titulo_mpris(metadatos)
        if not titulo:
            continue
        artista = _artista_mpris(metadatos)
        posicion = _propiedad_mpris(servicio, "Position")
        duracion = _duracion_mpris(metadatos)
        return {"titulo": titulo, "artista": artista,
                "posicion": posicion, "duracion": duracion}
    return {}


def _propiedad_mpris(servicio: str, propiedad: str) -> str:
    salida = _ejecutar(["busctl", "--user", "get-property", servicio,
                        "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player",
                        propiedad])
    return (salida or "").strip()


def _titulo_mpris(metadatos: str) -> str:
    hallado = re.search(r'"xesam:title"\s+variant\s+s\s+"((?:[^"\\]|\\.)*)"', metadatos)
    return _desescapar(hallado.group(1)) if hallado else ""


def _artista_mpris(metadatos: str) -> str:
    hallado = re.search(r'"xesam:artist"\s+variant\s+as\s+\d+\s+"((?:[^"\\]|\\.)*)"',
                        metadatos)
    return _desescapar(hallado.group(1)) if hallado else ""


def _duracion_mpris(metadatos: str) -> int:
    hallado = re.search(r'"mpris:length"\s+variant\s+x\s+(\d+)', metadatos)
    if not hallado:
        hallado = re.search(r'"mpris:length"\s+variant\s+t\s+(\d+)', metadatos)
    try:
        return int(int(hallado.group(1)) / 1000000) if hallado else 0
    except (TypeError, ValueError):
        return 0


def _desescapar(texto: str) -> str:
    return texto.replace('\\"', '"').replace("\\\\", "\\")


def _segundos_mpris(valor: str) -> int:
    """`Position` llega como `x 83000000` (µs) o `t 83000000`."""
    partes = valor.split()
    if len(partes) < 2:
        return 0
    try:
        return int(int(partes[1]) / 1000000)
    except ValueError:
        return 0


def _mmss(segundos: int) -> str:
    segundos = max(0, int(segundos))
    return "%d:%02d" % (segundos // 60, segundos % 60)


# --- sistema ------------------------------------------------------------

def carga_sistema() -> dict:
    """Carga media y tiempo encendido reales de `/proc`."""
    datos = {}
    try:
        campos = Path("/proc/loadavg").read_text(encoding="utf-8").split()
        datos["carga1"] = campos[0]
        datos["carga5"] = campos[1]
        datos["carga15"] = campos[2]
    except (OSError, IndexError):
        return {}
    try:
        segundos = int(float(Path("/proc/uptime").read_text(encoding="utf-8").split()[0]))
        dias, resto = divmod(segundos, 86400)
        horas, resto = divmod(resto, 3600)
        datos["encendido"] = ("%dd %dh" % (dias, horas) if dias
                              else "%dh %dmin" % (horas, resto // 60))
    except (OSError, ValueError, IndexError):
        datos["encendido"] = ""
    return datos


def memoria_sistema() -> dict:
    """Memoria en uso y disponible de `/proc/meminfo`.

    Se redondea al entero de GiB solo cuando el valor está cerca (misma regla
    que usa DylanOS Configuration): MemTotal recorta la memoria que reserva el
    firmware, así que 15,4 GiB se muestra como 16 GB y nunca como 15,4.
    """
    try:
        lineas = Path("/proc/meminfo").read_text(encoding="utf-8").splitlines()
    except OSError:
        return {}
    valores = {}
    for linea in lineas:
        partes = linea.split()
        if len(partes) >= 2 and partes[0].endswith(":"):
            try:
                valores[partes[0][:-1]] = int(partes[1])  # kB
            except ValueError:
                continue
    total = valores.get("MemTotal")
    disponible = valores.get("MemAvailable") or valores.get("MemFree")
    if not total or disponible is None:
        return {}
    return {"total": _gib(total), "disponible": _gib(disponible),
            "uso": max(0, min(100, round(100 * (total - disponible) / total)))}


def _gib(kilobytes: int) -> str:
    """kB → «8 GB» redondeando a la potencia de dos más cercana si procede."""
    gib = kilobytes / 1024 / 1024
    if gib < 1:
        return "%d MB" % round(gib * 1024)
    # Potencia de dos más cercana (2, 4, 8, 16…): MemTotal recorta la memoria
    # que reserva el firmware, así que 7,6 GiB se muestra como 8 GB.
    potencia = 2 ** round(__import__("math").log2(gib))
    if abs(gib - potencia) / potencia <= 0.10:
        return "%d GB" % potencia
    return "%d GB" % round(gib)


def sol(ajustes: dict) -> dict:
    """Salida y puesta de sol reales de la ubicación del clima (open-meteo)."""
    ubicacion = ajustes.get("clima") or {}
    try:
        latitud = float(ubicacion.get("latitud"))
        longitud = float(ubicacion.get("longitud"))
    except (TypeError, ValueError):
        return {}
    guardado = _leer_cache_clima()
    datos = guardado.get("datos") or {}
    if not datos:
        datos = _consultar_clima(latitud, longitud) or {}
    salida, puesta = datos.get("amanecer"), datos.get("atardecer")
    if not salida or not puesta:
        return {}
    return {"salida": salida, "puesta": puesta}


def informacion_sistema() -> dict:
    """Nombre y versión reales de la distribución y del equipo."""
    datos = {"distribucion": "DylanOS", "version": "", "equipo": os.uname().nodename}
    for ruta in (Path("/etc/dylanos-release"), Path("/etc/os-release")):
        try:
            texto = ruta.read_text(encoding="utf-8")
        except OSError:
            continue
        for linea in texto.splitlines():
            if "=" not in linea:
                continue
            clave, valor = linea.split("=", 1)
            valor = valor.strip().strip('"')
            if clave == "NAME":
                datos["distribucion"] = valor
            elif clave == "VERSION":
                datos["version"] = valor
        if datos["version"]:
            break
    return datos


# --- estado completo ----------------------------------------------------

def estado_sistema(usuario: str = "", equipo: str = "",
                   capacidades: dict | None = None,
                   momento: float | None = None) -> dict:
    """Todo lo que el tema necesita, con los datos reales de este equipo."""
    ajustes = leer_ajustes()
    cuentas = cuentas_del_sistema()
    activo = usuario or usuario_predeterminado(ajustes, cuentas)
    preferencias = leer_estado_usuario(activo) if activo else {}
    return {
        "usuario": activo,
        "nombre": next((c["nombre"] for c in cuentas if c["usuario"] == activo), activo),
        "cuentas": cuentas,
        "foto": foto_del_usuario(activo),
        "reloj": reloj(momento),
        "bateria": estado_bateria(),
        "almacenamiento": almacenamiento(),
        "red": estado_red(),
        "clima": clima(ajustes),
        "evento": proximo_evento(ajustes),
        "reproduccion": reproduccion(),
        "sistema": informacion_sistema(),
        "carga": carga_sistema(),
        "memoria": memoria_sistema(),
        "sol": sol(ajustes),
        "sesiones": sesiones_instaladas(),
        "capacidades": capacidades or {},
        "equipo": equipo,
        "preferencias": preferencias,
        "recordatorios": recordatorios(ajustes, preferencias),
        "zonaHoraria": time.tzname[0] if time.tzname else "",
    }


def recordatorios(ajustes: dict, preferencias: dict | None = None) -> list[dict]:
    """Recordatorios guardados por el usuario, máximo cuatro como el prototipo."""
    preferencias = preferencias or {}
    lista = preferencias.get("recordatorios")
    if not isinstance(lista, list):
        lista = (ajustes.get("recordatorios") or [])
    limpios = []
    for elemento in lista[:4]:
        if isinstance(elemento, str):
            limpios.append({"texto": elemento, "hecho": False})
        elif isinstance(elemento, dict) and elemento.get("texto"):
            limpios.append({"texto": str(elemento["texto"]),
                            "hecho": bool(elemento.get("hecho"))})
    return limpios


def datos_para_tema(estado: dict, ajustes: dict) -> dict:
    """Traduce el estado del sistema a las variables que lee el tema.

    Es el único punto donde se decide qué se dibuja y qué se oculta: el tema
    recibe `null` cuando no hay dato y no pinta el widget. Así la vista previa
    de Configuration y el login real no pueden discrepar.
    """
    deps = ajustes.get("apariencia") or {}
    composicion = ajustes.get("composicion") or {}
    reloj_datos = estado.get("reloj") or {}
    bateria = estado.get("bateria") or {}
    disco = estado.get("almacenamiento") or {}
    red = estado.get("red") or {}
    clima_datos = estado.get("clima") or {}
    evento = estado.get("evento") or {}
    reproduccion_datos = estado.get("reproduccion") or {}
    sistema = estado.get("sistema") or {}

    pronostico = clima_datos.get("pronostico") or []
    return {
        "Usuario": estado.get("nombre") or estado.get("usuario") or "",
        "Retrato": estado.get("foto") or "",
        "Hora": reloj_datos.get("hora", ""),
        "Minuto": reloj_datos.get("minuto", ""),
        "AmPm": reloj_datos.get("amPm", ""),
        "HoraCorta": reloj_datos.get("horaCorta", ""),
        "Fecha": reloj_datos.get("fecha", ""),
        "Mes": reloj_datos.get("mes", ""),
        "DiasSemana": reloj_datos.get("diasSemana") or [],
        "Dias": reloj_datos.get("dias") or [],
        "Hoy": reloj_datos.get("hoy", -1),
        # Clima: sin proveedor configurado no hay tarjeta.
        "Clima": ({"temperatura": clima_datos.get("temperatura"),
                   "condicion": clima_datos.get("condicion", ""),
                   "pronostico": pronostico} if clima_datos else None),
        "Evento": ({"titulo": evento.get("titulo", ""),
                    "cuando": evento.get("cuando", "")} if evento else None),
        "Reproduccion": ({"titulo": reproduccion_datos.get("titulo", ""),
                          "artista": reproduccion_datos.get("artista", ""),
                          "posicion": _mmss(_segundos_mpris(
                              reproduccion_datos.get("posicion") or "x 0")),
                          "duracion": _mmss(reproduccion_datos.get("duracion") or 0)}
                         if reproduccion_datos else None),
        # Sistema: cada fila existe solo si su dato existe.
        "Bateria": ({"porcentaje": bateria["porcentaje"],
                     "restante": bateria.get("restante", ""),
                     "cargando": bateria.get("cargando", False)}
                    if bateria and "porcentaje" in bateria else None),
        "Almacenamiento": disco.get("libre") or None,
        "Recordatorios": estado.get("recordatorios") or [],
        "Distribucion": sistema.get("distribucion", "DylanOS"),
        "Version": sistema.get("version", ""),
        "Equipo": estado.get("equipo") or sistema.get("equipo", ""),
        "ZonaHoraria": estado.get("zonaHoraria", ""),
        # Presentación: los valores por defecto son los del prototipo.
        "Fondo": deps.get("fondo_seleccionado") or "assets/fondo-seleccionado.png",
        "CrimsonGlass": bool(deps.get("crimson_glass", True)),
        "PosicionPaneles": composicion.get("posicion_paneles") or "clasica",
        "TamanoReloj": float(composicion.get("tamano_reloj") or 1.0),
        "TamanoAcceso": float(composicion.get("tamano_bloque_acceso") or 1.0),
        "Acento": deps.get("color_primario") or "#DC143C",
        "ModoOscuro": True,
        "NoMolestar": bool((estado.get("preferencias") or {}).get("no_molestar", False)),
        "WifiActivo": bool(red.get("wifi")),
        "BluetoothActivo": bool(red.get("bluetooth")),
        "WifiDisponible": bool(red.get("wifiDisponible")),
        "BluetoothDisponible": bool(red.get("bluetoothDisponible")),
        "Redes": red.get("redes") or [],
        "Ssid": red.get("ssid", ""),
        "Capacidades": estado.get("capacidades") or {},
        "Carga": estado.get("carga") or {},
        "Memoria": estado.get("memoria") or {},
        "Sol": estado.get("sol") or {},
        "SesionActiva": (estado.get("sesiones") or [{}])[0].get("nombre", ""),
        "AtajosPorDefecto": [a["id"] for a in (leer_catalogo().get("atajos") or [])
                             if a.get("por_defecto")],
    }
