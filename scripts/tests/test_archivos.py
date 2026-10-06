import ast
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "apps/archivos/main.py"


class ArchivosLauncherTest(unittest.TestCase):
    def test_launcher_only_delegates_to_workspace(self):
        text = SOURCE.read_text()
        tree = ast.parse(text)
        main = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "main")
        calls = [node for node in ast.walk(main) if isinstance(node, ast.Call)]
        runpy_calls = [node for node in calls if isinstance(node.func, ast.Attribute) and node.func.attr == "run_path"]
        self.assertEqual(len(runpy_calls), 1)
        self.assertNotIn("QGuiApplication", text)
        self.assertNotIn("QQmlApplicationEngine", text)
        self.assertNotIn("QIcon", text)
        self.assertIn('sys.argv[1:1] = ["--page", "files"]', text)

    def test_prototype_is_explicitly_non_productive(self):
        readme = (ROOT / "apps/archivos/README.md").read_text()
        self.assertIn("prototipo", readme.lower())
        self.assertIn("no es la implementación", readme.lower())


if __name__ == "__main__":
    unittest.main()
