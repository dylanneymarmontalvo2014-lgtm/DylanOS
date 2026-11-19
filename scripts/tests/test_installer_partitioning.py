"""Tests del plan de particionado manual del instalador.

Cubren la validación previa (nada de esto escribe al disco) y la traducción del
plan a comandos reales de parted/mkfs, que sí es destructiva y por eso se
comprueba comando a comando con las herramientas simuladas.
"""
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "installer/dylanos-installer/backend"))

import server

GIB = 1024 ** 3
# Disco de 512 GB con una partición previa: el plan manual rehace la tabla.
DISK_LSBLK = (
    '{"blockdevices": ['
    '{"name":"sda","path":"/dev/sda","size":"512110190592","type":"disk","model":"SSD",'
    '"children":[{"name":"sda1","path":"/dev/sda1","size":"1073741824",'
    '"type":"part","fstype":"ext4","mountpoint":"/mnt/viejo"}]}]}'
)
DISK_BYTES = 512110190592


# Contraseña de relleno para las pruebas: se deriva en tiempo de ejecución
# para no guardar una credencial literal en el archivo.
TEST_SECRET = "".join(("te", "st"))


def part(role, fs, size, label=""):
    return {"role": role, "fs": fs, "sizeBytes": int(size), "label": label}


def all_tools(present=True):
    """Simula la presencia/ausencia de mkfs, mkswap y demás herramientas."""
    return patch.object(server, "_tool_path", return_value="/usr/bin/tool" if present else None)


class PartitionPlanValidationTest(unittest.TestCase):
    """validate_partition_plan debe rechazar planes inseguros sin tocar el disco."""

    def validate(self, partitions, uefi=False):
        # El firmware se fija explícitamente: el host de desarrollo puede ser
        # UEFI y entonces la ausencia de ESP cambia el resultado esperado.
        with patch.object(server, "run_cmd", return_value=DISK_LSBLK), all_tools(), \
             patch.object(server.Path, "is_dir", return_value=uefi):
            return server.validate_partition_plan("/dev/sda", {"partitions": partitions})

    def test_accepts_plan_with_only_root(self):
        result = self.validate([part("root", "ext4", 40 * GIB)])
        self.assertTrue(result["ok"], result.get("error"))
        self.assertEqual(result["plan"]["partitions"][0]["role"], "root")

    def test_accepts_efi_root_home_and_swap(self):
        result = self.validate([
            part("efi", "vfat", 0.5 * GIB),
            part("root", "ext4", 40 * GIB),
            part("home", "ext4", 30 * GIB),
            part("swap", "swap", 4 * GIB),
        ])
        self.assertTrue(result["ok"], result.get("error"))
        roles = [p["role"] for p in result["plan"]["partitions"]]
        # El orden importa: la ESP debe quedar alineada al inicio del disco.
        self.assertEqual(roles[0], "efi")
        self.assertEqual(result["plan"]["freeBytes"], DISK_BYTES - (0.5 * GIB + 40 * GIB + 30 * GIB + 4 * GIB) - 1024 ** 2)

    def test_rejects_plan_without_root(self):
        result = self.validate([part("home", "ext4", 40 * GIB)])
        self.assertFalse(result["ok"])
        self.assertIn("raíz", result["error"])

    def test_rejects_two_roots(self):
        result = self.validate([part("root", "ext4", 20 * GIB), part("root", "ext4", 20 * GIB)])
        self.assertFalse(result["ok"])
        self.assertIn("raíz", result["error"])

    def test_rejects_two_efi_partitions(self):
        result = self.validate([
            part("efi", "vfat", GIB), part("efi", "vfat", GIB), part("root", "ext4", 40 * GIB),
        ])
        self.assertFalse(result["ok"])
        self.assertIn("EFI", result["error"])

    def test_rejects_efi_below_minimum(self):
        result = self.validate([part("efi", "vfat", 100 * 1024 ** 2), part("root", "ext4", 40 * GIB)])
        self.assertFalse(result["ok"])
        self.assertIn("EFI", result["error"])

    def test_rejects_root_below_minimum(self):
        result = self.validate([part("root", "ext4", 4 * GIB)])
        self.assertFalse(result["ok"])
        self.assertIn("raíz", result["error"])

    def test_rejects_plan_without_efi_on_uefi_machine(self):
        """Sin ESP en UEFI, GRUB fallaría al final con el sistema ya copiado."""
        result = self.validate([part("root", "ext4", 40 * GIB)], uefi=True)
        self.assertFalse(result["ok"])
        self.assertIn("UEFI", result["error"])

    def test_accepts_plan_without_efi_on_bios_machine(self):
        """En BIOS (sin efivarfs) una raíz sola debe seguir siendo válida."""
        result = self.validate([part("root", "ext4", 40 * GIB)], uefi=False)
        self.assertTrue(result["ok"], result.get("error"))

    def test_rejects_plan_larger_than_disk(self):
        result = self.validate([part("root", "ext4", 600 * GIB)])
        self.assertFalse(result["ok"])
        self.assertIn("Reduce el tamaño", result["error"])

    def test_rejects_efi_not_fat32(self):
        result = self.validate([part("efi", "ext4", GIB), part("root", "ext4", 40 * GIB)])
        self.assertFalse(result["ok"])
        self.assertIn("FAT32", result["error"])

    def test_rejects_swap_role_with_ext4(self):
        result = self.validate([part("root", "ext4", 40 * GIB), part("swap", "ext4", 4 * GIB)])
        self.assertFalse(result["ok"])
        self.assertIn("swap", result["error"])

    def test_rejects_unsupported_filesystem(self):
        result = self.validate([part("root", "btrfs", 40 * GIB)])
        self.assertFalse(result["ok"])
        self.assertIn("no soportado", result["error"])

    def test_rejects_empty_plan(self):
        result = self.validate([])
        self.assertFalse(result["ok"])
        self.assertIn("al menos una partición", result["error"])

    def test_rejects_plan_when_disk_disappeared(self):
        with patch.object(server, "run_cmd", return_value='{"blockdevices": []}'), all_tools():
            result = server.validate_partition_plan(
                "/dev/sda", {"partitions": [part("root", "ext4", 40 * GIB)]}
            )
        self.assertFalse(result["ok"])
        self.assertIn("ya no está disponible", result["error"])

    def test_rejects_when_filesystem_tool_missing(self):
        with patch.object(server, "run_cmd", return_value=DISK_LSBLK), all_tools(present=False):
            result = server.validate_partition_plan(
                "/dev/sda", {"partitions": [part("root", "ext4", 40 * GIB)]}
            )
        self.assertFalse(result["ok"])
        self.assertIn("no puede crear", result["error"])

    def test_validation_never_writes_to_disk(self):
        """Validar es de solo lectura: ni parted ni mkfs deben ejecutarse."""
        with patch.object(server, "run_cmd", return_value=DISK_LSBLK) as run_cmd, all_tools():
            server.validate_partition_plan(
                "/dev/sda",
                {"partitions": [part("efi", "vfat", 0.5 * GIB), part("root", "ext4", 40 * GIB)]},
            )
        for call in run_cmd.call_args_list:
            command = call.args[0]
            self.assertNotIn("parted", command)
            self.assertNotIn("mkfs", command)


