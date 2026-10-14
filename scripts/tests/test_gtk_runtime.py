"""Parse themes with actual GTK engines, independently of PySide's venv."""
from pathlib import Path
import subprocess
import tempfile
import unittest
import os

ROOT = Path(__file__).resolve().parents[2]


class GtkParserTest(unittest.TestCase):
    def test_css_loads_in_both_engines(self):
        for version in ('3.0', '4.0'):
            with self.subTest(version=version), tempfile.TemporaryDirectory() as config:
                code = '''
import gi, sys
try:
    gi.require_version('Gtk', sys.argv[1])
    from gi.repository import Gtk
except (ImportError, ValueError):
    sys.exit(77)
errors = []
for theme in ('DylanOS-Crimson', 'DylanOS-Crimson-Light'):
    for variant in ('gtk.css', 'gtk-dark.css'):
        provider = Gtk.CssProvider()
        provider.connect('parsing-error', lambda p,s,e: errors.append(str(e)))
        provider.load_from_path(sys.argv[2] + '/themes/gtk/' + theme + '/gtk-' + sys.argv[1] + '/' + variant)
if errors:
    print('\\n'.join(errors))
    sys.exit(1)
'''
                result = subprocess.run(['/usr/bin/python3', '-c', code, version, str(ROOT)],
                                        env={**os.environ, 'XDG_CONFIG_HOME': config}, capture_output=True, text=True)
                if result.returncode == 77:
                    self.skipTest('GTK introspection unavailable')
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
