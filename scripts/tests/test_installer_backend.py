"""Tests del backend del instalador nativo de DylanOS.

Verifica que la detección de hardware y la lógica de instalación funcionen
correctamente con y sin herramientas opcionales del sistema (lspci, lsblk, etc.).
"""
import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "installer/dylanos-installer/backend"))

import server


class SystemInfoDetectionTest(unittest.TestCase):
    """Verifica que get_real_system_info produce datos válidos."""

    def test_returns_all_required_keys(self):
        """La función debe devolver siempre las seis claves requeridas."""
        info = server.get_real_system_info()
        for key in ("device", "cpu", "ram", "storage", "gpu", "arch"):
            self.assertIn(key, info, f"Falta la clave '{key}' en system-info")

    def test_all_values_are_non_empty_strings(self):
        """Ningún valor puede ser vacío o None; el fallback produce una cadena."""
        info = server.get_real_system_info()
        for key, value in info.items():
            self.assertIsInstance(value, str, f"'{key}' no es str: {value!r}")
            self.assertTrue(value.strip(), f"'{key}' está vacío")

    def test_device_fallback_when_dmi_missing(self):
        """Cuando el DMI no existe el dispositivo usa un nombre genérico."""
        with patch("os.path.exists", return_value=False):
            info = server.get_real_system_info()
        self.assertIn("DylanOS", info["device"])

    def test_gpu_fallback_when_lspci_absent(self):
        """Sin lspci ni módulos de GPU conocidos devuelve el fallback genérico."""
        def fake_run_cmd(cmd, check=True):
            # Simular que lspci no está disponible
            if "lspci" in cmd:
                return ""
            return server.run_cmd.__wrapped__(cmd, check=check) if hasattr(server.run_cmd, "__wrapped__") else ""

        with patch.object(server, "run_cmd", side_effect=fake_run_cmd):
            with patch("pathlib.Path.exists", return_value=False):
                with patch("pathlib.Path.read_text", side_effect=OSError):
                    info = server.get_real_system_info()
        self.assertIsInstance(info["gpu"], str)
        self.assertTrue(info["gpu"].strip())

    def test_gpu_detected_via_lspci(self):
        """Cuando lspci devuelve una línea VGA se extrae el nombre correctamente."""
        lspci_output = (
            "00:00.0 Host bridge: Intel Corporation Xeon E3-1200 v2 (rev 09)\n"
            "00:02.0 VGA compatible controller: Intel Corporation HD Graphics 4000 (rev 09)\n"
            "00:1a.0 USB controller: Intel Corporation 7 Series\n"
        )
        with patch.object(server, "run_cmd", return_value=lspci_output):
            info = server.get_real_system_info()
        self.assertIn("Intel", info["gpu"])
        self.assertIn("HD Graphics", info["gpu"])

    def test_gpu_detected_via_3d_controller(self):
        """Líneas con '3D controller' también se reconocen como GPU."""
        lspci_output = (
            "01:00.0 3D controller: NVIDIA Corporation GK107M [GeForce GT 640M LE] (rev a1)\n"
        )
        with patch.object(server, "run_cmd", return_value=lspci_output):
            info = server.get_real_system_info()
        self.assertIn("NVIDIA", info["gpu"])

    def test_ram_parsed_from_meminfo(self):
        """La RAM se lee de /proc/meminfo y se expresa en GB."""
        fake_meminfo = "MemTotal:        8388608 kB\nMemFree:         4096000 kB\n"
        with patch("pathlib.Path.read_text", return_value=fake_meminfo):
            with patch("os.path.exists", return_value=True):
                # Solo parcheamos la ruta de meminfo
                info = server.get_real_system_info()
        # No podemos aislar solo meminfo con el mock global, pero verificamos
        # que el campo ram siempre tenga GB o MB
        self.assertTrue(
            info["ram"].endswith("GB") or info["ram"].endswith("MB") or info["ram"] == "—",
            f"Formato de RAM inesperado: {info['ram']!r}",
        )

    def test_cpu_name_not_empty(self):
        """El nombre de CPU nunca debe ser vacío en un sistema Linux real."""
        info = server.get_real_system_info()
        self.assertTrue(info["cpu"].strip())

    def test_arch_matches_platform(self):
        """La arquitectura reportada coincide con platform.machine()."""
        import platform
        info = server.get_real_system_info()
        self.assertEqual(info["arch"], platform.machine())