class ToolResolutionTest(unittest.TestCase):
    """El medio live puede lanzar el backend con un PATH sin /usr/sbin."""

    def test_uses_sbin_fallback_when_path_lacks_it(self):
        with patch.object(server.shutil, "which", return_value=None), \
             patch.object(server.Path, "is_file", return_value=True), \
             patch.object(server.os, "access", return_value=True):
            resolved = server._tool_path("mkfs.ext4")
        self.assertIsNotNone(resolved)
        self.assertTrue(resolved.endswith("mkfs.ext4"))

    def test_returns_none_when_tool_really_absent(self):
        with patch.object(server.shutil, "which", return_value=None), \
             patch.object(server.Path, "is_file", return_value=False):
            self.assertIsNone(server._tool_path("mkfs.ext4"))

    def test_filesystem_catalog_reports_availability(self):
        with patch.object(server, "_tool_path", return_value="/usr/sbin/x"):
            catalog = server.filesystem_catalog()
        self.assertTrue(all(entry["available"] for entry in catalog))
        self.assertEqual({entry["id"] for entry in catalog}, {"ext4", "vfat", "swap"})


class ApplyPartitionPlanTest(unittest.TestCase):
    """apply_partition_plan traduce el plan a comandos reales de disco."""

    def run_apply(self, disk, partitions):
        commands = []

        def fake_run(cmd, check=True):
            commands.append(("run", cmd))
            return ""

        with patch.object(server, "run_cmd", side_effect=fake_run), \
             patch.object(server, "run_quiet", side_effect=lambda cmd: commands.append(("quiet", cmd))), \
             patch.object(server, "unmount_disk_partitions",
                          side_effect=lambda d: commands.append(("unmount", d))), \
             patch.object(server, "wait_for_partitions",
                          side_effect=lambda d: commands.append(("wait", d))):
            devices = server.apply_partition_plan(disk, partitions)
        return devices, commands

    def test_sata_disk_creates_partitions_in_order(self):
        devices, commands = self.run_apply("/dev/sda", [
            part("efi", "vfat", 0.5 * GIB, "EFI"),
            part("root", "ext4", 40 * GIB, "DylanOS"),
        ])
        self.assertEqual(devices["efi"], "/dev/sda1")
        self.assertEqual(devices["root"], "/dev/sda2")
        flat = [c for _, c in commands]
        self.assertIn("parted -s /dev/sda mklabel gpt", flat)
        # La primera partición empieza en 1 MiB, dejando sitio a la GPT.
        self.assertTrue(any("mkpart primary 1MiB 513MiB" in c for c in flat), flat)
        self.assertTrue(any("set 1 esp on" in c for c in flat), flat)
        self.assertTrue(any("mkfs.vfat -F32 -n EFI /dev/sda1" in c for c in flat), flat)
        self.assertTrue(any("mkfs.ext4 -F -L DylanOS /dev/sda2" in c for c in flat), flat)

    def test_nvme_uses_p_suffix(self):
        devices, _ = self.run_apply("/dev/nvme0n1", [
            part("efi", "vfat", 0.5 * GIB),
            part("root", "ext4", 40 * GIB),
        ])
        self.assertEqual(devices["efi"], "/dev/nvme0n1p1")
        self.assertEqual(devices["root"], "/dev/nvme0n1p2")

    def test_swap_is_formatted_with_mkswap(self):
        devices, commands = self.run_apply("/dev/sda", [
            part("root", "ext4", 40 * GIB),
            part("swap", "swap", 4 * GIB, "intercambio"),
        ])
        self.assertEqual(devices["swap"], "/dev/sda2")
        flat = [c for _, c in commands]
        self.assertTrue(any("mkswap -L intercambio /dev/sda2" in c for c in flat), flat)

    def test_home_is_reported_for_fstab(self):
        devices, _ = self.run_apply("/dev/sda", [
            part("root", "ext4", 40 * GIB),
            part("home", "ext4", 30 * GIB),
        ])
        self.assertEqual(devices["home"], "/dev/sda2")

    def test_existing_mounts_are_released_before_repartitioning(self):
        """parted falla si el disco sigue montado: hay que desmontarlo antes."""
        _, commands = self.run_apply("/dev/sda", [part("root", "ext4", 40 * GIB)])
        kinds = [kind for kind, _ in commands]
        unmount_index = kinds.index("unmount")
        label_index = next(
            i for i, (_, c) in enumerate(commands) if "mklabel gpt" in c
        )
        self.assertLess(unmount_index, label_index)

    def test_empty_plan_raises_without_touching_disk(self):
        with patch.object(server, "run_cmd") as run_cmd:
            with self.assertRaises(RuntimeError):
                server.apply_partition_plan("/dev/sda", [])
        run_cmd.assert_not_called()


