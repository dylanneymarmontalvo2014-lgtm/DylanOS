"""Qt bridge. Actions use argument arrays; desktop operations retain OS policy."""
import os
from pathlib import Path
import platform
import shutil
import time
import subprocess

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

    def __init__(self):
        super().__init__()
        self._path = str(Path.home())
        self._files, self._history, self._cursor = [], [self._path], 0
        self._hidden, self._busy = False, False
        self._clipboard = ""
        self._stats = {}
        self._tools = []
        data = QStandardPaths.writableLocation(QStandardPaths.AppDataLocation)
        self.notes_store = Notes(Path(data))
        self.pool = QThreadPool(self)
        self.pool.setMaxThreadCount(1)
        self.watcher = QFileSystemWatcher(self)
        self.watcher.directoryChanged.connect(self.refresh)
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.updateStats)
        self.timer.start(2500)
        self.updateStats()
        self.refresh()
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
        if not shutil.which(args[0]):
            self.message.emit(f"{args[0]} no está instalado. Puedes instalarlo desde Software.")
            return False
        ok, _ = QProcess.startDetached(args[0], args[1:])
        if not ok:
            self.message.emit("No se pudo iniciar " + args[0])
        return ok

    @Slot(str)
    def action(self, name):
        commands = {
            "terminal": ["konsole"], "editor": ["codium"], "browser": ["firefox-esr"],
            "settings": ["systemsettings"], "network": ["systemsettings", "kcm_networkmanagement"],
            "bluetooth": ["systemsettings", "kcm_bluetooth"], "audio": ["systemsettings", "kcm_pulseaudio"],
            "display": ["systemsettings", "kcm_kscreen"], "power": ["systemsettings", "kcm_powerdevilprofilesconfig"],
            "keyboard": ["systemsettings", "kcm_keyboard"], "users": ["systemsettings", "kcm_users"],
            "appearance": ["systemsettings", "kcm_lookandfeel"],
            "store": ["plasma-discover"], "updates": ["plasma-discover", "--mode", "Update"],
            "calculator": ["dylanos-calculator"], "monitor": ["plasma-systemmonitor"],
            "screenshot": ["spectacle"], "documents": ["libreoffice"], "files": ["dolphin"],
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
    def findSoftware(self, query): self.launch(["plasma-discover", "--search", query])

    @Slot(str)
    def theme(self, variant):
        if variant not in ("Dark", "Light"):
            return
        program = "plasma-apply-colorscheme"
        if not shutil.which(program):
            self.message.emit("El cambio del escritorio requiere una sesión KDE Plasma.")
            return
        def apply():
            decoration = "DylanOS-Tahoe" + ("-Light" if variant == "Light" else "")
            commands = [[program, "DylanOS" + variant],
                        ["kwriteconfig6", "--file", "kwinrc", "--group", "org.kde.kdecoration2", "--key", "theme", "__aurorae__svg__" + decoration]]
            qdbus = shutil.which("qdbus6") or shutil.which("qdbus") or "/usr/lib/qt6/bin/qdbus"
            commands.append([qdbus, "org.kde.KWin", "/KWin", "reconfigure"])
            for command in commands:
                result = subprocess.run(command, capture_output=True, text=True, timeout=20)
                if result.returncode:
                    raise OSError("No se completó el cambio de apariencia: " + result.stderr.strip()[:300])
        self.work(apply, lambda _: self.message.emit("Apariencia del escritorio actualizada."))

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
        memory, disk = psutil.virtual_memory(), psutil.disk_usage(str(Path.home()))
        battery = psutil.sensors_battery()
        processes = []
        for proc in psutil.process_iter(["pid", "name", "memory_info", "username"]):
            try:
                info = proc.info
                if info["memory_info"]:
                    processes.append(dict(pid=info["pid"], name=info["name"] or "Proceso",
                                          memory=human_size(info["memory_info"].rss), rss=info["memory_info"].rss))
            except (psutil.Error, OSError):
                continue
        self._stats = dict(cpu=round(psutil.cpu_percent()), memory=round(memory.percent),
                           memoryText=f"{human_size(memory.used)} de {human_size(memory.total)}",
                           disk=round(disk.percent), free=human_size(disk.free),
                           uptime=f"{int((time.time() - psutil.boot_time()) / 3600)} h",
                           battery=f"{round(battery.percent)} %" if battery else "Sin batería",
                           host=platform.node(), kernel=platform.release(),
                           processes=sorted(processes, key=lambda p: p["rss"], reverse=True)[:30])
        self.statsChanged.emit()
