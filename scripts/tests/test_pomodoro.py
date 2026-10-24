"""Exercise the Dashboard Pomodoro's pure timing/progress helpers."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(shutil.which("node"), "Node.js needed to execute the Pomodoro helper")
class PomodoroClockTest(unittest.TestCase):
    def test_durations_modes_deadlines_and_progress(self):
        helper = ROOT / "apps/com.dylanos.dashboard/contents/ui/PomodoroClock.js"
        script = r'''const fs = require("node:fs");
const vm = require("node:vm");
const assert = require("node:assert/strict");
const source = fs.readFileSync(process.argv[1], "utf8").replace(/^\.pragma library\s*/, "");
const api = vm.runInNewContext(source + "\n({ durationSeconds, nextMode, remainingSeconds, progress })");
assert.equal(api.durationSeconds("focus"), 1500);
assert.equal(api.durationSeconds("break"), 300);
assert.equal(api.nextMode("focus"), "break");
assert.equal(api.nextMode("break"), "focus");
assert.equal(api.remainingSeconds(1500, 0), 2);
assert.equal(api.remainingSeconds(1499, 0), 2);
assert.equal(api.remainingSeconds(1000, 0), 1);
assert.equal(api.remainingSeconds(999, 1000), 0);
assert.equal(api.remainingSeconds(NaN, 1000), 0);
assert.equal(api.progress(1500, 1500), 0);
assert.equal(api.progress(750, 1500), 0.5);
assert.equal(api.progress(0, 1500), 1);
assert.equal(api.progress(2000, 1500), 0);
assert.equal(api.progress(0, 0), 0);
'''
        result = subprocess.run(["node", "-e", script, str(helper)], text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
