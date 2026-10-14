// DYLANOS-MOCK: Simulated installation steps and packages.
// DYLANOS-INTEGRATION: Replace with real Calamares installation progress events.

export interface InstallStep {
  id: string;
  label: string;
  packages: string[];
}

export const mockInstallationSteps: InstallStep[] = [
  {
    id: "preparing",
    label: "Preparando",
    packages: ["Verificando requisitos del sistema...", "Inicializando entorno de instalación..."],
  },
  {
    id: "copying",
    label: "Copiando archivos",
    packages: ["Copiando sistema base...", "Copiando archivos de configuración...", "Copiando entorno gráfico..."],
  },
  {
    id: "installing",
    label: "Instalando paquetes",
    packages: [
      "linux-image-amd64 (1/1254)",
      "linux-headers-amd64 (2/1254)",
      "grub-efi-amd64 (15/1254)",
      "network-manager (48/1254)",
      "pulseaudio (92/1254)",
      "xorg (152/1254)",
      "plasma-desktop (287/1254)",
      "dolphin (420/1254)",
      "firefox-esr (655/1254)",
      "libreoffice (890/1254)",
      "vlc (1100/1254)",
      "dylan-tweaks (1240/1254)",
    ],
  },
  {
    id: "configuring",
    label: "Configurando sistema",
    packages: ["Configurando gestor de arranque...", "Configurando usuarios y permisos...", "Aplicando configuración regional..."],
  },
  {
    id: "finishing",
    label: "Finalizando",
    packages: ["Limpiando archivos temporales...", "Generando initramfs...", "Instalación completada."],
  },
];