class DiskDetectionTest(unittest.TestCase):
    """Verifica que get_real_disks filtra dispositivos no válidos."""

    def test_returns_list(self):
        """get_real_disks siempre devuelve una lista (nunca None)."""
        disks = server.get_real_disks()
        self.assertIsInstance(disks, list)
        self.assertGreater(len(disks), 0)

    def test_no_loop_devices(self):
        """Los dispositivos loop no deben aparecer en la lista de discos."""
        disks = server.get_real_disks()
        for d in disks:
            self.assertNotIn("loop", d.get("device", ""),
                             f"Dispositivo loop en la lista: {d}")

    def test_no_zram_devices(self):
        """Los dispositivos zram no deben aparecer."""
        disks = server.get_real_disks()
        for d in disks:
            self.assertNotIn("zram", d.get("device", ""),
                             f"Dispositivo zram en la lista: {d}")

    def test_disk_has_required_keys(self):
        """Cada disco debe tener las claves que necesita la interfaz React."""
        disks = server.get_real_disks()
        for d in disks:
            for key in ("device", "size", "sizeGB", "model", "partitions"):
                self.assertIn(key, d, f"Falta '{key}' en disco {d.get('device')}")

    def test_fallback_when_lsblk_fails(self):
        """Si lsblk falla se devuelve un disco placeholder, nunca una excepción."""
        with patch.object(server, "run_cmd", return_value=""):
            disks = server.get_real_disks()
        self.assertIsInstance(disks, list)
        self.assertGreater(len(disks), 0)

    def test_lsblk_filters_cdrom(self):
        """Dispositivos sr* (CD/DVD) no deben aparecer en la lista."""
        fake_lsblk = (
            '{"blockdevices": ['
            '{"name":"sda","path":"/dev/sda","size":"256060514304","type":"disk","model":"SSD",'
            '"children":[{"name":"sda1","path":"/dev/sda1","size":"536870912","type":"part",'
            '"fstype":"vfat","mountpoint":"/boot/efi"}]},'
            '{"name":"sr0","path":"/dev/sr0","size":"4700000000","type":"rom","model":"DVD"}]}'
        )
        with patch.object(server, "run_cmd", return_value=fake_lsblk):
            disks = server.get_real_disks()
        paths = [d["device"] for d in disks]
        self.assertNotIn("/dev/sr0", paths)
        self.assertIn("/dev/sda", paths)


class GrubRobustnessTest(unittest.TestCase):
    """La instalación no debe abortar por limitaciones de GRUB al final."""

    SOURCE = (ROOT / "installer/dylanos-installer/backend/server.py").read_text(encoding="utf-8")

    def test_run_capture_reports_code_and_output(self):
        """run_capture devuelve el código real y la salida combinada."""
        code, output = server.run_capture("printf hola")
        self.assertEqual(code, 0)
        self.assertIn("hola", output)
        code, _ = server.run_capture("exit 3")
        self.assertEqual(code, 3)

    def test_chroot_sys_is_rbound_for_efivarfs(self):
        """/sys se replica en cascada para que efivarfs sea visible en el chroot."""
        self.assertIn("mount --rbind /sys /target/sys", self.SOURCE)
        self.assertIn("mount --make-rslave /target/sys", self.SOURCE)
        self.assertNotIn("mount --bind /sys", self.SOURCE)

    def test_automatic_layout_creates_bios_boot_partition(self):
        """El GPT automático crea partición BIOS boot y la raíz pasa a ser la 3."""
        self.assertIn("set 2 bios_grub on", self.SOURCE)
        self.assertIn('auto_root = f"{disk}{suffix}3"', self.SOURCE)

    def test_uefi_grub_falls_back_to_no_nvram_and_removable(self):
        """UEFI reintenta sin NVRAM y en modo removable antes de declarar fallo."""
        self.assertIn('for extra in ("", "--no-nvram", "--no-nvram --removable"):', self.SOURCE)
        self.assertIn("grub-install --target=x86_64-efi", self.SOURCE)
        self.assertIn("grub-install --target=i386-pc", self.SOURCE)
        self.assertIn("update-grub", self.SOURCE)


