import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest

MODULE_PATH = Path(__file__).resolve().parents[1] / "benchmarks" / "resource_benchmark.py"
SPEC = importlib.util.spec_from_file_location("resource_benchmark", MODULE_PATH)
benchmark = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(benchmark)


class ProcfsParsingTests(unittest.TestCase):
    def test_status_extracts_identity_rss_and_swap(self):
        status = "Name:\tproceso de prueba\nPPid:\t42\nVmRSS:\t120 kB\nVmSwap:\t20 kB\n"
        self.assertEqual(benchmark.parse_status(status), {
            "name": "proceso de prueba", "ppid": 42, "rss_kib": 120, "swap_kib": 20,
        })

    def test_smaps_and_io_use_real_byte_counters(self):
        self.assertEqual(benchmark.parse_smaps_rollup("Rss: 100 kB\nPss: 61 kB\n"), 61)
        self.assertEqual(benchmark.parse_io("rchar: 900\nread_bytes: 4096\nwchar: 800\nwrite_bytes: 8192\n"), {
            "read_bytes": 4096, "write_bytes": 8192,
        })

    def test_stat_handles_spaces_and_parentheses_in_process_name(self):
        stat = "100 (nombre ) con espacios) S 42 0 0 0 -1 0 0 0 0 0 25 75 0 0 20 0 1 0 100\n"
        self.assertEqual(benchmark.parse_stat(stat), {"ppid": 42, "cpu_ticks": 100})

    def test_meminfo_uses_memavailable_not_memfree(self):
        info = "MemTotal: 1000 kB\nMemFree: 100 kB\nMemAvailable: 400 kB\nSwapTotal: 200 kB\nSwapFree: 50 kB\n"
        self.assertEqual(benchmark.parse_meminfo(info), {
            "memory_total_kib": 1000, "memory_available_kib": 400,
            "memory_used_kib": 600, "swap_total_kib": 200,
            "swap_free_kib": 50, "swap_used_kib": 150,
        })

    def test_cpu_and_disk_counters_are_decoded(self):
        self.assertEqual(benchmark.parse_cpu_stat("cpu 100 20 30 400 50 0 0 0 0 0\n"), {
            "total_ticks": 600, "idle_ticks": 450,
        })
        line = "8 0 sda 1 0 100 0 2 0 200 0 0 0 0\n"
        self.assertEqual(benchmark.parse_diskstat(line), {
            "device": "sda", "read_bytes": 100 * 512, "write_bytes": 200 * 512,
        })

    def test_procfs_reads_one_complete_process(self):
        with tempfile.TemporaryDirectory() as temporary:
            proc = Path(temporary) / "100"
            proc.mkdir()
            (proc / "status").write_text("Name:\tapp\nPPid:\t1\nVmRSS:\t100 kB\nVmSwap:\t5 kB\n", encoding="utf-8")
            (proc / "stat").write_text("100 (app) S 1 0 0 0 0 0 0 0 0 0 2 3 0 0 20 0 1 0 1\n", encoding="utf-8")
            (proc / "io").write_text("read_bytes: 10\nwrite_bytes: 20\n", encoding="utf-8")
            (proc / "smaps_rollup").write_text("Pss: 60 kB\n", encoding="utf-8")
            process = benchmark.Procfs(Path(temporary)).process(100)
            self.assertEqual(process["pid"], 100)
            self.assertEqual(process["ppid"], 1)
            self.assertEqual(process["rss_kib"], 100)
            self.assertEqual(process["pss_kib"], 60)
            self.assertEqual(process["cpu_ticks"], 5)
            self.assertEqual(process["read_bytes"], 10)
            self.assertEqual(process["write_bytes"], 20)


