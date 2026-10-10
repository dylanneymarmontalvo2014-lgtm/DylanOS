#!/usr/bin/env python3
"""
Vista previa del instalador de DylanOS
Simula las pantallas del instalador con el estilo visual de DylanOS
"""

import tkinter as tk
from tkinter import ttk, font
import sys

class DylanOSInstallerPreview:
    def __init__(self, root):
        self.root = root
        self.root.title("DylanOS Instalador - Vista Previa")
        self.root.geometry("1024x768")
        self.root.configure(bg="#0A0A0A")

        # Configurar estilo
        self.setup_styles()

        # Estado actual
        self.current_screen = 0
        self.screens = [
            self.screen_particionado,
            self.screen_config_usuario,
            self.screen_distribucion_teclado,
            self.screen_instalacion_progreso,
            self.screen_instalacion_completada,
            self.screen_resumen_instalacion
        ]

        # Mostrar primera pantalla
        self.show_screen()

    def setup_styles(self):
        """Configura los estilos visuales de DylanOS"""
        self.style = ttk.Style()
        self.style.theme_use('clam')

        # Colores DylanOS
        self.bg_color = "#0A0A0A"
        self.accent_color = "#DC143C"
        self.text_primary = "#F5F5F7"
        self.text_secondary = "#98989F"
        self.progress_active = self.accent_color
        self.progress_inactive = "#2E2E33"

        # Configurar estilos personalizados
        self.style.configure('DylanOS.TFrame', background=self.bg_color)
        self.style.configure('DylanOS.TLabel',
                           background=self.bg_color,
                           foreground=self.text_primary,
                           font=('Inter', 18))
        self.style.configure('DylanOS.Header.TLabel',
                           background=self.bg_color,
                           foreground=self.text_primary,
                           font=('Inter', 34, 'bold'))
        self.style.configure('DylanOS.Body.TLabel',
                           background=self.bg_color,
                           foreground=self.text_secondary,
                           font=('Inter', 18))
        self.style.configure('DylanOS.Button.TButton',
                           background=self.accent_color,
                           foreground=self.text_primary,
                           font=('Inter', 14, 'bold'),
                           borderwidth=0,
                           focuscolor='none')
        self.style.map('DylanOS.Button.TButton',
                      background=[('active', '#B22222')])

        # Intentar cargar fuente Inter, usar fallback si no está disponible
        try:
            font.Font(family='Inter', size=12)
            self.font_family = 'Inter'
        except:
            self.font_family = 'Segoe UI' if sys.platform == 'win32' else 'Ubuntu' if sys.platform.startswith('linux') else 'Helvetica'

    def create_progress_indicators(self, parent, active_index):
        """Crea los indicadores de progreso estilo macOS"""
        frame = ttk.Frame(parent, style='DylanOS.TFrame')
        frame.pack(side='bottom', pady=20)

        for i in range(6):  # 6 pantallas estándar
            color = self.progress_active if i == active_index else self.progress_inactive
            label = tk.Label(frame,
                           bg=color if i == active_index else self.progress_inactive,
                           width=2, height=1)
            label.pack(side='left', padx=5)
            # Guardar referencia para poder actualizar después
            if i == active_index:
                self.active_indicator = label

    def clear_screen(self):
        """Limpia la pantalla actual"""
        for widget in self.root.winfo_children():
            widget.destroy()

    def show_screen(self):
        """Muestra la pantalla actual"""
        self.clear_screen()

        # Contenedor principal
        main_frame = ttk.Frame(self.root, style='DylanOS.TFrame')
        main_frame.pack(fill='both', expand=True, padx=40, pady=40)

        # Mostrar pantalla actual
        self.screens[self.current_screen](main_frame)

        # Indicadores de progreso
        self.create_progress_indicators(self.root, self.current_screen)

        # Botón de navegación (excepto en la última pantalla)
        if self.current_screen < len(self.screens) - 1:
            btn_frame = ttk.Frame(self.root, style='DylanOS.TFrame')
            btn_frame.pack(side='bottom', pady=20)

            next_btn = ttk.Button(btn_frame,
                                text="Siguiente",
                                style='DylanOS.Button.TButton',
                                command=self.next_screen)
            next_btn.pack(ipadx=20, ipady=10)
        else:
            # En la última pantalla, mostrar botón de reinicio
            btn_frame = ttk.Frame(self.root, style='DylanOS.TFrame')
            btn_frame.pack(side='bottom', pady=20)

            restart_btn = ttk.Button(btn_frame,
                                   text="Reiniciar Sistema",
                                   style='DylanOS.Button.TButton',
                                   command=self.root.quit)
            restart_btn.pack(ipadx=20, ipady=10)

    def next_screen(self):
        """Avanza a la siguiente pantalla"""
        if self.current_screen < len(self.screens) - 1:
            self.current_screen += 1
            self.show_screen()

    def screen_particionado(self, parent):
        """Pantalla: Particionado del disco"""
        # Contenido centrado
        content_frame = ttk.Frame(parent, style='DylanOS.TFrame')
        content_frame.place(relx=0.5, rely=0.5, anchor='center')

        # Título
        title_label = ttk.Label(content_frame,
                              text="Particionado del disco",
                              style='DylanOS.Header.TLabel')
        title_label.pack(pady=(0, 20))

        # Cuerpo
        body_text = ("DylanOS configurará automáticamente las particiones\n"
                    "para un rendimiento óptimo. Puede personalizar\n"
                    "el particionado si lo desea.")
        body_label = ttk.Label(content_frame,
                             text=body_text,
                             style='DylanOS.Body.TLabel',
                             justify='center')
        body_label.pack()

        # Vista previa simplificada de particiones
        preview_frame = ttk.Frame(content_frame, style='DylanOS.TFrame')
        preview_frame.pack(pady=30, fill='x', padx=50)

        # Barra de disco
        disk_frame = tk.Frame(preview_frame, bg='#1A1A1A', height=20)
        disk_frame.pack(fill='x', pady=10)
        disk_frame.pack_propagate(False)

        # Particiones
        partitions = [
            ('/boot/efi', '#DC143C', 100),  # EFI - crimson
            ('/', '#0A0A0A', 600),          # Raíz - negro
            ('swap', '#2E2E33', 100)        # Swap - gris oscuro
        ]

        for label, color, size in partitions:
            part_frame = tk.Frame(disk_frame, bg=color, width=size)
            part_frame.pack(side='left', fill='y')
            part_frame.pack_propagate(False)

            # Etiqueta pequeña para particiones importantes
            if label in ['/boot/efi', '/']:
                label_widget = tk.Label(part_frame,
                                      text=label,
                                      bg=color,
                                      fg='white' if color == '#DC143C' else '#F5F5F7',
                                      font=(self.font_family, 8))
                label_widget.place(relx=0.5, rely=0.5, anchor='center')

    def screen_config_usuario(self, parent):
        """Pantalla: Configuración de Usuario"""
        content_frame = ttk.Frame(parent, style='DylanOS.TFrame')
        content_frame.place(relx=0.5, rely=0.5, anchor='center')

        title_label = ttk.Label(content_frame,
                              text="Configuración de Usuario",
                              style='DylanOS.Header.TLabel')
        title_label.pack(pady=(0, 20))

        body_text = ("Configure su cuenta de usuario para DylanOS.\n"
                    "Esta cuenta tendrá privilegios de administrador.")
        body_label = ttk.Label(content_frame,
                             text=body_text,
                             style='DylanOS.Body.TLabel',
                             justify='center')
        body_label.pack(pady=(0, 30))

        # Campos de entrada simulados
        fields_frame = ttk.Frame(content_frame, style='DylanOS.TFrame')
        fields_frame.pack()

        # Nombre completo
        tk.Label(fields_frame,
                text="Nombre completo:",
                bg=self.bg_color,
                fg=self.text_secondary,
                font=(self.font_family, 12)).grid(row=0, column=0, sticky='w', pady=5)
        entry1 = tk.Entry(fields_frame,
                         width=25,
                         font=(self.font_family, 12),
                         bg='#1A1A1A',
                         fg=self.text_primary,
                         insertbackground=self.text_primary,
                         relief='flat')
        entry1.grid(row=0, column=1, padx=10, pady=5)
        entry1.insert(0, "Ing.Dylan")

        # Nombre de usuario
        tk.Label(fields_frame,
                text="Nombre de usuario:",
                bg=self.bg_color,
                fg=self.text_secondary,
                font=(self.font_family, 12)).grid(row=1, column=0, sticky='w', pady=5)
        entry2 = tk.Entry(fields_frame,
                         width=25,
                         font=(self.font_family, 12),
                         bg='#1A1A1A',
                         fg=self.text_primary,
                         insertbackground=self.text_primary,
                         relief='flat')
        entry2.grid(row=1, column=1, padx=10, pady=5)
        entry2.insert(0, "dylan")

        # Contraseña
        tk.Label(fields_frame,
                text="Contraseña:",
                bg=self.bg_color,
                fg=self.text_secondary,
                font=(self.font_family, 12)).grid(row=2, column=0, sticky='w', pady=5)
        entry3 = tk.Entry(fields_frame,
                         width=25,
                         font=(self.font_family, 12),
                         show='•',
                         bg='#1A1A1A',
                         fg=self.text_primary,
                         insertbackground=self.text_primary,
                         relief='flat')
        entry3.grid(row=2, column=1, padx=10, pady=5)
        entry3.insert(0, "••••••••")

        # Confirmar contraseña
        tk.Label(fields_frame,
                text="Confirmar contraseña:",
                bg=self.bg_color,
                fg=self.text_secondary,
                font=(self.font_family, 12)).grid(row=3, column=0, sticky='w', pady=5)
        entry4 = tk.Entry(fields_frame,
                         width=25,
                         font=(self.font_family, 12),
                         show='•',
                         bg='#1A1A1A',
                         fg=self.text_primary,
                         insertbackground=self.text_primary,
                         relief='flat')
        entry4.grid(row=3, column=1, padx=10, pady=5)
        entry4.insert(0, "••••••••")

    def screen_distribucion_teclado(self, parent):
        """Pantalla: Distribución de Teclado"""
        content_frame = ttk.Frame(parent, style='DylanOS.TFrame')
        content_frame.place(relx=0.5, rely=0.5, anchor='center')

        title_label = ttk.Label(content_frame,
                              text="Distribución de Teclado",
                              style='DylanOS.Header.TLabel')
        title_label.pack(pady=(0, 20))

        body_text = ("Seleccione la distribución de teclado que mejor se adapte\n"
                    "a su región y preferencias de escritura.")
        body_label = ttk.Label(content_frame,
                             text=body_text,
                             style='DylanOS.Body.TLabel',
                             justify='center')
        body_label.pack(pady=(0, 30))

        # Vista previa de teclado simplificada
        keyboard_frame = tk.Frame(content_frame, bg='#1A1A1A', height=120, width=400)
        keyboard_frame.pack(pady=20)
        keyboard_frame.pack_propagate(False)

        # Dibujar algunas teclas representativas
        key_labels = [
            ['Esc', 'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12'],
            ['`', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 'Backspace'],
            ['Tab', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\\'],
            ['Caps Lock', 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', "'", 'Enter'],
            ['Shift', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 'Shift'],
            ['Ctrl', 'Win', 'Alt', 'Espaciador', 'Alt', 'Win', 'Menu', 'Ctrl']
        ]

        key_size = 30
        key_pad = 2

        for row_idx, row in enumerate(key_labels):
            for col_idx, key in enumerate(row):
                x1 = col_idx * (key_size + key_pad) + 10
                y1 = row_idx * (key_size + key_pad) + 10
                x2 = x1 + key_size
                y2 = y1 + key_size

                # Tecla especial (más ancha)
                if key in ['Tab', 'Backspace', 'Enter', 'Shift', 'Ctrl', 'Win', 'Alt', 'Espaciador']:
                    width_multiplier = {
                        'Tab': 1.5,
                        'Backspace': 2,
                        'Enter': 2,
                        'Shift': 2.25,
                        'Ctrl': 1.25,
                        'Win': 1.25,
                        'Alt': 1.25,
                        'Espaciador': 6.25
                    }.get(key, 1)
                    x2 = x1 + (key_size * width_multiplier)

                # Dibujar tecla
                key_rect = tk.Frame(keyboard_frame,
                                  bg='#2A2A2A' if key not in ['Enter'] else self.accent_color,
                                  width=x2-x1,
                                  height=y2-y1)
                key_rect.place(x=x1, y=y1)
                key_rect.pack_propagate(False)

                if key != '':  # No dibujar etiqueta para teclas vacías
                    key_label = tk.Label(key_rect,
                                       text=key,
                                       bg=key_rect['bg'],
                                       fg=self.text_primary if key != 'Enter' else self.bg_color,
                                       font=(self.font_family, 8))
                    key_label.place(relx=0.5, rely=0.5, anchor='center')

    def screen_instalacion_progreso(self, parent):
        """Pantalla: Instalación en Progreso"""
        content_frame = ttk.Frame(parent, style='DylanOS.TFrame')
        content_frame.place(relx=0.5, rely=0.5, anchor='center')

        title_label = ttk.Label(content_frame,
                              text="Instalando DylanOS",
                              style='DylanOS.Header.TLabel')
        title_label.pack(pady=(0, 20))

        body_text = ("Los archivos se están copiando y configurando.\n"
                    "Este proceso puede tomar varios minutos.")
        body_label = ttk.Label(content_frame,
                             text=body_text,
                             style='DylanOS.Body.TLabel',
                             justify='center')
        body_label.pack(pady=(0, 40))

        # Barra de progreso simulada
        progress_frame = tk.Frame(content_frame, bg='#1A1A1A', height=20, width=400)
        progress_frame.pack(pady=10)
        progress_frame.pack_propagate(False)

        # Barra de fondo
        bg_bar = tk.Frame(progress_frame, bg='#2A2A2A', height=20, width=400)
        bg_bar.place(x=0, y=0)

        # Barra de progreso (animada simulación)
        self.progress_width = tk.Frame(progress_frame, bg=self.accent_color, height=20, width=0)
        self.progress_width.place(x=0, y=0)

        # Texto de progreso
        self.progress_label = ttk.Label(content_frame,
                                      text="0%",
                                      style='DylanOS.Body.TLabel')
        self.progress_label.pack(pady=10)

        # Iniciar animación de progreso
        self.animate_progress()

        # Detalles de instalación
        details_frame = ttk.Frame(content_frame, style='DylanOS.TFrame')
        details_frame.pack(pady=20, fill='x', padx=50)

        steps = [
            "✓ Preparando el sistema de archivos",
            "✓ Instalando el núcleo del sistema",
            "✓ Configurando el gestor de arranque",
            "✓ Instalando el entorno de escritorio",
            "✓ Instalando aplicaciones básicas",
            "✓ Configurando el usuario"
        ]

        for step in steps:
            step_label = ttk.Label(details_frame,
                                 text=step,
                                 style='DylanOS.Body.TLabel',
                                 font=(self.font_family, 12))
            step_label.pack(anchor='w', pady=2)

    def animate_progress(self):
        """Anima la barra de progreso"""
        current_width = self.progress_width.winfo_width()
        if current_width < 400:
            new_width = current_width + 5
            self.progress_width.configure(width=new_width)
            percent = int((new_width / 400) * 100)
            self.progress_label.configure(text=f"{percent}%")
            self.root.after(50, self.animate_progress)
        else:
            self.progress_label.configure(text="100%")

    def screen_instalacion_completada(self, parent):
        """Pantalla: Instalación Completada"""
        content_frame = ttk.Frame(parent, style='DylanOS.TFrame')
        content_frame.place(relx=0.5, rely=0.5, anchor='center')

        title_label = ttk.Label(content_frame,
                              text="Instalación Completada",
                              style='DylanOS.Header.TLabel')
        title_label.pack(pady=(0, 20))

        body_text = ("DylanOS se ha instalado correctamente en su equipo.\n"
                    "Por favor, reinicie el sistema para comenzar a usar\n"
                    "su nuevo sistema operativo.")
        body_label = ttk.Label(content_frame,
                             text=body_text,
                             style='DylanOS.Body.TLabel',
                             justify='center')
        body_label.pack(pady=(0, 40))

        # Icono de éxito (simplificado)
        success_frame = tk.Frame(content_frame, bg=self.accent_color, width=80, height=80)
        success_frame.pack(pady=20)
        success_frame.pack_propagate(False)

        # Marca de verificación
        check_label = tk.Label(success_frame,
                             text="✓",
                             bg=self.accent_color,
                             fg=self.bg_color,
                             font=(self.font_family, 48, 'bold'))
        check_label.place(relx=0.5, rely=0.5, anchor='center')

    def screen_resumen_instalacion(self, parent):
        """Pantalla: Resumen de Instalación"""
        content_frame = ttk.Frame(parent, style='DylanOS.TFrame')
        content_frame.place(relx=0.5, rely=0.5, anchor='center')

        title_label = ttk.Label(content_frame,
                              text="Resumen de la Instalación",
                              style='DylanOS.Header.TLabel')
        title_label.pack(pady=(0, 20))

        body_text = ("Revise la configuración que se aplicará a su sistema.\n"
                    "Todo está listo para comenzar.")
        body_label = ttk.Label(content_frame,
                             text=body_text,
                             style='DylanOS.Body.TLabel',
                             justify='center')
        body_label.pack(pady=(0, 30))

        # Información del resumen
        summary_frame = ttk.Frame(content_frame, style='DylanOS.TFrame')
        summary_frame.pack(fill='both', expand=True, padx=50, pady=20)

        # Información del sistema
        info_frame = ttk.LabelFrame(summary_frame,
                                  text=" Información del Sistema ",
                                  style='DylanOS.TFrame')
        info_frame.pack(fill='x', pady=10)

        info_text = tk.Text(info_frame,
                           height=8,
                           bg='#1A1A1A',
                           fg=self.text_primary,
                           font=(self.font_family, 11),
                           relief='flat',
                           wrap='word')
        info_text.pack(fill='both', expand=True, padx=10, pady=10)

        summary_info = """Sistema Operativo: DylanOS 1.0 Beta
Entorno de Escritorio: KDE Plasma 6
Núcleo: Linux 6.14.0-37-generic
Particiones:
  - /boot/efi (FAT32, 100 MB)
  - / (ext4, 25 GB)
  - swap (2 GB)
Usuario: Ing.Dylan (dylan)
Idioma: Español (España)
Distribución de Teclado: Español
"""
        info_text.insert('1.0', summary_info)
        info_text.configure(state='disabled')

        # Características instaladas
        features_frame = ttk.LabelFrame(summary_frame,
                                      text=" Características Instaladas ",
                                      style='DylanOS.TFrame')
        features_frame.pack(fill='both', expand=True, pady=10)

        features_text = tk.Text(features_frame,
                               height=6,
                               bg='#1A1A1A',
                               fg=self.text_primary,
                               font=(self.font_family, 11),
                               relief='flat',
                               wrap='word')
        features_text.pack(fill='both', expand=True, padx=10, pady=10)

        features_info = """✓ Escritorio KDE Plasma con tema DylanOS-Crimson
✓ Aplicaciones propias: Workspace, Calculadora, Dock, Notas
✓ Centro de Software de DylanOS
✓ Controladores gráficos y de red
✓ Herramientas de desarrollo básicas
✓ Soporte para impresión y escaneo
✓ Accesibilidad mejorada
"""
        features_text.insert('1.0', features_info)
        features_text.configure(state='disabled')

def main():
    root = tk.Tk()
    app = DylanOSInstallerPreview(root)

    # Centrar ventana
    root.update_idletasks()
    width = root.winfo_width()
    height = root.winfo_height()
    x = (root.winfo_screenwidth() // 2) - (width // 2)
    y = (root.winfo_screenheight() // 2) - (height // 2)
    root.geometry(f'{width}x{height}+{x}+{y}')

    root.mainloop()

if __name__ == "__main__":
    main()