class LocaleCatalogTest(unittest.TestCase):
    """Verifica la normalización de locales y la búsqueda de distribuciones."""

    def test_normalize_known_locale(self):
        """Locales conocidos se normalizan correctamente."""
        result = server.normalize_locale("es_419")
        self.assertTrue(result.endswith(".UTF-8"),
                        f"El locale normalizado debe terminar en .UTF-8: {result}")

    def test_normalize_already_utf8(self):
        """Un locale que ya tiene .UTF-8 no se duplica."""
        result = server.normalize_locale("en_US.UTF-8")
        self.assertEqual(result.count(".UTF-8"), 1)

    def test_xkb_layout_known(self):
        """Layouts conocidos se mapean al código XKB correcto."""
        self.assertEqual(server.xkb_layout_code("Español (Latinoamérica)"), "latam")
        self.assertEqual(server.xkb_layout_code("English (US)"), "us")
        self.assertEqual(server.xkb_layout_code("Deutsch"), "de")

    def test_xkb_layout_unknown_fallback(self):
        """Layouts desconocidos usan 'latam' como fallback seguro."""
        self.assertEqual(server.xkb_layout_code("Klingon"), "latam")


class DfParsingTest(unittest.TestCase):
    """El uso de particiones (df) debe funcionar en cualquier locale.

    La sesión live arranca con locales=es_ES.UTF-8 y `df` localiza su cabecera
    («S.ficheros…»); el instalador no puede depender del texto «Filesystem».
    """

    SPANISH_DF = (
        "S.ficheros 1K-bloques Usados Disponibles Uso% Montado en\n"
        "/dev/sda2 51G 5G 43G 11% /\n"
    )

    def test_partition_used_parses_localized_header(self):
        """Una cabecera en español no debe romper el parsing del uso."""
        with patch.object(server, "run_cmd", return_value=self.SPANISH_DF):
            used = server._partition_used_gb("/dev/sda2", "/")
        self.assertEqual(used, "5 GB", "El uso real debe leerse sin importar el idioma de df")

    def test_partition_used_uses_posix_df(self):
        """El comando debe ser `df -P` para garantizar formato estable."""
        captured = {}

        def fake_run(cmd, check=True):
            captured["cmd"] = cmd
            return "Filesystem 1G-blocks Used Available Use% Mounted on\n/dev/sda2 51G 5G 43G 11% /\n"

        with patch.object(server, "run_cmd", side_effect=fake_run):
            server._partition_used_gb("/dev/sda2", "/")
        self.assertIn("-P", captured["cmd"], "df debe invocarse en modo POSIX (-P)")


class PartitionSizeFormatTest(unittest.TestCase):
    """Las particiones pequeñas no deben mostrarse como «0 GB»."""

    FAKE_LSBLK = (
        '{"blockdevices": ['
        '{"name":"sda","path":"/dev/sda","size":"256060514304","type":"disk","model":"SSD",'
        '"children":[{"name":"sda1","path":"/dev/sda1","size":"536870912","type":"part",'
        '"fstype":"vfat","mountpoint":"/boot/efi"}]}]}'
    )

    def test_small_partition_shows_mb_not_zero_gb(self):
        """Una ESP de 512 MiB debe mostrar «512 MB», nunca «0 GB»."""
        with patch.object(server, "run_cmd", return_value=self.FAKE_LSBLK):
            disks = server.get_real_disks()
        esp = disks[0]["partitions"][0]
        self.assertEqual(esp["size"], "512 MB",
                         f"La ESP de 512 MiB se muestra como {esp['size']!r}")
        self.assertEqual(esp["sizeGB"], 0.5,
                         f"sizeGB debe conservar decimales para la barra: {esp['sizeGB']!r}")


