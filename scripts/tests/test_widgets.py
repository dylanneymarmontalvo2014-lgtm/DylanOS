"""Contratos de DylanOS Widgets: catálogo, retícula y layout inicial.

Cada aserción corresponde a un requisito del encargo que puede romperse en
silencio:

  - el catálogo debe tener al menos 20 widgets con contrato completo;
  - la retícula debe producir el Clima con exactamente el doble de ancho y
    la misma altura que un widget normal;
  - el layout por defecto solo puede aplicarse en sistema instalado, nunca
    en la sesión live, y solo una vez por usuario.

La librería JS se ejecuta con `node` (mismo enfoque que test_desktop.py con
el layout de Plasma) para no validar solo la sintaxis: se comprueba el
comportamiento real de las funciones.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from importlib.machinery import SourceFileLoader

ROOT = Path(__file__).resolve().parents[2]

layout = SourceFileLoader(
    "dylanos_widget_layout", str(ROOT / "scripts/dylanos-widget-layout")
).load_module()

CATALOG = ROOT / "apps/dylanos-widgets/qml/WidgetCatalog.js"
TOKENS = ROOT / "apps/dylanos-widgets-lib/WidgetTokens.js"

# Los plasmoides son autocontenidos: cada uno lleva una copia de la librería.
# Si las copias divergen, dos widgets del mismo escritorio se ven distintos.
# Todos los plasmoides de widgets: cada uno es autocontenido y lleva su copia
# de la librería. Se descubren del árbol para que añadir un widget no exija
# actualizar esta lista a mano.
VENDORED = tuple(sorted(
    path for path in ROOT.glob("apps/dylanos-widgets-*/contents/ui/lib")
    if path.is_dir()
))
WIDGET_APPS = tuple(sorted(
    path for path in ROOT.glob("apps/dylanos-widgets-*")
    if (path / "metadata.json").is_file()
))
VENDORED_FILES = ("WidgetTokens.js", "WidgetData.js", "WidgetCalc.js",
                  "WidgetCard.qml", "WidgetHeader.qml", "WidgetShell.qml",
                  "WidgetMeter.qml")


def read_catalog():
    """Extrae el catálogo ejecutándolo en node."""
    script = r'''
const fs = require("node:fs");
const vm = require("node:vm");
const src = fs.readFileSync(process.argv[1], "utf8").replace(/^\.pragma library\s*/, "");
const ctx = {};
vm.createContext(ctx);
vm.runInContext(src + "\n;this.api={entries,categories,roadmap,count,search,byCategory}", ctx);
process.stdout.write(JSON.stringify({
  entries: ctx.api.entries,
  categories: ctx.api.categories,
  roadmap: ctx.api.roadmap,
  count: ctx.api.count(),
  searchReloj: ctx.api.search("reloj").length,
  searchVacio: ctx.api.search("").length
}));
'''
    result = subprocess.run(
        ["node", "-e", script, str(CATALOG)],
        capture_output=True, text=True, check=True,
    )
    return json.loads(result.stdout)


@unittest.skipUnless(shutil.which("node"), "Node.js needed to execute the catalog")
class CatalogContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = read_catalog()

    def test_catalog_has_at_least_twenty_widgets(self):
        self.assertGreaterEqual(self.data["count"], 20)
        self.assertEqual(self.data["count"], len(self.data["entries"]))

    def test_every_entry_declares_the_full_contract(self):
        required = ("id", "applet", "name", "description", "category",
                    "sizes", "defaultSize", "dataSource", "status",
                    "inDefaultLayout")
        for entry in self.data["entries"]:
            with self.subTest(widget=entry.get("id")):
                for key in required:
                    self.assertIn(key, entry)
                self.assertTrue(entry["sizes"], "sin tamaños soportados")
                self.assertIn(entry["defaultSize"], entry["sizes"],
                              "el tamaño por defecto no está entre los soportados")
                self.assertIn(entry["status"], ("ready", "needs-pkg", "limited"))
                self.assertIn(entry["category"], self.data["categories"])
                # Sin red declarada no puede haber dependencia de red encubierta.
                self.assertIsInstance(entry["requiresNetwork"], bool)

    def test_declared_limits_are_explained(self):
        """Un widget limitado debe decir por qué, no solo estarlo."""
        for entry in self.data["entries"]:
            if entry["status"] in ("limited", "needs-pkg"):
                with self.subTest(widget=entry["id"]):
                    self.assertTrue(entry.get("limit"),
                                    "el límite no está documentado en el catálogo")

    def test_default_layout_is_clock_calendar_weather(self):
        defaults = [e for e in self.data["entries"] if e["inDefaultLayout"]]
        self.assertEqual([e["id"] for e in defaults],
                         ["clock", "calendar", "weather"])
        # Los tres del layout inicial deben ser implementables ya.
        for entry in defaults:
            self.assertIn(entry["status"], ("ready", "limited"))

    def test_applet_ids_are_unique_and_namespaced(self):
        ids = [e["applet"] for e in self.data["entries"]]
        self.assertEqual(len(ids), len(set(ids)), "ids de applet duplicados")
        for applet in ids:
            self.assertTrue(applet.startswith("com.dylanos.widgets."), applet)

    def test_search_filters_and_empty_term_returns_everything(self):
        self.assertEqual(self.data["searchVacio"], self.data["count"])
        self.assertGreaterEqual(self.data["searchReloj"], 1)


class GridContractTest(unittest.TestCase):
    def test_cell_size_is_clamped_for_extreme_screens(self):
        self.assertEqual(layout.cell_size(None), layout.DEFAULT_CELL)
        self.assertEqual(layout.cell_size(0), layout.DEFAULT_CELL)
        self.assertEqual(layout.cell_size(-400), layout.DEFAULT_CELL)
        self.assertEqual(layout.cell_size(100), layout.MIN_CELL)
        self.assertEqual(layout.cell_size(100000), layout.MAX_CELL)

    def test_weather_is_exactly_twice_as_wide_and_same_height(self):
        """Requisito literal: el Clima ocupa 2 columnas, no 2 filas."""
        for height in (600, 768, 800, 1080, 1440, 2160):
            with self.subTest(screen=height):
                rects = {t: (x, y, w, h)
                         for t, x, y, w, h in layout.layout_geometry(height)}
                clock = rects["com.dylanos.widgets.clock"]
                calendar = rects["com.dylanos.widgets.calendar"]
                weather = rects["com.dylanos.widgets.weather"]
                self.assertEqual(clock[2], clock[3], "el Reloj no es cuadrado")
                self.assertEqual(calendar[2], calendar[3], "el Calendario no es cuadrado")
                self.assertEqual(weather[2], clock[2] * 2,
                                 "el Clima no mide el doble de ancho")
                self.assertEqual(weather[3], clock[3],
                                 "el Clima no conserva la altura de un widget normal")

    def test_weather_sits_below_the_pair_and_aligns_left(self):
        rects = {t: (x, y, w, h)
                 for t, x, y, w, h in layout.layout_geometry(800)}
        clock = rects["com.dylanos.widgets.clock"]
        calendar = rects["com.dylanos.widgets.calendar"]
        weather = rects["com.dylanos.widgets.weather"]
        self.assertEqual(weather[0], clock[0], "el Clima no arranca en la misma x")
        self.assertGreater(weather[1], clock[1], "el Clima no está debajo")
        self.assertGreaterEqual(weather[1], clock[1] + clock[3],
                                "el Clima se solapa con la fila superior")
        # La pareja superior no se solapa entre sí.
        self.assertGreaterEqual(calendar[0], clock[0] + clock[2])

    def test_widgets_stay_inside_the_screen(self):
        for height in (600, 900, 1440):
            for widget, x, y, w, h in layout.layout_geometry(height):
                with self.subTest(screen=height, widget=widget):
                    self.assertGreaterEqual(x, 0)
                    self.assertGreaterEqual(y, 0)
                    self.assertGreater(w, 0)
                    self.assertGreater(h, 0)

    def test_size_classes_match_the_shared_tokens(self):
        """La retícula de Python y la de la librería JS no pueden divergir."""
        script = r'''
const fs = require("node:fs");
const vm = require("node:vm");
const src = fs.readFileSync(process.argv[1], "utf8").replace(/^\.pragma library\s*/, "");
const ctx = {};
vm.createContext(ctx);
vm.runInContext(src + "\n;this.api={cells,minCell,maxCell,defaultCell,cellFor}", ctx);
process.stdout.write(JSON.stringify({
  cells: ctx.api.cells, min: ctx.api.minCell,
  max: ctx.api.maxCell, def: ctx.api.defaultCell,
  c800: ctx.api.cellFor(800), c0: ctx.api.cellFor(0)
}));
'''
        result = subprocess.run(["node", "-e", script, str(TOKENS)],
                                capture_output=True, text=True, check=True)
        tokens = json.loads(result.stdout)
        for name, spec in tokens["cells"].items():
            with self.subTest(size=name):
                self.assertEqual(layout.SIZE_CELLS[name], (spec["w"], spec["h"]))
        self.assertEqual(layout.MIN_CELL, tokens["min"])
        self.assertEqual(layout.MAX_CELL, tokens["max"])
        self.assertEqual(layout.DEFAULT_CELL, tokens["def"])
        self.assertEqual(layout.cell_size(800), tokens["c800"])
        self.assertEqual(layout.cell_size(0), tokens["c0"])


class LiveDetectionTest(unittest.TestCase):
    def test_live_session_is_detected_by_the_installer_mountpoints(self):
        """Debe usar las mismas rutas que el instalador, no inventar otras."""
        installer = (ROOT / "installer/dylanos-installer/backend/server.py").read_text(
            encoding="utf-8")
        for mount in layout.LIVE_MEDIUM_MOUNTPOINTS:
            with self.subTest(mount=str(mount)):
                self.assertIn(mount.name, installer or str(mount))
                self.assertIn(str(mount), installer)

    def test_live_medium_present_means_live(self):
        self.assertTrue(layout.is_live_session(lambda path: True))

    def test_installed_system_is_not_live(self):
        self.assertFalse(layout.is_live_session(lambda path: False))

    def test_only_the_live_mountpoint_decision_matters(self):
        seen = []

        def probe(path):
            seen.append(path)
            return Path(path) == Path("/run/live/medium")

        self.assertTrue(layout.is_live_session(probe))
        self.assertTrue(all("live" in p for p in seen), seen)


class DefaultLayoutApplicationTest(unittest.TestCase):
    """El layout no debe aplicarse en live ni dos veces al mismo usuario."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self._old_state = os.environ.get("XDG_STATE_HOME")
        os.environ["XDG_STATE_HOME"] = self.tmp.name
        self.addCleanup(self._restore_state)

    def _restore_state(self):
        if self._old_state is None:
            os.environ.pop("XDG_STATE_HOME", None)
        else:
            os.environ["XDG_STATE_HOME"] = self._old_state

    def test_marker_is_per_user_state_not_shared(self):
        """El marcador nunca puede viajar en la imagen (sería /etc/skel)."""
        marker = layout.marker_path()
        self.assertIn("dylanos", str(marker))
        self.assertIn("widgets", str(marker))
        self.assertNotIn("skel", str(marker))
        self.assertFalse(layout.has_marker())

    def test_live_session_does_not_write_any_marker(self):
        calls = []

        def fake_eval(script, timeout=10):
            calls.append(script)
            return True, ""

        original_live = layout.is_live_session
        original_eval = layout.evaluate_in_plasma
        layout.is_live_session = lambda probe=None: True
        layout.evaluate_in_plasma = fake_eval
        try:
            status = layout.main(["--apply"])
        finally:
            layout.is_live_session = original_live
            layout.evaluate_in_plasma = original_eval

        self.assertEqual(status, 0)
        self.assertEqual(calls, [], "en live no debe evaluarse ningún script")
        self.assertFalse(layout.has_marker(), "en live no debe marcarse el layout")

    def test_installed_session_applies_once_and_respects_later_removals(self):
        calls = []

        def fake_eval(script, timeout=10):
            calls.append(script)
            return True, ""

        original_live = layout.is_live_session
        original_eval = layout.evaluate_in_plasma
        layout.is_live_session = lambda probe=None: False
        layout.evaluate_in_plasma = fake_eval
        try:
            self.assertEqual(layout.main(["--apply"]), 0)
            self.assertTrue(layout.has_marker())
            self.assertEqual(len(calls), 1)
            self.assertIn("addWidget", calls[0])

            # Segundo login: el usuario ya tiene su layout; si borró un widget
            # debe seguir borrado, así que no se vuelve a aplicar.
            self.assertEqual(layout.main(["--apply"]), 0)
            self.assertEqual(len(calls), 1,
                             "el layout se reaplicó en el segundo inicio")
        finally:
            layout.is_live_session = original_live
            layout.evaluate_in_plasma = original_eval

    def test_failed_dbus_call_is_not_marked_as_applied(self):
        """Si plasmashell no responde, el siguiente login debe reintentar."""
        original_live = layout.is_live_session
        original_eval = layout.evaluate_in_plasma
        layout.is_live_session = lambda probe=None: False
        layout.evaluate_in_plasma = lambda script, timeout=10: (False, "sin bus")
        try:
            status = layout.main(["--apply"])
        finally:
            layout.is_live_session = original_live
            layout.evaluate_in_plasma = original_eval

        self.assertEqual(status, 2)
        self.assertFalse(layout.has_marker(),
                         "no debe marcarse el layout si la aplicación falló")

    def test_generated_script_adds_the_three_widgets(self):
        script = layout.build_script(800)
        for widget_type, _ in layout.DEFAULT_LAYOUT:
            self.assertIn(widget_type, script)
        # Idempotente por tipo: no duplica un widget ya presente.
        self.assertIn("widgets(", script)


