// DYLANOS-MOCK: Keyboard layout data for the prototype.
// DYLANOS-INTEGRATION: Load from Calamares keyboard module.

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