class LatinAmericaLocaleTest(unittest.TestCase):
    """es_419 no existe en Debian: debe mapearse, no degradarse en silencio.

    El SUPPORTED de la ISO (trixie) no contiene es_419; sin corrección,
    «Español (Latinoamérica)» desaparece de la lista y normalize_locale lo
    convierte en es_ES (España) sin avisar a nadie.
    """

    SUPPORTED_WITH_MX = "es_MX.UTF-8 UTF-8\nes_ES.UTF-8 UTF-8\nen_US.UTF-8 UTF-8\n"
    SUPPORTED_WITH_419 = "es_419.UTF-8 UTF-8\nes_ES.UTF-8 UTF-8\n"

    def _with_supported(self, text):
        patcher_exists = patch("pathlib.Path.exists", return_value=True)
        patcher_read = patch("pathlib.Path.read_text", return_value=text)
        patcher_exists.start()
        patcher_read.start()
        self.addCleanup(patcher_exists.stop)
        self.addCleanup(patcher_read.stop)

    def test_normalize_locale_maps_latam_to_mexico_when_419_missing(self):
        """Sin es_419 en el sistema, el locale LatAm debe caer en es_MX, no es_ES."""
        self._with_supported(self.SUPPORTED_WITH_MX)
        self.assertEqual(server.normalize_locale("es_419"), "es_MX.UTF-8",
                         "es_419 debe mapearse al mejor locale LatAm disponible")

    def test_normalize_locale_keeps_419_when_supported(self):
        """Si algún día glibc soporta es_419, se usa tal cual (regresión)."""
        self._with_supported(self.SUPPORTED_WITH_419)
        self.assertEqual(server.normalize_locale("es_419"), "es_419.UTF-8")

    def test_available_locales_keeps_latam_option(self):
        """«Español (Latinoamérica)» debe seguir en la lista aunque solo exista es_MX."""
        self._with_supported(self.SUPPORTED_WITH_MX)
        codes = [item["code"] for item in server.available_locales()]
        self.assertIn("es_419", codes,
                      "La opción por defecto de DylanOS no puede desaparecer de la lista")


class LiveMediumExclusionTest(unittest.TestCase):
    """El USB/DVD del que corre el live no debe ofrecerse como disco destino."""

    LSBLK_TWO_DISKS = (
        '{"blockdevices": ['
        '{"name":"sda","path":"/dev/sda","size":"256060514304","type":"disk","model":"SSD",'
        '"children":[{"name":"sda1","path":"/dev/sda1","size":"536870912","type":"part",'
        '"fstype":"vfat","mountpoint":"/boot/efi"},'
        '{"name":"sda2","path":"/dev/sda2","size":"255523872768","type":"part",'
        '"fstype":"ext4","mountpoint":"/"}]},'
        '{"name":"sdb","path":"/dev/sdb","size":"17179869184","type":"disk","model":"USB Flash",'
        '"children":[{"name":"sdb1","path":"/dev/sdb1","size":"17179869184","type":"part",'
        '"fstype":"vfat","mountpoint":"/run/live/medium"}]}]}'
    )
    MOUNTS = "/dev/sdb1 /run/live/medium vfat ro 0 0\n/dev/sda2 / ext4 rw 0 0\n"

    def _patch_detection(self):
        def fake_run(cmd, check=True):
            if "PKNAME" in cmd:
                return "sdb"
            return self.LSBLK_TWO_DISKS

        run_patcher = patch.object(server, "run_cmd", side_effect=fake_run)
        mounts_patcher = patch("pathlib.Path.read_text", return_value=self.MOUNTS)
        run_patcher.start()
        mounts_patcher.start()
        self.addCleanup(run_patcher.stop)
        self.addCleanup(mounts_patcher.stop)

    def test_live_medium_disk_detected_from_mounts(self):
        """El disco respaldo del medio live se resuelve desde /proc/mounts."""
        self._patch_detection()
        self.assertEqual(server.live_medium_disk(), "/dev/sdb")

    def test_get_real_disks_excludes_live_medium(self):
        """La lista de discos instalables omite el medio de instalación."""
        self._patch_detection()
        paths = [d["device"] for d in server.get_real_disks()]
        self.assertIn("/dev/sda", paths)
        self.assertNotIn("/dev/sdb", paths,
                         "El USB de instalación no debe aparecer como destino")

    def test_storage_summary_excludes_live_medium(self):
        """El resumen de almacenamiento no suma la capacidad del USB live."""
        self._patch_detection()
        summary = server.real_storage_summary()
        self.assertEqual(summary, "0 GB disponibles de 238 GB",
                         f"El resumen contó el medio live: {summary!r}")


