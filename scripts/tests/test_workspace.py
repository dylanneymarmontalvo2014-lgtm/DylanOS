#!/usr/bin/env python3
"""Data integrity tests for the operations exposed by the desktop apps."""
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "apps/workspace"))
from core import Notes, safe_name, list_folder, copy_entry, create_project


class WorkspaceTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def test_listing_real_files_hidden_and_sort(self):
        (self.root / "carpeta").mkdir()
        (self.root / "árbol.txt").write_text("texto")
        (self.root / ".privado").touch()
        entries = list_folder(self.root)
        self.assertEqual([e["name"] for e in entries], ["carpeta", "árbol.txt"])
        self.assertEqual(len(list_folder(self.root, True)), 3)

    def test_names_cannot_escape_folder(self):
        for name in ("", " ", "..", ".", "../escape", "/tmp/escape", "a\0b"):
            with self.assertRaises(ValueError): safe_name(name)
        self.assertEqual(safe_name("área de trabajo"), "área de trabajo")

    def test_copy_keeps_original_and_refuses_overwrite(self):
        source = self.root / "source.txt"
        source.write_text("mi contenido")
        destination = self.root / "dest"
        destination.mkdir()
        self.assertEqual(copy_entry(source, destination).read_text(), "mi contenido")
        source.write_text("otra versión")
        with self.assertRaises(FileExistsError): copy_entry(source, destination)
        self.assertEqual((destination / source.name).read_text(), "mi contenido")
        self.assertEqual(source.read_text(), "otra versión")

    def test_symlinks_preserved_and_recursive_copy_rejected(self):
        source = self.root / "source"
        source.mkdir()
        (source / "link").symlink_to("/nonexistent")
        dest = self.root / "dest"
        dest.mkdir()
        copied = copy_entry(source, dest)
        self.assertTrue((copied / "link").is_symlink())
        with self.assertRaises(ValueError): copy_entry(source, source)

    def test_notes_persist_and_update_without_duplicate(self):
        store = Notes(self.root)
        note_id = store.save("", "Idea", "Primera línea\nSegunda línea 🪐")
        store.save(note_id, "Revisada", "cambio")
        reopened = Notes(self.root)
        self.assertEqual(len(reopened.all()), 1)
        self.assertEqual(reopened.all()[0]["body"], "cambio")
        reopened.delete(note_id)
        self.assertEqual(store.all(), [])
        reopened.db.close()
        store.db.close()

    def test_project_templates_and_existing_project_protected(self):
        for template in ("Python", "Web", "C++"):
            name = {"Python":"python", "Web":"web", "C++":"cpp"}[template]
            project = create_project(self.root, name, template)
            self.assertTrue((project / "README.md").exists())
            (project / "keep.txt").write_text("no tocar")
            with self.assertRaises(FileExistsError): create_project(self.root, name, template)
            self.assertEqual((project / "keep.txt").read_text(), "no tocar")
        with self.assertRaises(ValueError): create_project(self.root, "../escape", "Python")
        with self.assertRaises(ValueError): create_project(self.root, "test", "Unknown")


if __name__ == "__main__":
    unittest.main()