class AggregationTests(unittest.TestCase):
    def test_tree_contains_only_root_and_live_descendants(self):
        processes = {
            100: {"ppid": 1}, 101: {"ppid": 100}, 102: {"ppid": 101},
            200: {"ppid": 1}, 300: {"ppid": 999},
        }
        self.assertEqual(benchmark.tree_pids(processes, 100), {100, 101, 102})
        self.assertEqual(benchmark.tree_pids(processes, 404), set())

    def test_aggregate_does_not_hide_rss_when_pss_is_unavailable(self):
        processes = {
            100: {"rss_kib": 100, "pss_kib": 60, "swap_kib": 2, "cpu_ticks": 10, "read_bytes": 5, "write_bytes": 7},
            101: {"rss_kib": 50, "pss_kib": None, "swap_kib": 0, "cpu_ticks": 5, "read_bytes": 3, "write_bytes": 2},
        }
        self.assertEqual(benchmark.aggregate_processes(processes, {100, 101}), {
            "process_count": 2, "rss_kib": 150, "pss_kib": None, "swap_kib": 2,
            "cpu_ticks": 15, "read_bytes": 8, "write_bytes": 9,
        })

    def test_cpu_reports_one_core_and_whole_machine_percentages(self):
        self.assertEqual(benchmark.cpu_percentages(50, 0.5, 100, 4), (100.0, 25.0))
        self.assertEqual(benchmark.cpu_percentages(0, 0.0, 100, 4), (0.0, 0.0))

    def test_summary_has_average_peak_disk_and_process_metrics(self):
        samples = [
            {"rss_kib": 100, "pss_kib": 50, "swap_kib": 0, "cpu_percent": 2,
             "cpu_system_percent": 0.5, "read_bytes_per_second": 10,
             "write_bytes_per_second": 0, "process_count": 1},
            {"rss_kib": 300, "pss_kib": 150, "swap_kib": 10, "cpu_percent": 4,
             "cpu_system_percent": 1, "read_bytes_per_second": 30,
             "write_bytes_per_second": 20, "process_count": 3},
        ]
        result = benchmark.summarize(samples)
        self.assertEqual(result["ram_rss_average_kib"], 200)
        self.assertEqual(result["ram_rss_max_kib"], 300)
        self.assertEqual(result["ram_pss_average_kib"], 100)
        self.assertEqual(result["cpu_average_percent"], 3)
        self.assertEqual(result["cpu_max_percent"], 4)
        self.assertEqual(result["cpu_system_average_percent"], 0.75)
        self.assertEqual(result["disk_read_average_bytes_per_second"], 20)
        self.assertEqual(result["disk_write_max_bytes_per_second"], 20)
        self.assertEqual(result["processes_max"], 3)

    def test_missing_pss_is_not_replaced_with_zero(self):
        result = benchmark.summarize([{"rss_kib": 100, "pss_kib": None}])
        self.assertIsNone(result["ram_pss_average_kib"])
        self.assertIsNone(result["ram_pss_max_kib"])


