"""Contrato de DylanOS Process: núcleo Rust real + interfaz QML del prototipo.

Comprueba tres cosas que no cubren ni `cargo test` ni los tests QML:

1. Que el núcleo no tenga datos simulados (nada de aleatoriedad ni constantes
   inventadas) y lea de verdad `/proc`, el tema de iconos y systemd.
2. Que la interfaz conserve la estructura y los colores del prototipo.
3. Que la app quede integrada en el build, el staging y el escritorio.

No requiere ni Rust ni Qt instalados: es una verificación de contrato estática.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "apps/dylanos-process"
CORE = APP / "core"
QML = APP / "qml"
README = APP / "README.dylanos.md"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


class ProcessCoreContractTests(unittest.TestCase):
    """El núcleo Rust debe leer el sistema, no inventarlo."""

    def test_el_crate_no_tiene_dependencias_externas(self):
        manifest = read(CORE / "Cargo.toml")
        # Sin dependencias: el ISO se compila con --offline dentro del chroot.
        bloque = manifest.split("[dependencies]", 1)
        self.assertEqual(len(bloque), 2, "Cargo.toml debe declarar [dependencies]")
        self.assertEqual(bloque[1].split("[", 1)[0].strip(), "",
                         "el núcleo no debe arrastrar dependencias externas")

    def test_el_nucleo_se_enlaza_como_libreria_estatica(self):
        manifest = read(CORE / "Cargo.toml")
        self.assertIn('crate-type = ["staticlib", "rlib"]', manifest)

    def test_lee_los_archivos_reales_de_proc(self):
        sampler = read(CORE / "src/sampler.rs")
        # Los archivos globales se leen por ruta literal; los de proceso se
        # construyen con format!("{pid}/stat"), así que se comprueban aparte.
        for archivo in ["meminfo", "loadavg", "uptime", "stat", "net/dev", "diskstats"]:
            self.assertIn(f'"{archivo}"', sampler,
                          f"el muestreador debe leer /proc/{archivo}")
        for archivo in ["stat", "status", "cmdline", "io"]:
            self.assertIn(f'"{{pid}}/{archivo}"', sampler,
                          f"el muestreador debe leer /proc/<pid>/{archivo}")

    def test_usa_getpwuid_para_usuarios_reales(self):
        users = read(CORE / "src/users.rs")
        self.assertIn("getpwuid_r", users)

    def test_usa_kill_y_setpriority_reales(self):
        self.assertIn("kill(pid", read(CORE / "src/signals.rs"))
        self.assertIn("setpriority", read(CORE / "src/priority.rs"))

    def test_resuelve_iconos_del_tema_instalado(self):
        icons = read(CORE / "src/icons.rs")
        self.assertIn("kdeglobals", icons)
        self.assertIn("index.theme", icons)
        self.assertIn("Inherits=", icons)
        # Nunca iconos embebidos: la ruta sale del tema del sistema.
        self.assertNotIn("data:image", icons)

    def test_los_servicios_se_leen_de_systemd(self):
        services = read(CORE / "src/services.rs")
        self.assertIn("systemctl", services)
        self.assertIn("list-units", services)
        self.assertIn('"start"', services)
        self.assertIn('"stop"', services)

    def test_no_hay_aleatoriedad_ni_datos_simulados(self):
        prohibidos = ["rand", "Math.random", "random()", "lorem", "placeholder",
                      "mock", "dummy", "fake", "simulado"]
        for archivo in CORE.rglob("src/**/*.rs"):
            texto = read(archivo).lower()
            for palabra in prohibidos:
                self.assertNotIn(palabra.lower(), texto,
                                 f"{archivo.name} no debe contener {palabra!r}")

    def test_las_etiquetas_de_estado_estan_en_espanol(self):
        sampler = read(CORE / "src/sampler.rs")
        for etiqueta in ["Ejecutando", "Suspendido", "Zombi", "Detenido"]:
            self.assertIn(etiqueta, sampler)


class ProcessUiContractTests(unittest.TestCase):
    """La interfaz debe conservar el prototipo y no usar datos falsos."""

    @classmethod
    def setUpClass(cls):
        cls.main = read(QML / "Main.qml")
        cls.theme = read(QML / "Theme.qml")
        cls.todos = {p.name: read(p) for p in QML.glob("*.qml")}

    def test_existen_las_cuatro_pestanas_del_prototipo(self):
        tabbar = read(QML / "TabBar.qml")
        for etiqueta in ["Procesos", "Rendimiento", "Aplicaciones", "Servicios"]:
            self.assertIn(f'qsTr("{etiqueta}")', tabbar)

    def test_la_ventana_es_frameless_como_el_resto_de_apps(self):
        self.assertIn("Qt.FramelessWindowHint", self.main)
        self.assertIn("startSystemMove()", read(QML / "TitleBar.qml"))

    def test_conserva_los_colores_del_prototipo(self):
        # Superficies y acento del prototipo, literalmente.
        for color in ["#111114", "#15151a", "#1b1b21", "#0d0d10", "#06060a",
                      "#e0293b", "#f3f3f5", "#9c9ca5", "#6b6b74",
                      "#32d74b", "#ff9f0a", "#ff453a", "#0a84ff"]:
            self.assertIn(color, self.theme, f"falta el color {color} del prototipo")

    def test_los_colores_de_ocho_digitos_son_aarrggbb(self):
        # Qt interpreta 8 dígitos como #AARRGGBB (alfa primero). Un alfa al
        # final dejaría la ventana casi transparente: el bug de la 1.0 beta.
        for match in re.finditer(r'"(#[0-9a-fA-F]{8})"', self.theme):
            valor = match.group(1)
            alfa = int(valor[1:3], 16)
            self.assertGreater(alfa, 0, f"{valor} tiene alfa cero")
            self.assertLess(alfa, 255, f"{valor} no es translúcido")

    def test_la_ventana_usa_el_tamanio_del_prototipo(self):
        self.assertIn("width: 1320", self.main)
        self.assertIn("height: 720", self.main)

    def test_ningun_componente_declara_colores_fuera_de_los_tokens(self):
        # Los colores viven en Theme; el resto usa Theme.* (más los literales
        # de blanco puro, velos y resaltados de hover).
        permitidos = {"#ffffff", "#0affffff", "#12ffffff", "#a6000000", "transparent"}
        for nombre, texto in self.todos.items():
            if nombre in {"Theme.qml"}:
                continue
            for match in re.finditer(r'"#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})"', texto):
                self.assertIn(match.group(0).strip('"'), permitidos,
                              f"{nombre} declara el color {match.group(0)} fuera de Theme")

    def test_no_quedan_datos_simulados_en_la_interfaz(self):
        for nombre, texto in self.todos.items():
            self.assertNotIn("Math.random", texto, f"{nombre} genera datos aleatorios")
            self.assertNotIn("1.342 hilos", texto, f"{nombre} conserva el literal simulado")

    def test_el_cierre_de_proceso_exige_confirmacion(self):
        pagina = read(QML / "ProcessesPage.qml")
        self.assertIn("confirming = true", pagina)
        self.assertIn("processController.terminateProcess", pagina)
        self.assertIn("processController.forceTerminateProcess", pagina)
        # El texto de confirmación debe nombrar el proceso.
        self.assertIn("¿Forzar la finalización de %1?", pagina)

    def test_los_iconos_salen_del_tema_no_de_letras(self):
        icono = read(QML / "ProcessIcon.qml")
        self.assertIn("iconPath", icono)
        self.assertIn("image://icon/", icono)

    def test_no_se_usa_dolphin_ni_discover(self):
        for nombre, texto in self.todos.items():
            self.assertNotIn("dolphin", texto.lower(), nombre)
            self.assertNotIn("plasma-discover", texto.lower(), nombre)


class ProcessIntegrationTests(unittest.TestCase):
    """Integración con build, staging, escritorio y documentación."""

    def test_el_build_compila_el_nucleo_rust_en_el_chroot(self):
        build = read(ROOT / "scripts/build.sh")
        self.assertIn("dylanos-src/dylanos-process", build)
        self.assertIn("cargo build --release --offline --locked", build)
        # rustc/cargo no deben quedar en el ISO.
        self.assertIn("apt-get -y purge rustc cargo", build)

    def test_el_build_corre_los_tests_de_interfaz(self):
        build = read(ROOT / "scripts/build.sh")
        self.assertIn("ctest --test-dir /tmp/dylanos-src/dylanos-process/build", build)

    def test_el_desktop_id_es_el_de_la_app(self):
        desktop = read(APP / "org.dylanos.process.desktop")
        self.assertIn("Exec=dylanos-process", desktop)
        self.assertIn("Icon=dylanos-process", desktop)
        self.assertIn("StartupWMClass=org.dylanos.process", desktop)

    def test_la_app_declara_su_app_id_wayland(self):
        main = read(APP / "src/main.cpp")
        self.assertIn('setDesktopFileName(QStringLiteral("org.dylanos.process"))', main)

    def test_stage_py_oculta_el_lanzador_upstream(self):
        stage = read(ROOT / "scripts/stage.py")
        self.assertIn("/usr/share/applications/org.kde.plasma-systemmonitor.desktop", stage)
        self.assertIn("apps/dylanos-process/org.dylanos.process.desktop", stage)

    def test_el_readme_documenta_el_reemplazo(self):
        readme = read(README)
        self.assertIn("Rust", readme)
        self.assertIn("Qt", readme)
        self.assertIn("plasma-systemmonitor", readme)
        self.assertIn("cargo test", readme)


if __name__ == "__main__":
    unittest.main()