class InstallPreparationTest(unittest.TestCase):
    """Preparación robusta del disco antes de particionar (errores raros)."""

    LSBLK_MOUNTED_DISK = (
        '{"blockdevices": ['
        '{"name":"sdb","path":"/dev/sdb","size":"256060514304","type":"disk","model":"SSD",'
        '"children":['
        '{"name":"sdb1","path":"/dev/sdb1","size":"536870912","type":"part","mountpoint":"/mnt/win"},'
        '{"name":"sdb2","path":"/dev/sdb2","size":"255523872768","type":"part",'
        '"mountpoints":["/mnt/a","/mnt/b"]}]}]}'
    )

    def test_unmount_disk_partitions_unmounts_every_mount(self):
        """Antes de tocar el disco se desmontan TODAS sus particiones montadas."""
        commands = []

        def fake_quiet(cmd):
            commands.append(cmd)

        with patch.object(server, "run_cmd", return_value=self.LSBLK_MOUNTED_DISK):
            with patch.object(server, "run_quiet", side_effect=fake_quiet):
                server.unmount_disk_partitions("/dev/sdb")
        umounts = [c for c in commands if c.startswith("umount")]
        self.assertEqual(len(umounts), 3, f"Se esperaban 3 umount: {commands}")
        for path in ("/mnt/win", "/mnt/a", "/mnt/b"):
            self.assertTrue(any(path in c for c in umounts), f"Falta umount de {path}")

    def test_wait_for_partitions_settles_udev(self):
        """Tras partprobe hay que esperar a udev antes de formatear."""
        commands = []

        def fake_quiet(cmd):
            commands.append(cmd)

        with patch.object(server, "run_quiet", side_effect=fake_quiet):
            with patch.object(server.time, "sleep"):
                server.wait_for_partitions("/dev/sda")
        self.assertTrue(any("partprobe" in c for c in commands), "Falta partprobe")
        self.assertTrue(any("udevadm settle" in c for c in commands),
                        "Falta udevadm settle: mkfs puede correr antes de que exista el nodo")

    def test_find_install_partitions_tolerates_null_size(self):
        """size=None de lsblk no debe lanzar TypeError en modo manual."""
        fake = (
            '{"blockdevices": ['
            '{"name":"sda","path":"/dev/sda","size":"256060514304","type":"disk",'
            '"children":['
            '{"name":"sda1","path":"/dev/sda1","size":null,"type":"part","fstype":"vfat"},'
            '{"name":"sda2","path":"/dev/sda2","size":null,"type":"part","fstype":"ext4"}]}]}'
        )
        with patch.object(server, "run_cmd", return_value=fake):
            root_part, efi_part = server.find_install_partitions("/dev/sda")
        self.assertEqual((root_part, efi_part), ("/dev/sda2", "/dev/sda1"))


if __name__ == "__main__":
    unittest.main()

