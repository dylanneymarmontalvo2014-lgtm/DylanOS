import importlib.util
from pathlib import Path
import unittest

MODULE_PATH = Path(__file__).resolve().parents[1] / "benchmarks" / "app_budgets.py"
SPEC = importlib.util.spec_from_file_location("app_budgets", MODULE_PATH)
budgets = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(budgets)


def report(name, rss_kib=102400, pss_kib=51200, cpu=1.5, cpu_max=2.5, gpu=None, status="incomplete"):
    return {
        "name": name,
        "summary": {
            "ram_rss_max_kib": rss_kib,
            "ram_pss_max_kib": pss_kib,
            "cpu_system_average_percent": cpu,
            "cpu_system_max_percent": cpu_max,
            "gpu_max_percent": gpu,
            "processes_max": 2,
        },
        "budget": {"status": status},
    }


class AppBudgetTests(unittest.TestCase):
    def test_official_apps_exclude_the_browser(self):
        self.assertNotIn("browser", budgets.APPS)
        for name in ("configuration", "explorer", "calculator", "app-center",
                     "spotlight", "workspace", "store"):
            self.assertIn(name, budgets.APPS)
            self.assertTrue(budgets.APPS[name])

    def test_summary_converts_kibibytes_to_mibibytes(self):
        row = budgets.summarize_report(report("app", rss_kib=204800, pss_kib=102400))
        self.assertEqual(row["ram_rss_mib"], 200.0)
        self.assertEqual(row["ram_pss_mib"], 100.0)
        self.assertEqual(row["cpu_average_percent"], 1.5)
        self.assertEqual(row["processes_max"], 2)

    def test_missing_gpu_stays_unavailable(self):
        row = budgets.summarize_report(report("app", gpu=None))
        self.assertIsNone(row["gpu_max_percent"])

    def test_markdown_reports_status_and_skipped_apps(self):
        entries = {
            "configuration": {"command": ["dylanos-configuration"], "report": report("configuration", status="pass")},
            "store": {"command": ["dylanos-store"], "report": report("store", rss_kib=250000, status="fail")},
            "process": {"command": ["dylanos-process"], "error": "no está instalado"},
        }
        markdown = budgets.render_markdown(entries)
        self.assertIn("`configuration`", markdown)
        self.assertIn("aprobado", markdown)
        self.assertIn("fuera de límite", markdown)
        self.assertIn("no disponible: no está instalado", markdown)
        self.assertIn("200 MiB de RAM", markdown)

    def test_rows_are_sorted_by_name(self):
        entries = {
            "workspace": {"command": ["dylanos"], "report": report("workspace")},
            "calculator": {"command": ["dylanos-calculator"], "report": report("calculator")},
        }
        markdown = budgets.render_markdown(entries)
        self.assertLess(markdown.index("`calculator`"), markdown.index("`workspace`"))


if __name__ == "__main__":
    unittest.main()
