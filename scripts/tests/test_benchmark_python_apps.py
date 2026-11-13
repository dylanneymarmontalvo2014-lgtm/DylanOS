import importlib.util
from pathlib import Path
import unittest

MODULE_PATH = Path(__file__).resolve().parents[1] / "benchmarks" / "benchmark_python_apps.py"
SPEC = importlib.util.spec_from_file_location("benchmark_python_apps", MODULE_PATH)
benchmark = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(benchmark)


class BenchmarkPythonAppsTests(unittest.TestCase):
    def test_targets_only_three_current_python_apps(self):
        self.assertEqual(set(benchmark.APPS), {"archivos", "dylanos-spotlight", "workspace"})
        self.assertEqual(benchmark.APPS["archivos"][0].rsplit("/", 2)[-2:], ["archivos", "main.py"])
        self.assertIn("--smoke", benchmark.APPS["dylanos-spotlight"])
        self.assertIn("--smoke", benchmark.APPS["workspace"])

    def test_percentile_uses_nearest_rank(self):
        self.assertEqual(benchmark.percentile([1, 2, 3, 4, 5], 50), 3)
        self.assertEqual(benchmark.percentile([1, 2, 3, 4, 5], 95), 5)
        self.assertEqual(benchmark.percentile([5, 1, 4, 2, 3], 100), 5)

    def test_percentile_rejects_invalid_inputs(self):
        for percent in (0, -1, 101):
            with self.subTest(percent=percent), self.assertRaises(ValueError):
                benchmark.percentile([1], percent)
        with self.assertRaises(ValueError):
            benchmark.percentile([], 95)

    def test_summary_contains_startup_and_rss_statistics(self):
        result = benchmark.summarize([
            {"startup_ms": 10, "peak_rss_kib": 100},
            {"startup_ms": 20, "peak_rss_kib": 200},
            {"startup_ms": 30, "peak_rss_kib": 300},
        ])
        self.assertEqual(result, {
            "startup_median_ms": 20,
            "startup_p95_ms": 30,
            "peak_rss_median_kib": 200,
            "peak_rss_max_kib": 300,
        })

    def test_report_markdown_states_scope_and_limits(self):
        summary = {
            "startup_median_ms": 10,
            "startup_p95_ms": 15,
            "peak_rss_median_kib": 2048,
            "peak_rss_max_kib": 3072,
        }
        report = {
            "commit": "abc123",
            "date_utc": "2026-01-01 00:00:00 UTC",
            "python": "3.12.1",
            "pyside6": "6.8.2",
            "qt": "6.8.2",
            "platform": "linux / test",
            "iterations": 10,
            "warmups": 1,
            "apps": {name: {"summary": summary} for name in benchmark.APPS},
        }
        markdown = benchmark.render_markdown(report)
        self.assertIn("not true cold-boot results", markdown)
        self.assertIn("retired prototype QML", markdown)
        for name in benchmark.APPS:
            self.assertIn(f"`{name}`", markdown)
        self.assertIn("2.00", markdown)


if __name__ == "__main__":
    unittest.main()