class SamplerTests(unittest.TestCase):
    def process(self, pid, ppid, cpu, read, write, rss=100):
        return {"pid": pid, "ppid": ppid, "name": f"p{pid}", "cpu_ticks": cpu,
                "read_bytes": read, "write_bytes": write, "rss_kib": rss,
                "pss_kib": rss // 2, "swap_kib": 0}

    def test_application_sampler_deltas_include_children(self):
        class FakeProcfs:
            def processes(inner):
                return {
                    100: inner_current[100], 101: inner_current[101], 999: self.process(999, 1, 900, 0, 0),
                }
        inner_current = {100: self.process(100, 1, 10, 100, 20), 101: self.process(101, 100, 20, 200, 40)}
        sampler = benchmark.ApplicationSampler(FakeProcfs(), 100, ticks_per_second=100, cpu_count=4)
        first = sampler.sample(10.0)
        self.assertEqual(first["process_count"], 2)
        self.assertIsNone(first["cpu_percent"])
        inner_current = {100: self.process(100, 1, 35, 200, 40, 120), 101: self.process(101, 100, 45, 350, 80, 80)}
        second = sampler.sample(10.5)
        self.assertEqual(second["cpu_percent"], 100)
        self.assertEqual(second["cpu_system_percent"], 25)
        self.assertEqual(second["rss_kib"], 200)
        self.assertEqual(second["read_bytes_per_second"], 500)
        self.assertEqual(second["write_bytes_per_second"], 120)
        self.assertEqual(sampler.child_pids, {101})

    def test_system_sampler_uses_busy_time_and_disk_deltas(self):
        class FakeProcfs:
            def meminfo(inner):
                return {"memory_total_kib": 1000, "memory_available_kib": 400,
                        "memory_used_kib": 600, "swap_used_kib": 10}
            def cpu_stat(inner):
                return inner_cpu.pop(0)
            def diskstats(inner):
                return inner_disk.pop(0)
        inner_cpu = [{"total_ticks": 600, "idle_ticks": 450}, {"total_ticks": 800, "idle_ticks": 650}]
        inner_disk = [{"sda": {"read_bytes": 1000, "write_bytes": 2000}},
                      {"sda": {"read_bytes": 1500, "write_bytes": 2000}}]
        sampler = benchmark.SystemSampler(FakeProcfs())
        first = sampler.sample(20.0)
        second = sampler.sample(20.5)
        self.assertEqual(first["memory_used_kib"], 600)
        self.assertIsNone(first["cpu_system_percent"])
        self.assertEqual(second["cpu_system_percent"], 0)
        self.assertEqual(second["read_bytes_per_second"], 1000)
        self.assertEqual(second["write_bytes_per_second"], 0)

    def test_cli_measures_and_terminates_a_real_child(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "result.json"
            result = benchmark.main([
                "--name", "hijo real", "--duration", "0.3", "--interval", "0.05",
                "--output", str(output), "--", sys.executable, "-c", "import time; time.sleep(10)",
            ])
            self.assertEqual(result, 0)
            import json
            report = json.loads(output.read_text(encoding="utf-8"))
            self.assertGreater(report["summary"]["ram_rss_max_kib"], 0)
            self.assertGreaterEqual(report["summary"]["processes_max"], 1)
            self.assertTrue(output.with_suffix(".md").is_file())
            self.assertEqual(report["budget"]["status"], "incomplete")


class GpuTests(unittest.TestCase):
    @staticmethod
    def process(pid, ppid, cpu, read, write, rss=100):
        return {"pid": pid, "ppid": ppid, "name": f"p{pid}", "cpu_ticks": cpu,
                "read_bytes": read, "write_bytes": write, "rss_kib": rss,
                "pss_kib": rss // 2, "swap_kib": 0}

    def test_fdinfo_engines_reads_drm_nanoseconds_only(self):
        text = (
            "pos:\t0\nflags:\t02100002\ndrm-client-id:\t7\n"
            "drm-engine-gfx:\t123456789 ns\ndrm-engine-compute:\t42 ns\n"
            "drm-memory-vram:\t1024 KiB\n"
        )
        self.assertEqual(benchmark.parse_fdinfo_engines(text), {
            "drm-engine-gfx": 123456789, "drm-engine-compute": 42,
        })

    def test_procfs_gpu_engines_sums_all_descriptors(self):
        with tempfile.TemporaryDirectory() as temporary:
            fdinfo = Path(temporary) / "100" / "fdinfo"
            fdinfo.mkdir(parents=True)
            (fdinfo / "3").write_text("drm-engine-gfx:\t10 ns\n", encoding="utf-8")
            (fdinfo / "4").write_text("drm-engine-gfx:\t5 ns\ndrm-engine-render:\t2 ns\n", encoding="utf-8")
            (fdinfo / "5").write_text("pos:\t0\n", encoding="utf-8")
            procfs = benchmark.Procfs(Path(temporary))
            self.assertEqual(procfs.gpu_engines(100), {"drm-engine-gfx": 15, "drm-engine-render": 2})
            self.assertIsNone(procfs.gpu_engines(404))

    def test_gpu_sampler_uses_the_busiest_card_and_reports_nothing_without_source(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for card, value in (("card0", "12"), ("card1", "48")):
                device = root / card / "device"
                device.mkdir(parents=True)
                (device / "gpu_busy_percent").write_text(value + "\n", encoding="utf-8")
            sampler = benchmark.GpuSampler(root)
            self.assertTrue(sampler.available)
            self.assertEqual(sampler.percent(), 48.0)
        empty = benchmark.GpuSampler(Path(tempfile.mkdtemp()))
        empty.nvidia_smi = None
        self.assertFalse(empty.available)
        self.assertIsNone(empty.percent())

    def test_application_gpu_percent_uses_the_busiest_engine(self):
        class FakeProcfs:
            def processes(inner):
                return {100: GpuTests.process(100, 1, 10, 0, 0)}
            def gpu_engines(inner, pid):
                return gpu_samples.pop(0)
        gpu_samples = [{"drm-engine-gfx": 0, "drm-engine-render": 0},
                       {"drm-engine-gfx": 1_000_000_000, "drm-engine-render": 250_000_000}]
        sampler = benchmark.ApplicationSampler(FakeProcfs(), 100, ticks_per_second=100, cpu_count=4)
        first = sampler.sample(10.0)
        second = sampler.sample(11.0)
        self.assertIsNone(first["gpu_percent"])
        self.assertEqual(second["gpu_percent"], 100.0)


class ContractTests(unittest.TestCase):
    def summary(self, rss_mib=100):
        return {
            "ram_rss_max_kib": rss_mib * 1024,
            "cpu_system_average_percent": 2.0,
            "cpu_system_max_percent": 2.5,
            "swap_max_kib": 0,
        }

    def test_app_budget_uses_200_mib_and_normalized_cpu(self):
        result = benchmark.evaluate_budget(self.summary(200), "application")
        self.assertTrue(result["measured_within_limits"])
        self.assertEqual(result["status"], "incomplete")
        self.assertEqual(result["checks"]["ram_rss_max"]["limit"], 200 * 1024)
        self.assertEqual(result["checks"]["gpu"]["status"], "unknown")
        self.assertEqual(result["checks"]["frame_pacing"]["status"], "unknown")

    def test_system_budget_uses_300_mib_and_swap_target(self):
        result = benchmark.evaluate_budget(self.summary(300), "system")
        self.assertTrue(result["measured_within_limits"])
        self.assertEqual(result["checks"]["ram_used_max"]["limit"], 300 * 1024)

    def test_exceeding_a_measured_limit_fails(self):
        result = benchmark.evaluate_budget(self.summary(201), "application")
        self.assertFalse(result["measured_within_limits"])
        self.assertEqual(result["checks"]["ram_rss_max"]["status"], "fail")

    def test_markdown_preserves_unavailable_metrics_and_environment(self):
        report = {
            "name": "app de prueba", "mode": "application", "command": ["app", "--smoke"],
            "date_utc": "2026-11-26 00:00:00 UTC", "duration_s": 5,
            "environment": {"platform": "Linux/test", "cpu_model": "CPU de prueba", "cpu_count": 4},
            "summary": self.summary(), "budget": benchmark.evaluate_budget(self.summary(), "application"),
            "unavailable": {"gpu": "Sin fuente por proceso", "ui_response": "Sin sonda", "frame_pacing": "Sin sonda"},
        }
        markdown = benchmark.render_markdown(report)
        self.assertIn("app de prueba", markdown)
        self.assertIn("CPU de prueba", markdown)
        self.assertIn("Sin fuente por proceso", markdown)
        self.assertIn("incompleto", markdown)
        self.assertNotIn("GPU: 0", markdown)


if __name__ == "__main__":
    unittest.main()