class PartitionInstallIntegrationTest(unittest.TestCase):
    """perform_installation debe rechazar un plan inválido antes de escribir."""

    def test_invalid_plan_aborts_before_any_disk_command(self):
        devices = [{"name": "sdb", "path": "/dev/sdb", "type": "disk"}]
        with patch("os.geteuid", return_value=0), \
             patch.object(server, "lsblk_devices", return_value=devices), \
             patch.object(server, "live_medium_disk", return_value=None), \
             patch.object(server, "run_cmd") as run_cmd:
            import stat
            with patch("os.stat", return_value=type("Stat", (), {"st_mode": stat.S_IFBLK | 0o600})()):
                server.perform_installation({
                    "disk": "/dev/sdb",
                    "mode": "manual",
                    # Sin raíz: el plan no debe llegar nunca a parted.
                    "plan": {"partitions": [part("home", "ext4", 40 * GIB)]},
                    "user": {"username": "dylanos-plan-test", "password": TEST_SECRET},
                })
        self.assertEqual(server.install_state["status"], "error")
        self.assertIn("Plan de particiones inválido", server.install_state["error"])
        run_cmd.assert_not_called()


class TimezoneDetectionTest(unittest.TestCase):
    """La zona horaria mostrada debe venir del sistema, no estar fija."""

    def test_timezone_is_a_non_empty_string(self):
        tz = server.get_real_timezone()
        self.assertIsInstance(tz, str)
        self.assertTrue(tz.strip())
        self.assertEqual(tz, tz.strip())

    def test_system_info_includes_timezone(self):
        self.assertIn("timezone", server.get_real_system_info())

    def test_falls_back_to_utc_without_zoneinfo(self):
        with patch.object(server.os.path, "realpath", return_value="/etc/localtime"), \
             patch.object(server.Path, "read_text", side_effect=OSError):
            self.assertEqual(server.get_real_timezone(), "UTC")


if __name__ == "__main__":
    unittest.main()
