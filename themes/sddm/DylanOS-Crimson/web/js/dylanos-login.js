/* =========================================================================
   DylanOS — Login Manager (tema del greeter)

   Este archivo es el script.js del prototipo con los datos simulados fuera:
   el dibujo, las animaciones y los tiempos son los mismos, pero los textos y
   las listas vienen del sistema. `datos_sistema.py` decide qué existe; este
   archivo solo lo pinta y oculta lo que no tiene dato.

   Regla: aquí no se inventa ningún valor. Si un widget no trae datos, se
   oculta y no ocupa sitio, igual que si el prototipo no lo tuviera.
   ========================================================================= */

(function () {
  'use strict';

  /* ===== Estado interactivo (el mismo del prototipo) ===== */
  const state = {
    openPanel: null,     // null | 'wifi' | 'bluetooth' | 'display' | 'battery'
    theme: 'dark',       // 'dark' | 'light'
    dndOn: false,
    wifiChipOn: true,
    btChipOn: true,
    pwError: false,
    shakeCount: 0,
    unlocked: false,
    ocupado: false
  };

  /* ===== Datos: los pone el puente antes de cargar; si no hay puente,
     se queda el objeto vacío y todo lo que dependa de datos se oculta. ===== */
  let DATOS = {};

  const $ = (id) => document.getElementById(id);
  const crear = (etiqueta, clases, estilos) => {
    const nodo = document.createElement(etiqueta);
    if (clases) nodo.className = clases;
    if (estilos) nodo.setAttribute('style', estilos);
    return nodo;
  };
  const escapar = (texto) => String(texto == null ? '' : texto)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');

  /* ===== Escalado del lienzo =====
     El prototipo es un lienzo fijo de 1440×960. Se escala con transform para
     que no reflowe: a 1440×960 el factor es 1 y el dibujo es el original. */
  const LIENZO_ANCHO = 1440;
  const LIENZO_ALTO = 960;

  function ajustarLienzo() {
    const raiz = $('themeRoot');
    if (!raiz) return;
    const factor = Math.min(window.innerWidth / LIENZO_ANCHO,
                            window.innerHeight / LIENZO_ALTO);
    raiz.style.transform = 'scale(' + factor + ')';
  }

  /* ===== Acento y personalización ===== */
  function aplicarApariencia() {
    const raiz = $('themeRoot');
    if (!raiz) return;
    const acento = normalizarHex(DATOS.Acento);
    if (acento) {
      raiz.style.setProperty('--dylanos-primario', acento);
      raiz.style.setProperty('--dylanos-primario-rgb', tripleteRgb(acento));
      raiz.style.setProperty('--dylanos-primario-hover', aclarar(acento, 0.12));
    }
    const personalizado = Boolean(DATOS.Personalizado);
    if (personalizado) raiz.setAttribute('data-dylanos', 'personalizado');
    if (DATOS.CrimsonGlass === false) raiz.setAttribute('data-glass', 'off');

    const paneles = DATOS.PosicionPaneles || 'clasica';
    // El espejo y «solo centro» los resuelve la hoja de estilo: mover nodos
    // aquí duplicaría la inversión. Solo se marca la composición.
    if (paneles !== 'clasica') raiz.setAttribute('data-paneles', paneles);

    const reloj = Number(DATOS.TamanoReloj);
    if (reloj && Math.abs(reloj - 1) > 0.001) {
      raiz.setAttribute('data-escala-reloj', '');
      raiz.style.setProperty('--dylanos-reloj', String(reloj));
    }
    const acceso = Number(DATOS.TamanoAcceso);
    if (acceso && Math.abs(acceso - 1) > 0.001) {
      raiz.setAttribute('data-escala-acceso', '');
      raiz.style.setProperty('--dylanos-acceso', String(acceso));
    }
  }

  function normalizarHex(valor) {
    if (typeof valor !== 'string') return '';
    const limpio = valor.trim();
    if (/^#[0-9a-fA-F]{6}$/.test(limpio)) return limpio.toLowerCase();
    if (/^#[0-9a-fA-F]{3}$/.test(limpio)) {
      return ('#' + limpio[1] + limpio[1] + limpio[2] + limpio[2] + limpio[3] + limpio[3]).toLowerCase();
    }
    return '';
  }

  function tripleteRgb(hex) {
    return [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16)).join(',');
  }

  function aclarar(hex, cuanto) {
    const canales = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16));
    const claros = canales.map((c) => Math.min(255, Math.round(c + (255 - c) * cuanto)));
    return '#' + claros.map((c) => c.toString(16).padStart(2, '0')).join('');
  }

  /* ===== Wallpaper ===== */
  function aplicarFondo() {
    const fondo = DATOS.Fondo || 'assets/fondo-seleccionado.png';
    const imagen = $('dylanos-wallpaper');
    if (imagen && imagen.getAttribute('src') !== fondo) imagen.setAttribute('src', fondo);
    const relleno = $('dylanos-fondo');
    if (relleno) relleno.style.backgroundImage = 'url("' + fondo.replace(/"/g, '%22') + '")';
  }

  /* ===== Reloj y barra superior ===== */
  function pintarReloj(datos) {
    const r = datos || {};
    ponerTexto('clockTimeText', r.HoraCorta);
    ponerTexto('timeAmPm', r.AmPm);
    ponerTexto('timeHour', r.Hora);
    ponerTexto('timeMinute', r.Minuto);
    ponerTexto('dateText', r.Fecha);
    pintarCalendario(r);
  }

  function ponerTexto(id, valor) {
    const nodo = $(id);
    if (!nodo) return;
    if (valor === undefined || valor === null || valor === '') return;
    nodo.textContent = String(valor);
  }

  /* ===== Calendario ===== */
  function pintarCalendario(r) {
    const rejilla = $('calendarGrid');
    if (!rejilla) return;
    const diasSemana = Array.isArray(r.DiasSemana) && r.DiasSemana.length
      ? r.DiasSemana : ['D', 'L', 'M', 'M', 'J', 'V', 'S'];
    const dias = Array.isArray(r.Dias) ? r.Dias : [];
    if (!dias.length) return;
    ponerTexto('calendarMonth', r.Mes);

    const partes = diasSemana.map((wd) =>
      '<span style="font-size:10.5px; color:rgba(255,255,255,.4);">' + escapar(wd) + '</span>');
    const hoy = Number(r.Hoy);
    dias.forEach((numero, indice) => {
      const esHoy = indice === hoy;
      // Los días que no son del mes van atenuados; `hoy` siempre es del mes.
      const otroMes = !esHoy && (indice < primerHueco(dias, hoy) || indice > ultimoDelMes(dias, hoy));
      const color = esHoy ? '#ffffff'
        : (otroMes ? 'rgba(255,255,255,0.25)' : 'rgba(255,255,255,0.75)');
      const fondo = esHoy ? 'var(--crimson)' : 'transparent';
      partes.push('<span style="font-size:12px; padding:4px 0; border-radius:7px; color:' +
        color + '; background:' + fondo + ';">' + escapar(numero) + '</span>');
    });
    rejilla.innerHTML = partes.join('');
  }

  function primerHueco(dias, hoy) {
    // Índice del primer día del mes actual: el día 1 del mes es el primero
    // que no es mayor que el anterior (la rejilla empieza en 1).
    return dias.indexOf(1);
  }

  function ultimoDelMes(dias, hoy) {
    const inicio = primerHueco(dias, hoy);
    if (inicio < 0) return dias.length - 1;
    let ultimo = inicio;
    for (let i = inicio; i < dias.length; i++) {
      if (dias[i] >= dias[i - 1] && dias[i] !== 1) ultimo = i;
      if (i > inicio && dias[i] === 1) break;
    }
    return ultimo;
  }

  /* ===== Clima ===== */
  function pintarClima(datos) {
    const panel = $('dylanos-widget-clima');
    if (!panel) return;
    if (!datos || datos.temperatura === null || datos.temperatura === undefined) {
      panel.setAttribute('data-hidden', '');
      return;
    }
    panel.removeAttribute('data-hidden');
    ponerTexto('weatherTemp', datos.temperatura);
    ponerTexto('weatherCondition', datos.condicion || '');
    const fila = $('forecastRow');
    if (fila) {
      fila.innerHTML = (datos.pronostico || []).map((d) =>
        '<div style="display:flex; flex-direction:column; align-items:center; gap:4px;">' +
        '<span style="font-size:11.5px; color:rgba(255,255,255,.5);">' + escapar(d.etiqueta) + '</span>' +
        '<span style="font-size:12.5px; font-weight:600;">' + escapar(d.maxima) + '°</span>' +
        '<span style="font-size:11px; color:rgba(255,255,255,.4);">' + escapar(d.minima) + '°</span>' +
        '</div>').join('');
    }
  }

  /* ===== Próximo evento ===== */
  function pintarEvento(datos) {
    const panel = $('dylanos-widget-proximo-evento');
    if (!panel) return;
    if (!datos || !datos.titulo) {
      panel.setAttribute('data-hidden', '');
      return;
    }
    panel.removeAttribute('data-hidden');
    ponerTexto('eventTitle', datos.titulo);
    ponerTexto('eventTime', datos.cuando);
  }

  /* ===== En reproducción ===== */
  function pintarReproduccion(datos) {
    const panel = $('dylanos-widget-reproduccion');
    if (!panel) return;
    if (!datos || !datos.titulo) {
      panel.setAttribute('data-hidden', '');
      return;
    }
    panel.removeAttribute('data-hidden');
    ponerTexto('trackTitle', datos.titulo);
    ponerTexto('trackArtist', datos.artista || '');
    const tiempos = panel.querySelectorAll('div[style*="font-size:11px"]');
    if (tiempos.length >= 2) {
      tiempos[0].textContent = datos.posicion || '0:00';
      tiempos[1].textContent = datos.duracion || '0:00';
    }
  }

  /* ===== Sistema (batería y almacenamiento) ===== */
  function pintarSistema(datos) {
    const panel = $('dylanos-widget-sistema');
    if (!panel) return;
    const bateria = datos && datos.Bateria;
    const disco = datos && datos.Almacenamiento;
    if (!bateria && !disco) {
      panel.setAttribute('data-hidden', '');
      return;
    }
    panel.removeAttribute('data-hidden');
    // El anillo y la cifra: con batería real, o fuera.
    const anillo = $('batteryGaugeCircle');
    const bloqueBateria = anillo ? anillo.closest('.widget-row') : null;
    if (bateria) {
      const porcentaje = Math.max(0, Math.min(100, Number(bateria.porcentaje) || 0));
      ponerTexto('batteryPctTop', porcentaje + '%');
      ponerTexto('batteryPctPopover', porcentaje);
      ponerTexto('batteryPctGauge', porcentaje);
      ponerTexto('batteryPctLabel', porcentaje);
      const relleno = $('batteryFillRect');
      if (relleno) relleno.setAttribute('width', Math.max(1, Math.round((porcentaje / 100) * 19)));
      if (anillo) anillo.setAttribute('stroke-dashoffset', Math.round(157 - (157 * porcentaje) / 100));
      ponerTexto('batteryRemaining', bateria.restante || '');
      const restante = $('batteryRemaining');
      if (restante) restante.setAttribute('data-hidden', bateria.restante ? '' : '');
      const botonBateria = $('btnBattery');
      if (botonBateria) botonBateria.removeAttribute('data-hidden');
    } else {
      // Sin batería: no se pinta un 0 % falso, se quita la fila entera.
      if (bloqueBateria) bloqueBateria.setAttribute('data-hidden', '');
      const botonBateria = $('btnBattery');
      if (botonBateria) botonBateria.setAttribute('data-hidden', '');
      const panelBateria = $('panelBattery');
      if (panelBateria) panelBateria.setAttribute('data-hidden', '');
    }
    // La fila del almacenamiento no lleva clase: es el bloque de texto a la
    // derecha del anillo. Se localiza por su contenido (`storageFree`) para
    // ocultarla entera cuando no hay disco (y no dejar un título suelto).
    const nodoDisco = $('storageFree');
    if (nodoDisco) {
      const filaDisco = nodoDisco.parentElement;
      if (disco) {
        filaDisco.removeAttribute('data-hidden');
        nodoDisco.removeAttribute('data-hidden');
        ponerTexto('storageFree', disco + ' libres');
      } else {
        filaDisco.setAttribute('data-hidden', '');
      }
    }
  }

  /* ===== Recordatorios ===== */
  function pintarRecordatorios(lista) {
    const panel = $('dylanos-widget-recordatorios');
    const contenedor = $('remindersList');
    if (!panel || !contenedor) return;
    if (!Array.isArray(lista) || !lista.length) {
      panel.setAttribute('data-hidden', '');
      return;
    }
    panel.removeAttribute('data-hidden');
    contenedor.innerHTML = lista.map((r) => {
      const hecho = Boolean(r.hecho);
      const anillo = hecho ? 'var(--crimson)' : 'rgba(255,255,255,0.3)';
      const relleno = hecho ? 'var(--crimson)' : 'transparent';
      const color = hecho ? 'rgba(255,255,255,0.45)' : 'rgba(255,255,255,0.75)';
      const marca = hecho
        ? '<svg width="9" height="9" viewBox="0 0 24 24" fill="none"><path d="M5 12l5 5 9-9" stroke="#fff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"></path></svg>'
        : '';
      return '<div class="widget-row">' +
        '<div style="width:16px; height:16px; border-radius:50%; border:1.6px solid ' + anillo +
        '; background:' + relleno + '; flex-shrink:0; display:flex; align-items:center; justify-content:center;">' +
        marca + '</div>' +
        '<span style="font-size:13.5px; color:' + color + ';">' + escapar(r.texto) + '</span>' +
        '</div>';
    }).join('');
  }

  /* ===== Atajos ===== */
  const ATAJOS_POR_DEFECTO = ['tema', 'no-molestar', 'wifi', 'bluetooth'];
  // Límite del prototipo: la rejilla de atajos son dos filas de dos.
  const MAXIMO_ATAJOS = 4;
  const TODOS_LOS_ATAJOS = ATAJOS_POR_DEFECTO.concat([
    'apagar', 'reiniciar', 'suspender', 'sesion', 'teclado', 'contraste',
    'texto', 'crimson-glass']);

  function pintarAtajos(lista) {
    const panel = $('dylanos-widget-atajos');
    if (!panel) return;
    const predeterminados = (Array.isArray(DATOS.AtajosPorDefecto) && DATOS.AtajosPorDefecto.length)
      ? DATOS.AtajosPorDefecto : ATAJOS_POR_DEFECTO;
    const activos = (Array.isArray(lista) && lista.length ? lista : predeterminados)
      .filter((id) => TODOS_LOS_ATAJOS.includes(id))
      .slice(0, MAXIMO_ATAJOS);
    if (!activos.length) {
      panel.setAttribute('data-hidden', '');
      return;
    }
    panel.removeAttribute('data-hidden');

    // Se reutilizan los cuatro chips del prototipo; los que no estén elegidos
    // se ocultan, y los que falten se crean con el mismo estilo.
    const rejilla = panel.querySelector('div[style*="grid-template-columns"]');
    if (!rejilla) return;
    const existentes = Array.from(rejilla.querySelectorAll('[data-atajo]'));
    existentes.forEach((chip) => {
      const id = chip.getAttribute('data-atajo');
      if (activos.includes(id)) {
        chip.removeAttribute('data-hidden');
      } else {
        chip.setAttribute('data-hidden', '');
      }
    });
    activos.forEach((id) => {
      if (existentes.some((c) => c.getAttribute('data-atajo') === id)) return;
      const chip = crear('button', 'icon-btn shortcut-chip',
        'width:auto; height:auto; flex-direction:column; gap:8px; padding:14px 0; ' +
        'border-radius:14px; background:rgba(255,255,255,0.05);');
      chip.setAttribute('data-atajo', id);
      chip.setAttribute('aria-label', etiquetaAtajo(id));
      chip.innerHTML = iconoAtajo(id) +
        '<span style="font-size:11.5px;">' + escapar(etiquetaAtajo(id)) + '</span>';
      chip.addEventListener('click', () => accionAtajo(id, chip));
      rejilla.appendChild(chip);
    });
  }

  function etiquetaAtajo(id) {
    const nombres = {
      'tema': state.theme === 'light' ? 'Modo claro' : 'Modo oscuro',
      'no-molestar': 'No molestar', 'wifi': 'Wi-Fi', 'bluetooth': 'Bluetooth',
      'apagar': 'Apagar', 'reiniciar': 'Reiniciar', 'suspender': 'Suspender',
      'sesion': 'Sesión', 'teclado': 'Teclado', 'contraste': 'Contraste',
      'texto': 'Texto', 'crimson-glass': 'Crimson Glass'
    };
    return nombres[id] || id;
  }

  function iconoAtajo(id) {
    const trazos = {
      'apagar': '<path d="M12 3v8" stroke="currentColor" stroke-width="2" stroke-linecap="round"></path><path d="M6.5 6.5a8 8 0 1 0 11 0" stroke="currentColor" stroke-width="2" stroke-linecap="round"></path>',
      'reiniciar': '<path d="M20 12a8 8 0 1 1-2.3-5.6" stroke="currentColor" stroke-width="2" stroke-linecap="round"></path><path d="M20 4v5h-5" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></path>',
      'suspender': '<path d="M20 14.5A8.5 8.5 0 0 1 9.5 4a8.5 8.5 0 1 0 10.5 10.5z" stroke="currentColor" stroke-width="2" stroke-linejoin="round"></path>',
      'sesion': '<rect x="3" y="4" width="18" height="12" rx="2" stroke="currentColor" stroke-width="2"></rect><path d="M9 20h6M12 16v4" stroke="currentColor" stroke-width="2" stroke-linecap="round"></path>',
      'teclado': '<rect x="2" y="6" width="20" height="12" rx="2" stroke="currentColor" stroke-width="2"></rect><path d="M6 10h.01M10 10h.01M14 10h.01M18 10h.01M7 14h10" stroke="currentColor" stroke-width="2" stroke-linecap="round"></path>',
      'contraste': '<circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="2"></circle><path d="M12 3a9 9 0 0 1 0 18z" fill="currentColor"></path>',
      'texto': '<path d="M4 7V4h16v3M9 20h6M12 4v16" stroke="currentColor" stroke-width="2" stroke-linecap="round"></path>',
      'crimson-glass': '<path d="M4 6h16M4 12h16M4 18h16" stroke="currentColor" stroke-width="2" stroke-linecap="round"></path>'
    };
    return '<svg width="18" height="18" viewBox="0 0 24 24" fill="none">' +
      (trazos[id] || '') + '</svg>';
  }

  function accionAtajo(id, chip) {
    switch (id) {
      case 'tema':
        alternarTema();
        break;
      case 'no-molestar':
        state.dndOn = !state.dndOn;
        chip.classList.toggle('is-open', state.dndOn);
        guardarPreferencia({ no_molestar: state.dndOn });
        break;
      case 'wifi':
        state.wifiChipOn = !state.wifiChipOn;
        chip.classList.toggle('is-open', state.wifiChipOn);
        ordenarRed({ wifi: state.wifiChipOn });
        break;
      case 'bluetooth':
        state.btChipOn = !state.btChipOn;
        chip.classList.toggle('is-open', state.btChipOn);
        ordenarRed({ bluetooth: state.btChipOn });
        break;
      case 'apagar':
      case 'reiniciar':
      case 'suspender':
        ejecutarAccion(id);
        break;
      case 'contraste':
        chip.classList.toggle('is-open');
        document.documentElement.style.filter =
          chip.classList.contains('is-open') ? 'contrast(1.25)' : '';
        break;
      case 'texto':
        chip.classList.toggle('is-open');
        DATOS.TamanoTexto = chip.classList.contains('is-open') ? 1.12 : 1;
        $('themeRoot').style.setProperty('--dylanos-texto', DATOS.TamanoTexto);
        break;
      case 'crimson-glass': {
        const raiz = $('themeRoot');
        const apagado = raiz.getAttribute('data-glass') === 'off';
        if (apagado) raiz.removeAttribute('data-glass');
        else raiz.setAttribute('data-glass', 'off');
        chip.classList.toggle('is-open', !apagado);
        guardarPreferencia({ crimson_glass: apagado });
        break;
      }
      case 'sesion':
        // La sesión se elige en Configuration; aquí solo se muestra la activa.
        chip.classList.toggle('is-open');
        break;
      default:
        break;
    }
  }

  /* ===== Paneles emergentes (Wi-Fi / Bluetooth / Pantalla / Batería) ===== */
  const panelMap = {
    wifi: { btn: 'btnWifi', panel: 'panelWifi' },
    bluetooth: { btn: 'btnBt', panel: 'panelBt' },
    display: { btn: 'btnDisplay', panel: 'panelDisplay' },
    battery: { btn: 'btnBattery', panel: 'panelBattery' }
  };

  function renderPanels() {
    Object.entries(panelMap).forEach(([nombre, ids]) => {
      const abierto = state.openPanel === nombre;
      const boton = $(ids.btn);
      const panel = $(ids.panel);
      if (boton) boton.classList.toggle('is-open', abierto);
      if (panel) panel.toggleAttribute('data-hidden', !abierto);
    });
    const capa = $('overlayClick');
    if (capa) capa.toggleAttribute('data-hidden', !state.openPanel);
  }

  function togglePanel(nombre) {
    state.openPanel = state.openPanel === nombre ? null : nombre;
    renderPanels();
  }

  /* ===== Panel de red con datos reales ===== */
  function pintarRed(datos) {
    if (!datos) return;
    const panel = $('panelWifi');
    if (panel) {
      const lista = panel.querySelector('div[style*="flex-direction:column"]');
      if (lista) {
        const redes = Array.isArray(datos.Redes) ? datos.Redes : [];
        lista.innerHTML = redes.map((r, indice) => {
          const activa = datos.Ssid && r.ssid === datos.Ssid;
          return '<div style="display:flex; align-items:center; justify-content:space-between; ' +
            'padding:8px 6px; border-radius:10px;' +
            (activa ? ' background:rgba(var(--dylanos-primario-rgb),0.14);' : '') + '">' +
            '<span style="font-size:13.5px;' + (activa ? '' : ' color:rgba(255,255,255,.75);') + '">' +
            escapar(r.ssid) + '</span>' +
            (indice === 0 || activa
              ? '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" style="color:var(--crimson);"><path d="M20 7l-9 10-5-5" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"></path></svg>'
              : '') +
            '</div>';
        }).join('');
      }
      const alterna = panel.querySelector('.toggle');
      if (alterna && !datos.WifiDisponible) {
        panel.setAttribute('data-hidden', '');
        const boton = $('btnWifi');
        if (boton) boton.setAttribute('data-hidden', '');
      } else if (alterna) {
        alterna.classList.toggle('on', Boolean(datos.WifiActivo));
        alterna.classList.toggle('off', !datos.WifiActivo);
      }
    }
    const panelBt = $('panelBt');
    if (panelBt) {
      const alterna = panelBt.querySelector('.toggle');
      if (!datos.BluetoothDisponible) {
        panelBt.setAttribute('data-hidden', '');
        const boton = $('btnBt');
        if (boton) boton.setAttribute('data-hidden', '');
      } else if (alterna) {
        alterna.classList.toggle('on', Boolean(datos.BluetoothActivo));
        alterna.classList.toggle('off', !datos.BluetoothActivo);
      }
    }
  }

  /* ===== Tema claro/oscuro (inversión de filtro CSS, como el prototipo) ===== */
  function renderTheme() {
    const raiz = $('themeRoot');
    if (raiz) raiz.classList.toggle('light', state.theme === 'light');
    const chip = $('chipTheme');
    if (chip) chip.classList.toggle('is-open', state.theme === 'light');
    ponerTexto('chipThemeLabel', state.theme === 'light' ? 'Modo claro' : 'Modo oscuro');
  }

  function alternarTema() {
    state.theme = state.theme === 'dark' ? 'light' : 'dark';
    renderTheme();
    guardarPreferencia({ tema: state.theme });
  }

  /* ===== Retrato, usuario y estado de bloqueo ===== */
  function pintarCuenta(datos) {
    ponerTexto('username', datos.Usuario);
    // Retrato real: si no hay foto, la silueta del prototipo se queda.
    const retrato = $('dylanos-retrato');
    if (retrato) {
      if (datos.Retrato) {
        retrato.src = datos.Retrato;
        retrato.removeAttribute('data-hidden');
      } else {
        retrato.setAttribute('data-hidden', '');
        retrato.removeAttribute('src');
      }
    }
    const ayuda = document.querySelector('#groupLogin div[style*="font-size:13px"]');
    if (ayuda) {
      ayuda.textContent = datos.PermiteClave === false
        ? 'Introduce tu contraseña para desbloquear'
        : 'Usa tu huella o presiona cualquier tecla para desbloquear';
    }
  }

  /* ===== Contraseña: autenticación real (PAM a través de SDDM) ===== */
  function tryUnlock() {
    const entrada = $('pwInput');
    if (!entrada || state.ocupado) return;
    const clave = entrada.value;
    if (!clave) {
      marcarError();
      return;
    }
    state.ocupado = true;
    ponerTexto('lockText', 'Comprobando…');
    const entregado = entrar(datosUsuario(), clave);
    if (!entregado) {
      // Sin puente no hay autenticación posible: se dice, no se simula.
      state.ocupado = false;
      ponerTexto('lockText', 'Bloqueado');
      mostrarMensaje('La autenticación no está disponible');
      marcarError();
    }
  }

  function datosUsuario() {
    return DATOS.UsuarioCuenta || DATOS.Usuario || '';
  }

  function accesoCorrecto() {
    state.ocupado = false;
    state.unlocked = true;
    state.pwError = false;
    ponerTexto('lockText', 'Desbloqueado');
    const entrada = $('pwInput');
    if (entrada) {
      entrada.value = '';
      entrada.classList.remove('is-error');
    }
    ocultarError();
  }

  function accesoFallido(mensaje) {
    state.ocupado = false;
    ponerTexto('lockText', 'Bloqueado');
    mostrarMensaje(mensaje || 'Contraseña incorrecta');
    marcarError();
  }

  function marcarError() {
    const entrada = $('pwInput');
    if (!entrada) return;
    state.pwError = true;
    state.shakeCount++;
    entrada.value = '';
    entrada.classList.add('is-error');
    mostrarError();
    const envoltorio = $('pwShakeWrap');
    if (!envoltorio) return;
    envoltorio.classList.remove('pw-shake-a', 'pw-shake-b');
    void envoltorio.offsetWidth;  // reinicia la animación en intentos seguidos
    envoltorio.classList.add(state.shakeCount % 2 ? 'pw-shake-a' : 'pw-shake-b');
  }

  function mostrarError(texto) {
    const nodo = $('pwErrorText');
    if (!nodo) return;
    if (texto) nodo.textContent = texto;
    nodo.removeAttribute('data-hidden');
  }

  function ocultarError() {
    const nodo = $('pwErrorText');
    if (nodo) nodo.setAttribute('data-hidden', '');
  }

  function mostrarMensaje(texto) {
    if (!texto) return;
    mostrarError(texto);
  }

  /* ===== Puente con el sistema (lo inyecta el host) =====
     Sin host (por ejemplo, al abrir el HTML en un navegador) no hay
     autenticación ni acciones: el tema se dibuja y no finge nada. */
  function perfil() {
    return window.DYLANOS_LOGIN || {};
  }

  function entrar(usuario, clave) {
    const api = perfil();
    if (typeof api.entrar !== 'function') return false;
    try {
      return api.entrar(usuario, clave) === true;
    } catch (e) {
      return false;
    }
  }

  function ejecutarAccion(nombre) {
    const api = perfil();
    if (typeof api.accion === 'function') api.accion(nombre);
  }

  function guardarPreferencia(cambios) {
    const api = perfil();
    if (typeof api.guardarPreferencia === 'function') {
      api.guardarPreferencia(JSON.stringify(cambios));
    }
  }

  function ordenarRed(cambios) {
    const api = perfil();
    if (typeof api.ordenar === 'function') api.ordenar(JSON.stringify(cambios));
  }

  /* ===== Selección de widgets =====
     El usuario elige qué tarjetas quiere en cada columna. Las que no elige se
     ocultan con `data-oculto` (no se borran: el dibujo del prototipo queda
     intacto y volver a activarlas es inmediato). Un widget sin datos se
     oculta aparte, con `data-hidden`, para no confundir «no elegido» con
     «no hay dato». */
  const WIDGETS_POR_DEFECTO = {
    izquierda: ['clima', 'proximo-evento', 'reproduccion', 'sistema'],
    derecha: ['calendario', 'recordatorios', 'atajos']
  };

  const TODOS_LOS_WIDGETS = [
    'clima', 'proximo-evento', 'reproduccion', 'sistema', 'usuarios', 'sesiones',
    'teclado', 'calendario', 'recordatorios', 'atajos', 'energia', 'version',
    'mensaje', 'reloj-mundial', 'red', 'carga', 'memoria', 'hora-solar'
  ];

  /* ===== Widgets adicionales =====
     Son tarjetas nuevas con la MISMA estética que las del prototipo (mismo
     .glass-panel, mismo radio de 18 px, mismo padding y mismo título en
     carmesí). Solo se crean cuando el usuario las elige, así que el dibujo
     por defecto del login no cambia ni un píxel. */
  const ESTILO_TARJETA = 'border-radius:18px; padding:18px;';
  const ESTILO_TITULO = 'font-size:12px; font-weight:600; color:var(--crimson); ' +
    'text-transform:uppercase; letter-spacing:.06em; margin-bottom:12px;';
  const ESTILO_SECUNDARIO = 'font-size:12.5px; color:rgba(255,255,255,.55);';

  const WIDGETS_NUEVOS = {
    usuarios: { columna: 'izquierda', titulo: 'Usuarios', pintar: pintarWidgetUsuarios },
    sesiones: { columna: 'izquierda', titulo: 'Sesiones', pintar: pintarWidgetSesiones },
    teclado: { columna: 'izquierda', titulo: 'Teclado', pintar: pintarWidgetTeclado },
    red: { columna: 'izquierda', titulo: 'Red', pintar: pintarWidgetRed },
    carga: { columna: 'izquierda', titulo: 'Carga del sistema', pintar: pintarWidgetCarga },
    energia: { columna: 'derecha', titulo: 'Energía', pintar: pintarWidgetEnergia },
    version: { columna: 'derecha', titulo: 'Sistema', pintar: pintarWidgetVersion },
    'reloj-mundial': { columna: 'derecha', titulo: 'Reloj mundial', pintar: pintarWidgetRelojMundial },
    mensaje: { columna: 'derecha', titulo: 'Aviso', pintar: pintarWidgetMensaje },
    memoria: { columna: 'derecha', titulo: 'Memoria', pintar: pintarWidgetMemoria },
    'hora-solar': { columna: 'derecha', titulo: 'Salida y puesta de sol', pintar: pintarWidgetSol }
  };

  function crearTarjeta(id, titulo, contenido) {
    const panel = crear('div', 'glass-panel', ESTILO_TARJETA);
    panel.id = 'dylanos-widget-' + id;
    const cabecera = crear('div', '', ESTILO_TITULO);
    cabecera.textContent = titulo;
    panel.appendChild(cabecera);
    const cuerpo = crear('div', '', 'display:flex; flex-direction:column; gap:8px;');
    cuerpo.innerHTML = contenido;
    panel.appendChild(cuerpo);
    return panel;
  }

  function filaWidget(izquierda, derecha, destacado) {
    return '<div class="widget-row" style="justify-content:space-between; gap:10px;">' +
      '<span style="font-size:13.5px; white-space:nowrap; overflow:hidden; ' +
      'text-overflow:ellipsis;' + (destacado ? ' font-weight:600;' : '') + '">' +
      escapar(izquierda) + '</span>' +
      '<span style="' + ESTILO_SECUNDARIO + ' flex-shrink:0;">' + escapar(derecha) + '</span>' +
      '</div>';
  }

  function pintarWidgetUsuarios(datos) {
    const cuentas = (datos && datos.Cuentas) || [];
    if (!cuentas.length) return null;
    return cuentas.slice(0, 4).map((c) => filaWidget(
      c.nombre || c.usuario, c.usuario === datos.UsuarioCuenta ? 'En uso' : '',
      c.usuario === datos.UsuarioCuenta)).join('');
  }

  function pintarWidgetSesiones(datos) {
    const sesiones = (datos && datos.Sesiones) || [];
    if (!sesiones.length) return null;
    return sesiones.slice(0, 4).map((s) => filaWidget(
      s.nombre, s.tipo === 2 ? 'Wayland' : 'X11', false)).join('');
  }

  function pintarWidgetTeclado(datos) {
    const teclado = (datos && datos.Teclado) || '';
    if (!teclado) return null;
    return '<div style="font-size:13.5px;">' + escapar(teclado) + '</div>';
  }

  function pintarWidgetEnergia(datos) {
    const capacidades = (datos && datos.Capacidades) || {};
    const acciones = [
      ['apagar', 'Apagar'], ['reiniciar', 'Reiniciar'], ['suspender', 'Suspender']
    ].filter(([clave]) => capacidades[clave]);
    if (!acciones.length) return null;
    return '<div style="display:grid; grid-template-columns:repeat(3,1fr); gap:10px;">' +
      acciones.map(([clave, texto]) =>
        '<button class="icon-btn shortcut-chip" data-energia="' + clave + '" ' +
        'aria-label="' + texto + '" style="width:auto; height:auto; flex-direction:column; ' +
        'gap:8px; padding:14px 0; border-radius:14px; ' +
        'background:rgba(255,255,255,0.05);">' + iconoAtajo(clave) +
        '<span style="font-size:11.5px;">' + texto + '</span></button>').join('') +
      '</div>';
  }

  function pintarWidgetVersion(datos) {
    const version = (datos && datos.Version) || '';
    const equipo = (datos && datos.Equipo) || '';
    if (!version && !equipo) return null;
    const partes = [];
    if (version) partes.push(filaWidget(datos.Distribucion || 'DylanOS', version, true));
    if (equipo) partes.push(filaWidget('Equipo', equipo, false));
    return partes.join('');
  }

  function pintarWidgetRelojMundial(datos) {
    const zonas = (datos && datos.ZonasMundiales) || [];
    if (!zonas.length) return null;
    return zonas.slice(0, 4).map((z) => filaWidget(z.ciudad, z.hora, false)).join('');
  }

  function pintarWidgetMensaje(datos) {
    const mensaje = (datos && datos.Mensaje) || '';
    if (!mensaje) return null;
    return '<div style="font-size:13px; line-height:1.45;">' + escapar(mensaje) + '</div>';
  }

  function pintarWidgetRed(datos) {
    const redes = (datos && datos.Redes) || [];
    const ssid = (datos && datos.Ssid) || '';
    if (!redes.length && !ssid) return null;
    const estado = ssid ? 'Conectado' : 'Sin conexión';
    const filas = [filaWidget(ssid || 'Red', estado, Boolean(ssid))];
    // Solo las otras redes, con su señal real.
    redes.filter((r) => r.ssid !== ssid).slice(0, 2).forEach((r) => {
      filas.push(filaWidget(r.ssid, (r.senal || '') + ' %', false));
    });
    return filas.join('');
  }

  function pintarWidgetCarga(datos) {
    const carga = (datos && datos.Carga) || {};
    if (!carga.carga1) return null;
    return filaWidget('Carga (1 min)', carga.carga1, true) +
      filaWidget('Carga (5 min)', carga.carga5 || '', false) +
      filaWidget('Encendido', carga.encendido || '', false);
  }

  function pintarWidgetMemoria(datos) {
    const memoria = (datos && datos.Memoria) || {};
    if (!memoria.total) return null;
    const uso = Math.max(0, Math.min(100, Number(memoria.uso) || 0));
    return '<div style="display:flex; align-items:center; gap:16px;">' +
      '<div style="position:relative; width:58px; height:58px; flex-shrink:0;">' +
      '<svg width="58" height="58" viewBox="0 0 58 58">' +
      '<circle cx="29" cy="29" r="25" fill="none" stroke="rgba(255,255,255,0.1)" stroke-width="6"></circle>' +
      '<circle cx="29" cy="29" r="25" fill="none" stroke="var(--crimson)" stroke-width="6" ' +
      'stroke-linecap="round" stroke-dasharray="157" stroke-dashoffset="' +
      Math.round(157 - (157 * uso) / 100) + '" transform="rotate(-90 29 29)"></circle></svg>' +
      '<div style="position:absolute; inset:0; display:flex; align-items:center; ' +
      'justify-content:center; font-size:14px; font-weight:700;">' + uso + '%</div></div>' +
      '<div>' + filaWidget('En uso', memoria.total, false) +
      '<div style="height:6px;"></div>' + filaWidget('Disponible', memoria.disponible || '', false) +
      '</div></div>';
  }

  function pintarWidgetSol(datos) {
    const sol = (datos && datos.Sol) || {};
    if (!sol.salida || !sol.puesta) return null;
    return filaWidget('Salida', sol.salida, false) + filaWidget('Puesta', sol.puesta, false);
  }

  function sincronizarWidgetsNuevos(datos, elegidos) {
    Object.entries(WIDGETS_NUEVOS).forEach(([id, definicion]) => {
      const existente = $('dylanos-widget-' + id);
      if (!elegidos.includes(id)) {
        // No elegido: si estaba creado se oculta, y si no, no se crea.
        if (existente) existente.setAttribute('data-oculto', '');
        return;
      }
      const contenido = definicion.pintar(datos);
      if (contenido === null) {
        // Elegido pero sin dato real: se oculta, no se rellena con nada.
        if (existente) existente.setAttribute('data-hidden', '');
        return;
      }
      const columna = $('dylanos-columna-' + definicion.columna);
      if (!columna) return;
      let panel = existente;
      if (!panel) {
        panel = crearTarjeta(id, definicion.titulo, contenido);
        columna.appendChild(panel);
        engancharEnergia(panel);
      } else {
        const cuerpo = panel.lastElementChild;
        if (cuerpo) cuerpo.innerHTML = contenido;
        engancharEnergia(panel);
        panel.removeAttribute('data-oculto');
        panel.removeAttribute('data-hidden');
      }
    });
  }

  function engancharEnergia(panel) {
    panel.querySelectorAll('[data-energia]').forEach((boton) => {
      if (boton.dataset.enganchado) return;
      boton.dataset.enganchado = '1';
      boton.addEventListener('click', () => ejecutarAccion(boton.getAttribute('data-energia')));
    });
  }

  function pintarSeleccionWidgets(datos) {
    const seleccion = (datos && datos.Widgets) || WIDGETS_POR_DEFECTO;
    const elegidos = [].concat(seleccion.izquierda || [], seleccion.derecha || []);
    TODOS_LOS_WIDGETS.forEach((id) => {
      if (WIDGETS_NUEVOS[id]) return;  // esos los gestiona sincronizarWidgetsNuevos
      const panel = $('dylanos-widget-' + id);
      if (!panel) return;
      if (elegidos.includes(id)) panel.removeAttribute('data-oculto');
      else panel.setAttribute('data-oculto', '');
    });
    sincronizarWidgetsNuevos(datos, elegidos);
    ajustarDesbordamiento();
  }

  /* Si hay más tarjetas de las que caben, la columna hace scroll. Se decide
     después de pintar, midiendo de verdad: con la selección del prototipo no
     se activa y el dibujo queda intacto. */
  function ajustarDesbordamiento() {
    ['izquierda', 'derecha'].forEach((lado) => {
      const columna = $('dylanos-columna-' + lado);
      if (!columna) return;
      // La columna no tiene altura propia: se compara con la altura útil del
      // lienzo (960 px menos la barra superior).
      const disponible = LIENZO_ALTO - 96;
      columna.classList.toggle('dylanos-desborda', columna.scrollHeight > disponible + 1);
    });
  }

  /* ===== Aplicar el estado que llega del host ===== */
  function aplicarEstado(datos) {
    if (!datos || typeof datos !== 'object') return;
    DATOS = datos;
    aplicarFondo();
    aplicarApariencia();
    pintarSeleccionWidgets(datos);
    pintarReloj(datos.Reloj || datos);
    pintarCuenta(datos);
    pintarClima(datos.Clima);
    pintarEvento(datos.Evento);
    pintarReproduccion(datos.Reproduccion);
    pintarSistema(datos);
    pintarRecordatorios(datos.Recordatorios);
    pintarAtajos(datos.Atajos);
    pintarRed(datos);
    if (datos.NoMolestar !== undefined) {
      state.dndOn = Boolean(datos.NoMolestar);
      const chip = $('chipDnd');
      if (chip) chip.classList.toggle('is-open', state.dndOn);
    }
    if (datos.WifiActivo !== undefined) {
      state.wifiChipOn = Boolean(datos.WifiActivo);
      const chip = $('chipWifi');
      if (chip) chip.classList.toggle('is-open', state.wifiChipOn);
    }
    if (datos.BluetoothActivo !== undefined) {
      state.btChipOn = Boolean(datos.BluetoothActivo);
      const chip = $('chipBt');
      if (chip) chip.classList.toggle('is-open', state.btChipOn);
    }
    const topBateria = $('batteryPctTop');
    if (topBateria && (!datos.Bateria)) topBateria.setAttribute('data-hidden', '');
  }

  /* ===== Arranque ===== */
  function iniciar() {
    ajustarLienzo();
    window.addEventListener('resize', ajustarLienzo);

    Object.entries(panelMap).forEach(([nombre, ids]) => {
      const boton = $(ids.btn);
      if (boton) {
        boton.addEventListener('click', (evento) => {
          evento.stopPropagation();
          togglePanel(nombre);
        });
      }
    });
    const capa = $('overlayClick');
    if (capa) capa.addEventListener('click', () => {
      state.openPanel = null;
      renderPanels();
    });

    const chipTema = $('chipTheme');
    if (chipTema) chipTema.addEventListener('click', alternarTema);

    const chips = [['chipDnd', 'no-molestar'], ['chipWifi', 'wifi'], ['chipBt', 'bluetooth']];
    chips.forEach(([id, atajo]) => {
      const chip = $(id);
      if (chip) chip.addEventListener('click', () => accionAtajo(atajo, chip));
    });

    const botonDesbloqueo = $('btnUnlock');
    if (botonDesbloqueo) botonDesbloqueo.addEventListener('click', tryUnlock);
    const entrada = $('pwInput');
    if (entrada) {
      entrada.addEventListener('keydown', (evento) => {
        if (evento.key === 'Enter') tryUnlock();
      });
      entrada.addEventListener('input', () => {
        state.pwError = false;
        entrada.classList.remove('is-error');
        ocultarError();
      });
    }

    // El botón de energía del prototipo no existe: aquí se añade la fila de
    // energía solo si SDDM declara las capacidades.
    renderPanels();
    renderTheme();

    const puente = perfil();
    if (typeof puente.iniciar === 'function') {
      aplicarEstado(puente.iniciar());
    }
    if (typeof puente.alCambiarEstado === 'function') {
      puente.alCambiarEstado(function (datos) { aplicarEstado(datos); });
    }
    // El canal de Qt se conecta en paralelo al documento: si al arrancar
    // todavía no hay puente, se reintenta al llegar y se aplican los datos
    // reales en cuanto están. Sin esto el tema se quedaba con el dibujo del
    // prototipo y sin datos del equipo.
    window.__dylanosListo = function (objeto) {
      if (!objeto || typeof objeto.estado !== 'function') return;
      try {
        const datos = JSON.parse(objeto.estado());
        if (datos && typeof datos === 'object') aplicarEstado(datos);
      } catch (e) {
        /* sin datos: se queda lo que ya estaba pintado */
      }
    };
    if (!puente.iniciar && !puente.entrar) {
      // Reintento por si el canal llega tarde y __dylanosListo no se llamó.
      let intentos = 0;
      const espera = setInterval(function () {
        intentos++;
        const api = window.DYLANOS_LOGIN || {};
        if (typeof api.estado === 'function') {
          clearInterval(espera);
          window.__dylanosListo(api);
        } else if (typeof window.dylanos !== 'undefined' && window.dylanos) {
          clearInterval(espera);
          window.__dylanosListo(window.dylanos);
        } else if (intentos > 40) {
          clearInterval(espera);
        }
      }, 100);
    }
    window.dylanosAplicarEstado = aplicarEstado;
    window.dylanosAccesoCorrecto = accesoCorrecto;
    window.dylanosAccesoFallido = accesoFallido;
    document.documentElement.setAttribute('data-listo', '1');
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', iniciar);
  } else {
    iniciar();
  }
})();