class WidgetPackagingTest(unittest.TestCase):
    def test_each_widget_ships_metadata_and_representation(self):
        for app in ("dylanos-widgets-clock", "dylanos-widgets-calendar",
                    "dylanos-widgets-weather"):
            with self.subTest(app=app):
                base = ROOT / "apps" / app
                self.assertTrue((base / "metadata.json").is_file())
                self.assertTrue((base / "contents/ui/main.qml").is_file())
                metadata = json.loads((base / "metadata.json").read_text(encoding="utf-8"))
                self.assertEqual(metadata["KPackageStructure"], "Plasma/Applet")
                self.assertTrue(metadata["KPlugin"]["Id"].startswith(
                    "com.dylanos.widgets."))

    def test_metadata_ids_match_the_catalog_applets(self):
        data = read_catalog()
        for entry in data["entries"]:
            app = entry["applet"].replace(".", "-").replace(
                "com-dylanos-widgets-", "dylanos-widgets-")
            if not (ROOT / "apps" / app).is_dir():
                # Los widgets de F3 aún no existen: el catálogo los declara.
                continue
            metadata = json.loads(
                (ROOT / "apps" / app / "metadata.json").read_text(encoding="utf-8"))
            with self.subTest(applet=entry["applet"]):
                self.assertEqual(metadata["KPlugin"]["Id"], entry["applet"])

    def test_every_catalog_widget_has_a_shipped_package(self):
        """Los 20 del catálogo deben existir como paquete, no solo anunciarse."""
        data = read_catalog()
        for entry in data["entries"]:
            suffix = entry["applet"].replace("com.dylanos.widgets.", "")
            with self.subTest(widget=entry["id"]):
                app = ROOT / "apps" / ("dylanos-widgets-" + suffix)
                self.assertTrue((app / "metadata.json").is_file(),
                                "falta el paquete de %s" % entry["id"])
                self.assertTrue((app / "contents/ui/main.qml").is_file())

    def test_no_widget_is_blocked_by_a_missing_package(self):
        """Un widget con `needs-pkg` sería una promesa incumplida en la galería."""
        data = read_catalog()
        blocked = [e["id"] for e in data["entries"] if e["status"] == "needs-pkg"]
        self.assertEqual(blocked, [], blocked)

    def test_every_widget_imports_the_shared_library(self):
        """Ningún widget puede traer su propia copia de los tokens de color."""
        for app in WIDGET_APPS:
            main = app / "contents/ui/main.qml"
            source = main.read_text(encoding="utf-8")
            with self.subTest(app=app.name):
                self.assertIn("WidgetTokens.js", source,
                              "%s no usa los tokens compartidos" % app.name)

    def test_widgets_do_not_hardcode_brand_colors(self):
        """La deriva cromática (#e11d2e, #ff4d5a) ya ocurrió una vez."""
        forbidden = ("#e11d2e", "#ff4d5a", "#1a1414", "#2a1618")
        for app in WIDGET_APPS:
            for path in app.glob("contents/ui/**/*.qml"):
                text = path.read_text(encoding="utf-8").lower()
                for color in forbidden:
                    with self.subTest(file=path.name, color=color):
                        self.assertNotIn(color, text)

    def test_vendored_library_copies_are_identical(self):
        """Un plasmoid es autocontenido: las copias no pueden divergir."""
        for name in VENDORED_FILES:
            reference = (ROOT / "apps/dylanos-widgets-lib" / name).read_text(
                encoding="utf-8")
            for folder in VENDORED:
                with self.subTest(name=name, folder=str(folder.parent.parent.parent.name)):
                    copy = (folder / name).read_text(encoding="utf-8")
                    self.assertEqual(reference, copy,
                                     "la copia de %s diverge de la librería" % name)



