// DYLANOS-MOCK: All data in this file is simulated for the Figma Make prototype.
// DYLANOS-INTEGRATION: Replace with real Calamares/Linux system data.

export const mockSystemInfo = {
  device: "Inspiron 3421",
  cpu: "Intel Core i5-3210M",
  ram: "8.00 GB",
  storage: "237 GB disponibles de 512 GB",
  gpu: "Intel HD Graphics 4000",
};

export const languages = [
  { code: "es_419", name: "Español (Latinoamérica)" },
  { code: "es_ES", name: "Español (España)" },
  { code: "en_US", name: "English (US)" },
  { code: "en_GB", name: "English (UK)" },
  { code: "pt_BR", name: "Português (Brasil)" },
  { code: "fr_FR", name: "Français" },
  { code: "de_DE", name: "Deutsch" },
  { code: "it_IT", name: "Italiano" },
  { code: "ru_RU", name: "Русский" },
  { code: "zh_CN", name: "中文（简体）" },
  { code: "ja_JP", name: "日本語" },
  { code: "ko_KR", name: "한국어" },
  { code: "ar_SA", name: "العربية" },
];

export const keyboardLayouts = [
  "Español (Latinoamérica)",
  "Español",
  "English (US)",
  "English (UK)",
  "Português (Brasil)",
  "Français",
  "Deutsch",
  "Italiano",
  "Русский",
  "中文（简体）",
  "日本語",
  "한국어",
  "العربية",
];

export const keyboardVariants: Record<string, string[]> = {
  "Español (Latinoamérica)": [
    "Español (Latinoamérica)",
    "Español (Latinoamérica) - sin teclas muertas",
    "Español (Latinoamérica) - con tecla Ñ",
    "Español (Latinoamérica) - Dvorak",
    "Español (Latinoamérica) - Dvorak sin teclas muertas",
    "Español (Latinoamérica) - Colemak",
    "Español (Latinoamérica) - Colemak-DH",
  ],
  "Español": ["Español", "Español - sin teclas muertas", "Español - Dvorak"],
  "English (US)": ["English (US)", "English (US) - Dvorak", "English (US) - Colemak", "English (US) - Workman"],
  "English (UK)": ["English (UK)", "English (UK) - Dvorak"],
  "Português (Brasil)": ["Português (Brasil)", "Português (Brasil) - sin teclas muertas"],
  "Français": ["Français", "Français (AZERTY)", "Français - Bépo"],
  "Deutsch": ["Deutsch", "Deutsch - sin teclas muertas"],
};

export const keyboardModels = [
  "Genérico de 105 teclas (Internacional)",
  "Genérico de 104 teclas (EE.UU.)",
  "Apple - MacBook Pro",
  "Dell - Latitude",
  "Lenovo - ThinkPad",
  "HP - EliteBook",
];

// DYLANOS-MOCK: Simulated disk data.
// DYLANOS-INTEGRATION: Replace with real data from Calamares partition module.
export interface Partition {
  device: string;
  type: string;
  mount: string;
  fs: string;
  size: string;
  sizeGB: number;
  used: string;
  color: string;
}

export interface Disk {
  device: string;
  size: string;
  sizeGB: number;
  model: string;
  partitions: Partition[];
}

export const mockDisks: Disk[] = [
  {
    device: "/dev/sda",
    size: "512 GB",
    sizeGB: 512,
    model: "KINGSTON SA400S37/512G",
    partitions: [
      { device: "/dev/sda1", type: "Primaria", mount: "/", fs: "ext4", size: "200 GB", sizeGB: 200, used: "32 GB", color: "#dc2626" },
      { device: "/dev/sda2", type: "Primaria", mount: "swap", fs: "swap", size: "8 GB", sizeGB: 8, used: "0 B", color: "#d97706" },
      { device: "/dev/sda3", type: "Primaria", mount: "/home", fs: "ext4", size: "100 GB", sizeGB: 100, used: "12 GB", color: "#3b82f6" },
      { device: "Espacio libre", type: "—", mount: "—", fs: "—", size: "204 GB", sizeGB: 204, used: "—", color: "#374151" },
    ],
  },
];

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
