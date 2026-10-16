"""Qt bridge. Actions use argument arrays; desktop operations retain OS policy."""
import os
from pathlib import Path
import platform
import shutil
import time
import subprocess
import sys
import configparser

import psutil
from PySide6.QtCore import QObject, Property, Signal, Slot, QTimer, QUrl, QProcess, QStandardPaths, QFile, QFileSystemWatcher, QRunnable, QThreadPool
from PySide6.QtGui import QDesktopServices
from core import Notes, list_folder, human_size, safe_name, copy_entry, create_project


class WorkSignals(QObject):
    finished = Signal(object, str)


class Work(QRunnable):
    def __init__(self, action):
        super().__init__()
        self.action = action
        self.signals = WorkSignals()

    def run(self):
        try:
            self.signals.finished.emit(self.action(), "")
        except Exception as error:
            self.signals.finished.emit(None, str(error))


class Backend(QObject):
    filesChanged = Signal()
    notesChanged = Signal()
    statsChanged = Signal()
    busyChanged = Signal()
    toolsChanged = Signal()
    message = Signal(str)
    projectCreated = Signal(str)

    def __init__(self, page=None):
        super().__init__()
        self._page = page
        self._path = str(Path.home())
        self._files, self._history, self._cursor = [], [self._path], 0
        self._hidden, self._busy = False, False
        self._clipboard = ""
        self._stats = {}
        self._tools = []
        # Preserve the existing Workspace notes location across separate app identities.
        data = Path(QStandardPaths.writableLocation(QStandardPaths.GenericDataLocation)) / "DylanOS" / "Workspace"
        self.notes_store = Notes(data)
        self.pool = QThreadPool(self)
        self.pool.setMaxThreadCount(1)
        self.watcher = QFileSystemWatcher(self)
        self.watcher.directoryChanged.connect(self.refresh)
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.updateStats)
        self._cpu_history = []
        self._memory_history = []
        if page in (None, "monitor"):
            self.timer.start(2500)
        self.updateStats()
        if page in (None, "files"):
            self.refresh()
        if page in (None, "dev"):
            self.scanTools()

    @Property(str, notify=filesChanged)
    def folder(self): return self._path

    @Property('QVariantList', notify=filesChanged)
    def files(self): return self._files

    @Property(bool, notify=filesChanged)
    def canBack(self): return self._cursor > 0

    @Property(bool, notify=filesChanged)
    def canForward(self): return self._cursor < len(self._history) - 1

    @Property(bool, notify=busyChanged)
    def busy(self): return self._busy

    @Property('QVariantList', notify=notesChanged)
    def notes(self): return self.notes_store.all()

    @Property('QVariantMap', notify=statsChanged)
    def stats(self): return self._stats

    @Property('QVariantList', notify=toolsChanged)
    def tools(self): return self._tools

    @Property(str, constant=True)
    def projectsFolder(self): return str(Path.home() / "Proyectos")

    @Property('QVariantList', constant=True)
    def places(self):
        locations = [("Inicio", QStandardPaths.HomeLocation), ("Escritorio", QStandardPaths.DesktopLocation),
                     ("Documentos", QStandardPaths.DocumentsLocation), ("Descargas", QStandardPaths.DownloadLocation),
                     ("Imágenes", QStandardPaths.PicturesLocation), ("Música", QStandardPaths.MusicLocation)]
        return [dict(name=name, path=QStandardPaths.writableLocation(loc)) for name, loc in locations]

    def work(self, action, complete):
        if self._busy:
            self.message.emit("Espera a que termine la operación actual.")
            return
        self._busy = True
        self.busyChanged.emit()
        self._job = Work(action)
        self._completion = complete
        self._job.signals.finished.connect(self.finishWork)
        self.pool.start(self._job)

    @Slot(object, str)
    def finishWork(self, result, error):
        self._busy = False
        self.busyChanged.emit()
        if error:
            self.message.emit(error)
        else:
            self._completion(result)

    def loadFolder(self, path, history_cursor=None, add=True):
        def complete(entries):
            self._path, self._files = path, entries
            if history_cursor is not None:
                self._cursor = history_cursor
            elif add and path != self._history[self._cursor]:
                self._history = self._history[:self._cursor + 1] + [path]
                self._cursor += 1
            if self.watcher.directories():
                self.watcher.removePaths(self.watcher.directories())
            self.watcher.addPath(path)
            self.filesChanged.emit()
        self.work(lambda: list_folder(path, self._hidden), complete)

    @Slot(str)
    def navigate(self, path):
        self.loadFolder(str(Path(path).expanduser().absolute()))

    @Slot()
    def refresh(self):
        if not self._busy:
            self.loadFolder(self._path, add=False)

    @Slot()
    def back(self):
        if self.canBack:
            self.loadFolder(self._history[self._cursor - 1], self._cursor - 1, False)

    @Slot()
    def forward(self):
        if self.canForward:
            self.loadFolder(self._history[self._cursor + 1], self._cursor + 1, False)

    @Slot()
    def up(self): self.navigate(str(Path(self._path).parent))

    @Slot(bool)
    def showHidden(self, value):
        self._hidden = value
        self.refresh()

    @Slot(str)
    def openFile(self, path):
        if Path(path).is_dir():
            self.navigate(path)
        elif not QDesktopServices.openUrl(QUrl.fromLocalFile(path)):
            self.message.emit("No se pudo abrir el archivo. Revisa las aplicaciones predeterminadas.")

    @Slot(str)
    def newFolder(self, name):
        try:
            (Path(self._path) / safe_name(name)).mkdir()
            self.refresh()
        except (OSError, ValueError) as error:
            self.message.emit(str(error))

    @Slot(str, str)
    def rename(self, path, name):
        try:
            source = Path(path)
            target = source.with_name(safe_name(name))
            if target.exists() or target.is_symlink():
                raise FileExistsError("Ese nombre ya existe.")
            # Linux renameat2 RENAME_NOREPLACE avoids races and replacing user data.
            import ctypes
            libc = ctypes.CDLL(None, use_errno=True)
            if libc.renameat2(-100, os.fsencode(source), -100, os.fsencode(target), 1):
                errno = ctypes.get_errno()
                raise OSError(errno, os.strerror(errno))
            self.refresh()
        except (OSError, ValueError) as error:
            self.message.emit(str(error))

    @Slot(str)
    def copy(self, path):
        self._clipboard = path
        self.message.emit("Copiado. Abre la carpeta de destino y pulsa Pegar.")

    @Slot()
    def paste(self):
        if self._clipboard:
            source, target = self._clipboard, self._path
            self.work(lambda: copy_entry(source, target), lambda _: self.refresh())

    @Slot(str)
    def trash(self, path):
        def action():
            ok, _ = QFile.moveToTrash(path)
            if not ok:
                raise OSError("No se pudo mover a la papelera. El archivo sigue en su sitio.")
        self.work(action, lambda _: self.refresh())

    @Slot(str, str, str, result=str)
    def saveNote(self, note_id, title, body):
        try:
            value = self.notes_store.save(note_id, title, body)
            self.notesChanged.emit()
            return value
        except Exception as error:
            self.message.emit("No se guardó la nota: " + str(error))
            return ""

    @Slot(str, result=bool)
    def deleteNote(self, note_id):
        try:
            self.notes_store.delete(note_id)
            self.notesChanged.emit()
            return True
        except Exception as error:
            self.message.emit(str(error))
            return False

    @Slot(str, str, str)
    def createProject(self, parent, name, template):
        self.work(lambda: str(create_project(parent, name, template)), self.projectCreated.emit)

    def launch(self, args):
        friendly = {"dylanos-store": "DylanOS Store", "dylanos-explorer": "Archivos", "plasma-systemmonitor": "Monitor del sistema",
                    "systemsettings": "Ajustes del sistema", "konsole": "Terminal", "dolphin": "Archivos"}
        if not shutil.which(args[0]):
            self.message.emit(f"{friendly.get(args[0], args[0])} no está instalado. Puedes instalarlo desde DylanOS Store.")
            return False
        ok, _ = QProcess.startDetached(args[0], args[1:])
        if not ok:
            self.message.emit("No se pudo iniciar " + friendly.get(args[0], args[0]))
        return ok

    @Slot(str)
    def openApp(self, page):
        if page == "files":
            self.action("files")
        elif page in ("welcome", "notes", "dev", "monitor", "settings"):
            self.launch([sys.executable, str(Path(__file__).with_name("main.py")), "--page", page])

    @Slot(bool)
    def pauseMonitor(self, paused):
        if paused:
            self.timer.stop()
        else:
            self.updateStats()
            self.timer.start(2500)

    @Slot(str)
    def action(self, name):
        commands = {
            "terminal": ["konsole"], "editor": ["codium"], "browser": ["firefox-esr"],
            "settings": ["systemsettings"], "network": ["systemsettings", "kcm_networkmanagement"],
            "bluetooth": ["systemsettings", "kcm_bluetooth"], "audio": ["systemsettings", "kcm_pulseaudio"],
            "display": ["systemsettings", "kcm_kscreen"], "power": ["systemsettings", "kcm_powerdevilprofilesconfig"],
            "keyboard": ["systemsettings", "kcm_keyboard"], "users": ["systemsettings", "kcm_users"],
            "appearance": ["systemsettings", "kcm_lookandfeel"],
            "store": ["dylanos-store"], "updates": ["dylanos-store", "--mode", "Update"],
            "calculator": ["dylanos-calculator"], "monitor": ["plasma-systemmonitor"], "files": ["dylanos-explorer"],
            "screenshot": ["spectacle"], "documents": ["libreoffice"], 
        }
        if name in commands:
            self.launch(commands[name])

    @Slot(str, str)
    def openProject(self, path, app):
        if not Path(path).is_dir():
            self.message.emit("La carpeta del proyecto no existe.")
            return
        if app == "terminal": self.launch(["konsole", "--workdir", path])
        elif app == "editor": self.launch(["codium", "--", path])
        elif app == "files": QDesktopServices.openUrl(QUrl.fromLocalFile(path))

    @Slot(str)
    def findSoftware(self, query): self.launch(["dylanos-store", "--search", query])

    @Slot(str)
    def theme(self, variant):
        if variant not in ("Dark", "Light"):
            return
        program = "plasma-apply-colorscheme"
        if not shutil.which(program):
            self.message.emit("El cambio del escritorio requiere una sesión KDE Plasma.")
            return
        def apply():
            decoration = "DylanOS-Crimson" + ("-Light" if variant == "Light" else "")
            commands = [[program, "DylanOS" + variant],
                        ["kwriteconfig6", "--file", "kwinrc", "--group", "org.kde.kdecoration2", "--key", "theme", "__aurorae__svg__" + decoration]]
            qdbus = shutil.which("qdbus6") or shutil.which("qdbus") or "/usr/lib/qt6/bin/qdbus"
            commands.append([qdbus, "org.kde.KWin", "/KWin", "reconfigure"])
            for command in commands:
                result = subprocess.run(command, capture_output=True, text=True, timeout=20)
                if result.returncode:
                    raise OSError("No se completó el cambio de apariencia: " + result.stderr.strip()[:300])
            # Persist both GTK versions without clobbering other user settings.
            gtk_theme = "DylanOS-Crimson" + ("-Light" if variant == "Light" else "")
            config_root = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))
            for version in ("gtk-3.0", "gtk-4.0"):
                settings_path = config_root / version / "settings.ini"
                settings = configparser.ConfigParser(interpolation=None)
                settings.optionxform = str
                settings.read(settings_path)
                if not settings.has_section("Settings"):
                    settings.add_section("Settings")
                settings.set("Settings", "gtk-theme-name", gtk_theme)
                settings.set("Settings", "gtk-icon-theme-name", "breeze-dark" if variant == "Dark" else "breeze")
                settings.set("Settings", "gtk-application-prefer-dark-theme", "1" if variant == "Dark" else "0")
                settings_path.parent.mkdir(parents=True, exist_ok=True)
                temporary = settings_path.with_suffix(".ini.dylanos-tmp")
                with temporary.open("w") as handle:
                    settings.write(handle, space_around_delimiters=False)
                temporary.replace(settings_path)
            # GTK's desktop portal/color preference is published by Plasma.
            if shutil.which("gsettings"):
                for key, value in (("gtk-theme", gtk_theme), ("color-scheme", "prefer-dark" if variant == "Dark" else "prefer-light")):
                    result = subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", key, value], capture_output=True, text=True, timeout=10)
                    if result.returncode:
                        raise OSError("El tema se guardó, pero no se pudo notificar a GTK: " + result.stderr.strip()[:200])
        self.work(apply, lambda _: self.message.emit("Apariencia actualizada. Algunas apps GTK requieren volver a abrirse."))

    @Slot()
    def scanTools(self):
        self._tools = [dict(name=name, command=command, installed=bool(shutil.which(command)),
                            path=shutil.which(command) or "No instalado")
                       for name, command in [("Git", "git"), ("Python", "python3"), ("Node.js", "node"),
                       ("npm", "npm"), ("C / C++", "g++"), ("CMake", "cmake"), ("VSCodium", "codium"),
                       ("Podman", "podman"), ("GDB", "gdb"), ("SSH", "ssh")]]
        self.toolsChanged.emit()

    @Slot()
    def updateStats(self):
        try:
            memory = psutil.virtual_memory()
            disk = psutil.disk_usage(str(Path.home()))
            battery = psutil.sensors_battery()
            boot = psutil.boot_time()
            cpu = round(psutil.cpu_percent())
            processes = []
            for proc in (psutil.process_iter(["pid", "name", "memory_info"]) if self._page in (None, "monitor") else []):
                try:
                    info = proc.info
                    if info.get("memory_info"):
                        processes.append(dict(pid=info["pid"], name=info["name"] or "Proceso",
                                              memory=human_size(info["memory_info"].rss), rss=info["memory_info"].rss))
                except (psutil.Error, OSError, KeyError):
                    continue
        except (psutil.Error, OSError):
            class _FallbackMem:
                percent = 0; used = 0; total = 1024 * 1024 * 1024
            class _FallbackDisk:
                percent = 0; free = 10 * 1024 * 1024 * 1024
            memory = _FallbackMem()
            disk = _FallbackDisk()
            battery = None
            boot = time.time()
            cpu = 0
            processes = []

        self._cpu_history = (self._cpu_history + [cpu])[-60:]
        self._memory_history = (self._memory_history + [round(memory.percent)])[-60:]
        self._stats = dict(cpu=cpu, memory=round(memory.percent),
                           cpuHistory=self._cpu_history, memoryHistory=self._memory_history,
                           processCount=len(processes),
                           memoryText=f"{human_size(memory.used)} de {human_size(memory.total)}",
                           disk=round(disk.percent), free=human_size(disk.free),
                           uptime=f"{int((time.time() - boot) / 3600)} h",
                           battery=f"{round(battery.percent)} %" if battery else "Sin batería",
                           host=platform.node(), kernel=platform.release(),
                           processes=sorted(processes, key=lambda p: p["rss"], reverse=True))
        self.statsChanged.emit()