def run_js(library, expression):
    """Ejecuta una función de una biblioteca .pragma library con node."""
    script = r'''
const fs = require("node:fs");
const vm = require("node:vm");
const src = fs.readFileSync(process.argv[1], "utf8").replace(/^\.pragma library\s*/, "");
const ctx = { Intl: Intl, Date: Date, Math: Math, String: String,
              Number: Number, isFinite: isFinite, parseFloat: parseFloat };
vm.createContext(ctx);
vm.runInContext(src, ctx);
process.stdout.write(JSON.stringify(vm.runInContext(process.argv[2], ctx)));
'''
    result = subprocess.run(["node", "-e", script, str(library), expression],
                            capture_output=True, text=True, check=True)
    return json.loads(result.stdout)


DATA_LIB = ROOT / "apps/dylanos-widgets-lib/WidgetData.js"
CALC_LIB = ROOT / "apps/dylanos-widgets-lib/WidgetCalc.js"


@unittest.skipUnless(shutil.which("node"), "Node.js needed to execute the data library")
class DataLibraryTest(unittest.TestCase):
    """Las fórmulas de datos son la parte con más riesgo: se ejecutan de verdad."""

    def test_cpu_ignores_guest_counters(self):
        """/proc/stat ya incluye guest en user y nice: sumarlos infla el total.

        Es el fallo que se corrigió en el dashboard el 2026-10-24.
        """
        line = "cpu  100 10 50 800 20 0 5 0 999 999"
        counters = run_js(DATA_LIB, "cpuCountersFromStatLine(%s)" % json.dumps(line))
        # total = user+nice+system+idle+iowait+irq+softirq+steal = 985
        self.assertEqual(counters["total"], 985)
        self.assertEqual(counters["idle"], 820)

    def test_cpu_usage_rejects_incoherent_deltas(self):
        cases = [
            "cpuUsagePercent(1000, 500, 1000, 500)",   # sin delta
            "cpuUsagePercent(1000, 500, 900, 400)",    # contadores que retroceden
            "cpuUsagePercent(0, 0, 100, 200)",         # idle > total
            "cpuUsagePercent(NaN, 0, 100, 50)",
        ]
        for case in cases:
            with self.subTest(case=case):
                self.assertIsNone(run_js(DATA_LIB, case))

    def test_cpu_usage_computes_a_real_percentage(self):
        value = run_js(DATA_LIB, "cpuUsagePercent(1000, 800, 2000, 1000)")
        self.assertAlmostEqual(value, 80.0, places=5)

    def test_memory_rounds_to_the_nearest_power_of_two(self):
        """MemTotal recorta lo que reserva el firmware: 7,6 GiB son 8 GB."""
        cases = {7993964: 8, 11.6 * 1024 * 1024: 12, 15.4 * 1024 * 1024: 16}
        for kb, expected in cases.items():
            with self.subTest(kb=kb):
                self.assertEqual(run_js(DATA_LIB, "roundMemoryGb(%d)" % round(kb)),
                                 expected)

    def test_memory_keeps_an_odd_size_when_it_is_not_close(self):
        """3 GiB no debe convertirse en 4: la diferencia es del 33 %."""
        self.assertEqual(run_js(DATA_LIB, "roundMemoryGb(%d)" % (3 * 1024 * 1024)), 3)

    def test_meminfo_without_available_does_not_invent_usage(self):
        parsed = run_js(DATA_LIB, "parseMemInfo(%s)" % json.dumps("MemTotal: 1024 kB"))
        self.assertEqual(parsed["usedKb"], 1024)

    def test_df_output_is_parsed_or_rejected(self):
        parsed = run_js(DATA_LIB, "parseDfOutput(%s)" % json.dumps("  100 400\n"))
        self.assertEqual(parsed, {"usedBytes": 100, "totalBytes": 400})
        self.assertIsNone(run_js(DATA_LIB, "parseDfOutput(%s)" % json.dumps("basura")))

    def test_upower_percentage_handles_both_scales(self):
        self.assertEqual(run_js(DATA_LIB, "parseUpowerPercentage(0.87)"), 87)
        self.assertEqual(run_js(DATA_LIB, "parseUpowerPercentage(87)"), 87)
        self.assertIsNone(run_js(DATA_LIB, "parseUpowerPercentage('x')"))

    def test_apt_upgrade_count_only_counts_inst_lines(self):
        text = "Inst foo [1] (2)\nInst bar\nConf baz\nRemv qux"
        self.assertEqual(run_js(DATA_LIB, "countAptUpgrades(%s)" % json.dumps(text)), 2)

    def test_bytes_formatting_uses_spanish_decimal_comma(self):
        self.assertEqual(run_js(DATA_LIB, "formatBytes(%d)" % (1536 * 1024 * 1024)),
                         "1,5 GB")
        self.assertEqual(run_js(DATA_LIB, "formatBytes(%d)" % (512 * 1024 * 1024)),
                         "512 MB")
        self.assertEqual(run_js(DATA_LIB, "formatBytes(-1)"), "—")

    def test_next_event_picks_the_soonest_future_event(self):
        ics = ("BEGIN:VCALENDAR\n"
               "BEGIN:VEVENT\nSUMMARY:Tarde\nDTSTART:20300501T100000Z\nEND:VEVENT\n"
               "BEGIN:VEVENT\nSUMMARY:Pronto\nDTSTART:20300101T090000Z\nEND:VEVENT\n"
               "END:VCALENDAR")
        now = 1893456000000  # 2030-01-01 00:00 UTC
        event = run_js(DATA_LIB, "parseNextEvent(%s, %d)" % (json.dumps(ics), now))
        self.assertEqual(event["title"], "Pronto")

    def test_next_event_returns_none_when_everything_is_past(self):
        ics = "BEGIN:VCALENDAR\nBEGIN:VEVENT\nSUMMARY:Viejo\nDTSTART:20200101T100000Z\nEND:VEVENT\nEND:VCALENDAR"
        self.assertIsNone(
            run_js(DATA_LIB, "parseNextEvent(%s, %d)" % (json.dumps(ics), 1893456000000)))

    def test_ics_text_unescaping(self):
        self.assertEqual(
            run_js(DATA_LIB, "decodeIcsText(%s)" % json.dumps("Reunión\\, equipo")),
            "Reunión, equipo")


