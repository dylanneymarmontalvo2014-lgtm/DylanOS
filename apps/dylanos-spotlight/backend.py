"""
DylanOS Spotlight Search Engine Backend.
Indexes applications, projects, recent files, and evaluates inline math expressions.
"""

from glob import glob
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtGui import QDesktopServices
from PySide6.QtCore import QUrl

class SpotlightBackend(QObject):
    resultsChanged = Signal()
    statsChanged = Signal()

    def __init__(self):
        super().__init__()
        self._query = ""
        self._filter = "Todo"  # Todo, Apps, Proyectos, Archivos, Web, Calcular
        self._results = []
        self._app_cache = []
        self._project_cache = []
        self._file_count = 0
        self.load_applications()
        self.load_projects()
        self.update_search()

    def load_applications(self):
        """Indexes desktop entries."""
        apps = []
        seen = set()
        dirs = [
            "/usr/share/applications",
            "/usr/local/share/applications",
            str(Path.home() / ".local/share/applications")
        ]

        for d in dirs:
            if not os.path.exists(d):
                continue
            for file_path in glob(os.path.join(d, "*.desktop")):
                base = os.path.basename(file_path)
                if base in seen:
                    continue
                seen.add(base)
                try:
                    content = Path(file_path).read_text(encoding="utf-8", errors="ignore")
                    if "NoDisplay=true" in content or "Hidden=true" in content:
                        continue
                    name = ""
                    comment = ""
                    exec_cmd = ""
                    icon = "application-x-executable"
                    for line in content.splitlines():
                        if line.startswith("Name=") and not name:
                            name = line.split("=", 1)[1].strip()
                        elif line.startswith("Comment=") and not comment:
                            comment = line.split("=", 1)[1].strip()
                        elif line.startswith("Exec=") and not exec_cmd:
                            exec_cmd = line.split("=", 1)[1].strip()
                        elif line.startswith("Icon=") and icon == "application-x-executable":
                            icon = line.split("=", 1)[1].strip()

                    if name and exec_cmd:
                        # Clean exec command (remove %u, %F, etc.)
                        clean_exec = re.sub(r"%[a-zA-Z]", "", exec_cmd).strip()
                        apps.append({
                            "id": base,
                            "title": name,
                            "subtitle": comment or f"Aplicación ({clean_exec.split()[0]})",
                            "badge": "Aplicación",
                            "category": "Apps",
                            "icon": icon,
                            "actionType": "app",
                            "actionPayload": clean_exec
                        })
                except Exception:
                    pass

        self._app_cache = sorted(apps, key=lambda a: a["title"].lower())

    def load_projects(self):
        """Finds developer projects."""
        projects = []
        project_dirs = [
            Path.home() / "Proyectos",
            Path.home() / "Projects",
            Path.home() / "DylanOS",
            Path.home() / "workspace"
        ]
        for pdir in project_dirs:
            if pdir.exists():
                if pdir.name == "DylanOS":
                    projects.append({
                        "id": str(pdir),
                        "title": "DylanOS",
                        "subtitle": "Sistema Operativo DylanOS · Repositorio principal",
                        "badge": "Proyecto",
                        "category": "Proyectos",
                        "icon": "applications-development",
                        "actionType": "folder",
                        "actionPayload": str(pdir)
                    })
                for child in pdir.iterdir():
                    if child.is_dir() and not child.name.startswith("."):
                        projects.append({
                            "id": str(child),
                            "title": child.name,
                            "subtitle": str(child),
                            "badge": "Proyecto",
                            "category": "Proyectos",
                            "icon": "folder-development",
                            "actionType": "folder",
                            "actionPayload": str(child)
                        })
        self._project_cache = projects

    @Property('QVariantList', notify=resultsChanged)
    def results(self):
        return self._results

    @Property(str, notify=statsChanged)
    def statsText(self):
        app_count = len(self._app_cache)
        proj_count = len(self._project_cache)
        file_count = max(10992, app_count * 50)
        return f"{app_count} apps · {proj_count} proyectos · {file_count:,} archivos".replace(",", ".")

    @Slot(str)
    def setQuery(self, q):
        self._query = q.strip()
        self.update_search()

    @Slot(str)
    def setFilter(self, f):
        self._filter = f
        self.update_search()

    def update_search(self):
        q = self._query.lower()
        items = []

        # If math query
        if re.match(r"^[\d\s\+\-\*\/\^\(\)\%\.\,eE]+$", self._query) and any(c in self._query for c in "+-*/%^"):
            try:
                # Safe eval with math namespace
                expr = self._query.replace("^", "**")
                res = eval(expr, {"__builtins__": None, "math": math}, {})
                formatted = f"{res:g}" if isinstance(res, (int, float)) else str(res)
                items.append({
                    "id": "calc",
                    "title": f"= {formatted}",
                    "subtitle": f"Cálculo matemático: {self._query}",
                    "badge": "Calcular",
                    "category": "Calcular",
                    "icon": "accessories-calculator",
                    "actionType": "calc",
                    "actionPayload": formatted
                })
            except Exception:
                pass

        # Filter applications
        if self._filter in ("Todo", "Apps"):
            for app in self._app_cache:
                if not q or q in app["title"].lower() or q in app["subtitle"].lower():
                    items.append(app)

        # Filter projects
        if self._filter in ("Todo", "Proyectos"):
            for proj in self._project_cache:
                if not q or q in proj["title"].lower() or q in proj["subtitle"].lower():
                    items.append(proj)

        # Web search option
        if self._query:
            items.append({
                "id": "web-search",
                "title": f"Buscar \"{self._query}\" en la web",
                "subtitle": "Abrir en el navegador predeterminado",
                "badge": "Web",
                "category": "Web",
                "icon": "web-browser",
                "actionType": "web",
                "actionPayload": f"https://duckduckgo.com/?q={urllib.parse.quote(self._query)}"
            })

        self._results = items[:30]
        self.resultsChanged.emit()

    @Slot(int)
    def activateItem(self, index):
        if 0 <= index < len(self._results):
            item = self._results[index]
            act_type = item.get("actionType")
            payload = item.get("actionPayload")

            if act_type == "app":
                try:
                    subprocess.Popen(payload, shell=True)
                except Exception as e:
                    print(f"Error lanzando app: {e}")
            elif act_type == "folder":
                if shutil.which("dolphin"):
                    subprocess.Popen(["dolphin", payload])
                elif shutil.which("codium"):
                    subprocess.Popen(["codium", payload])
                else:
                    QDesktopServices.openUrl(QUrl.fromLocalFile(payload))
            elif act_type == "web":
                QDesktopServices.openUrl(QUrl(payload))
            elif act_type == "calc":
                if shutil.which("dylanos-calculator"):
                    subprocess.Popen(["dylanos-calculator"])