@unittest.skipUnless(shutil.which("node"), "Node.js needed to execute the calculator")
class CalculatorLibraryTest(unittest.TestCase):
    """El evaluador no puede usar eval ni quedarse sin límites."""

    def test_arithmetic_and_precedence(self):
        cases = {"12 * (3 + 4)": 84, "1+1": 2, "10/4": 2.5, "7%3": 1,
                 "-5+3": -2, "2*(3+4)-(1/2)": 13.5}
        for expression, expected in cases.items():
            with self.subTest(expression=expression):
                result = run_js(CALC_LIB, "evaluate(%s)" % json.dumps(expression))
                self.assertTrue(result["ok"], expression)
                self.assertAlmostEqual(result["value"], expected, places=9)

    def test_rejects_everything_that_is_not_arithmetic(self):
        """Un evaluador permisivo bloqueó Spotlight con 9**99999999."""
        for expression in ("", "9**99999999", "1/0", "5%0", "abc", "(1+2",
                           "1+", "alert(1)", "__proto__", "9x9", "constructor",
                           "1e999", "Math.max(1,2)"):
            with self.subTest(expression=expression):
                self.assertFalse(
                    run_js(CALC_LIB, "evaluate(%s)" % json.dumps(expression))["ok"],
                    "se aceptó una expresión no aritmética")

    def test_length_is_bounded(self):
        long_expression = "+".join(["1"] * 60)
        self.assertFalse(run_js(CALC_LIB, "evaluate(%s)" % json.dumps(long_expression))["ok"])

    def test_result_formatting_drops_float_noise(self):
        self.assertEqual(run_js(CALC_LIB, "formatValue(2.000000001)"), "2")
        self.assertEqual(run_js(CALC_LIB, "formatValue(2.5)"), "2.5")


if __name__ == "__main__":
    unittest.main()
