/*
 * Componente del DylanOS Login Manager.
 *
 * Es el componente del prototipo con una sola diferencia: `renderVals` ya no
 * inventa datos. Todo lo que se muestra viene de `DylanOSDatos` (el puente)
 * o de los props que entrega el host del greeter; lo que el sistema no puede
 * ofrecer antes del login se declara ausente y su widget no se pinta.
 *
 * La estructura de estado, los nombres de las clases y las acciones son las
 * del prototipo: tocar eso cambiaría el comportamiento visual.
 */
class Component extends DCLogic {
  constructor(props) {
    super(props);
    this.state = {
      openPanel: null,
      theme: 'dark',
      dndOn: false,
      wifiChipOn: true,
      btChipOn: true,
      pwValue: '',
      pwError: false,
      shakeCount: 0,
      unlocked: false,
      autenticando: false,
      mensaje: '',
      ahora: new Date(),
      sistema: (window.DylanOSDatos || {}).estadoDelSistema ? window.DylanOSDatos.estadoDelSistema() : {}
    };
  }

  componentDidMount() {
    var self = this;
    this.reloj = setInterval(function () {
      self.setState({ ahora: new Date() });
    }, 1000);
    this.aplicarApariencia();
    this.sincronizar();
    this.refresco = setInterval(function () { self.sincronizar(); }, 5000);
    this.refrescoApariencia = setInterval(function () {
      self.aplicarApariencia();
    }, 5000);
    if (window.DylanOSDatos && window.DylanOSDatos.alCambiarEstado) {
      window.DylanOSDatos.alCambiarEstado(function (estado) {
        self.setState({ sistema: estado || {} });
      });
    }
    /*
     * El prototipo dibuja el campo sin foco: su estado de reposo es el que
     * define la composición. En el login real el teclado debe estar listo,
     * así que el foco se pide solo cuando el host lo habilita (por defecto
     * sí): así la captura de fidelidad coincide y el uso real no obliga a
     * pulsar antes de escribir.
     */
    if (this.props && this.props.autoFocus === false) return;
    var entrada = document.querySelector('.pw-input');
    if (entrada) entrada.focus();
  }

  componentWillUnmount() {
    clearInterval(this.reloj);
    clearInterval(this.refresco);
  }

  /*
   * Aplica la configuración de apariencia al tema.
   *
   * Todo se hace con atributos y variables CSS sobre el propio marcado: el
   * dibujo del prototipo no se reescribe. Sin personalización no se toca
   * nada y el render es exactamente el original.
   */
  aplicarApariencia() {
    var D = window.DylanOSDatos || {};
    var config = D.configuracion ? D.configuracion() : {};
    var apariencia = config.apariencia || {};
    var composicion = config.composicion || {};
    var raiz = document.querySelector('.theme-root');
    if (!raiz) return;

    var primario = apariencia.color_primario;
    /*
     * El atributo de paleta solo se activa cuando el color elegido no es el
     * del prototipo: con el valor por defecto, el tema se dibuja con sus
     * estilos originales y el render es idéntico al prototipo.
     */
    var porDefecto = !primario || String(primario).toLowerCase() === '#dc143c'
      || String(primario).toLowerCase() === '#e11d2a';
    if (!porDefecto) {
      /*
       * Del acento elegido se derivan las tres familias que usa el prototipo:
       * el color base para títulos y cifras, una variante clara para iconos y
       * estados activos, y una más saturada para el anillo de batería y las
       * barras de progreso. Así TODO el texto de acento sigue al usuario.
       */
      raiz.style.setProperty('--dylanos-primario', primario);
      raiz.style.setProperty('--dylanos-primario-claro', this.aclarar(primario, 0.18));
      raiz.style.setProperty('--dylanos-primario-fuerte', this.saturar(primario, 0.12));
      raiz.style.setProperty('--dylanos-primario-control', primario);
      raiz.style.setProperty('--dylanos-primario-hover', this.aclarar(primario, 0.3));
      raiz.setAttribute('data-paleta', 'personalizada');
    } else {
      raiz.removeAttribute('data-paleta');
      // Se vuelve a los valores del prototipo, no a los de la capa visual.
      raiz.style.removeProperty('--dylanos-primario');
      raiz.style.removeProperty('--dylanos-primario-claro');
      raiz.style.removeProperty('--dylanos-primario-fuerte');
      raiz.style.removeProperty('--dylanos-primario-control');
      raiz.style.removeProperty('--dylanos-primario-hover');
    }

    if (apariencia.crimson_glass === false) {
      raiz.setAttribute('data-glass', 'off');
    } else if (apariencia.crimson_glass === true) {
      raiz.removeAttribute('data-glass');
      var desenfoque = Number(apariencia.desenfoque_px);
      if (!isNaN(desenfoque) && desenfoque !== 36) {
        var hojas = document.styleSheets;
        for (var i = 0; i < hojas.length; i++) {
          try {
            var reglas = hojas[i].cssRules;
            for (var j = 0; j < reglas.length; j++) {
              if (reglas[j].selectorText === '.glass-panel') {
                reglas[j].style.backdropFilter = 'blur(' + desenfoque + 'px) saturate(150%)';
                reglas[j].style.webkitBackdropFilter = 'blur(' + desenfoque + 'px) saturate(150%)';
              }
            }
          } catch (e) { /* hoja de otro origen: se omite */ }
        }
      }
    }

    /*
     * Distribución de los paneles.
     *
     * El prototipo coloca una columna a cada lado. `centrada` deja solo el
     * reloj y el acceso (login mínimo, o pantallas pequeñas); `izquierda`
     * mantiene los paneles de ese lado y libera el derecho.
     */
    var posicion = composicion.posicion_paneles || 'clasica';
    var columnaIzquierda = raiz.querySelector('.dylanos-columna-izquierda');
    var columnaDerecha = raiz.querySelector('.dylanos-columna-derecha');
    /*
     * Distribución de los paneles.
     *
     * El prototipo tiene tres bloques de columnas: los paneles de la
     * izquierda, la columna con el reloj y el acceso, y una tercera columna
     * con el calendario, los recordatorios y los atajos. `centrada` deja solo
     * el reloj y el acceso: se ocultan los paneles, nunca la columna que
     * contiene el login.
     *
     * Ocultar es la única operación segura sobre el estilo: el `display:flex`
     * viene en el atributo `style` del prototipo y restaurarlo (con
     * `style.display = ''` o `removeProperty`) BORRA esa propiedad; sin
     * `flex` el `gap` deja de aplicarse y todo se desplaza.
     */
    var posicion = composicion.posicion_paneles || 'clasica';
    var raizPaneles = raiz.querySelectorAll('.dylanos-panel');
    var centrada = posicion === 'centrada';
    Array.prototype.forEach.call(raizPaneles, function (elemento) {
      if (!elemento.dataset.dylanosEstilo) {
        elemento.dataset.dylanosEstilo = elemento.getAttribute('style') || '';
      }
      if (centrada) {
        elemento.style.setProperty('display', 'none', 'important');
      } else {
        elemento.setAttribute('style', elemento.dataset.dylanosEstilo);
      }
    });
    raiz.setAttribute('data-posicion', posicion);

    var escalaReloj = Number(composicion.tamano_reloj);
    if (!isNaN(escalaReloj) && escalaReloj !== 1) {
      raiz.style.setProperty('--dylanos-reloj', escalaReloj);
      raiz.setAttribute('data-escala-reloj', 'personalizada');
    }
    var escalaAcceso = Number(composicion.tamano_bloque_acceso);
    if (!isNaN(escalaAcceso) && escalaAcceso !== 1) {
      raiz.style.setProperty('--dylanos-acceso', escalaAcceso);
      raiz.setAttribute('data-escala-acceso', 'personalizada');
    }

    if (apariencia.modo === 'light') {
      raiz.style.filter = 'invert(1) hue-rotate(180deg)';
    }

    var fondo = apariencia.fondo_seleccionado;
    if (fondo) {
      var imagen = raiz.querySelector('img[alt=""]');
      if (imagen) {
        var url = /^(https?:|file:|\/)/.test(fondo) ? fondo : fondo;
        if (imagen.getAttribute('src') !== url) imagen.src = url;
      }
    }
  }

  /* Aumenta la saturación de un color hex (para el anillo y las barras). */
  saturar(hex, cantidad) {
    var valor = String(hex).replace('#', '');
    if (valor.length !== 6) return hex;
    var r = parseInt(valor.substr(0, 2), 16) / 255;
    var g = parseInt(valor.substr(2, 2), 16) / 255;
    var b = parseInt(valor.substr(4, 2), 16) / 255;
    var max = Math.max(r, g, b), min = Math.min(r, g, b);
    var l = (max + min) / 2;
    var s = max === min ? 0 : (l > 0.5 ? (max - min) / (2 - max - min) : (max - min) / (max + min));
    var h = 0;
    if (max !== min) {
      if (max === r) h = ((g - b) / (max - min) + (g < b ? 6 : 0)) / 6;
      else if (max === g) h = ((b - r) / (max - min) + 2) / 6;
      else h = ((r - g) / (max - min) + 4) / 6;
    }
    s = Math.min(1, s + cantidad);
    function aRgb(p, q, t) {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 2) return q;
      if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    }
    var r2, g2, b2;
    if (s === 0) { r2 = g2 = b2 = l; }
    else {
      var q = l < 0.5 ? l * (1 + s) : l + s - l * s;
      var p = 2 * l - q;
      r2 = aRgb(p, q, h + 1 / 3); g2 = aRgb(p, q, h); b2 = aRgb(p, q, h - 1 / 3);
    }
    function dos(n) { return ('0' + Math.round(n * 255).toString(16)).slice(-2); }
    return '#' + dos(r2) + dos(g2) + dos(b2);
  }

  /* Aclara un color hex para el estado activo (hover, bordes). */
  aclarar(hex, cantidad) {
    var valor = String(hex).replace('#', '');
    if (valor.length !== 6) return hex;
    var r = parseInt(valor.substr(0, 2), 16);
    var g = parseInt(valor.substr(2, 2), 16);
    var b = parseInt(valor.substr(4, 2), 16);
    function subir(c) { return Math.round(c + (255 - c) * cantidad); }
    function dos(n) { return ('0' + n.toString(16)).slice(-2); }
    return '#' + dos(subir(r)) + dos(subir(g)) + dos(subir(b));
  }

  sincronizar() {
    if (window.DylanOSDatos && window.DylanOSDatos.estadoDelSistema) {
      this.setState({ sistema: window.DylanOSDatos.estadoDelSistema() });
    }
  }

  /* --- paneles de la barra superior ---------------------------------- */

  toggle(name) {
    const cur = this.state.openPanel;
    this.setState({ openPanel: cur === name ? null : name });
  }

  closePanel() {
    this.setState({ openPanel: null });
  }

  /* --- acciones reales ------------------------------------------------ */

  aplicarTema(claro) {
    var raiz = document.querySelector('.theme-root');
    if (raiz) {
      raiz.style.filter = claro ? 'invert(1) hue-rotate(180deg)' : 'none';
    }
    this.setState({ theme: claro ? 'light' : 'dark' });
    this.guardar({ modo: claro ? 'light' : 'dark' });
  }

  toggleTheme() {
    this.aplicarTema(this.state.theme !== 'light');
  }

  toggleDnd() {
    var activo = !this.state.dndOn;
    this.setState({ dndOn: activo });
    this.guardar({ noMolestar: activo });
  }

  toggleWifiChip() {
    var activo = !this.state.wifiChipOn;
    this.setState({ wifiChipOn: activo });
    this.ordenar({ wifi: activo });
  }

  toggleBtChip() {
    var activo = !this.state.btChipOn;
    this.setState({ btChipOn: activo });
    this.ordenar({ bluetooth: activo });
  }

  guardar(cambios) {
    if (window.dylanos && window.dylanos.guardarPreferencia) {
      try { window.dylanos.guardarPreferencia(JSON.stringify(cambios)); } catch (e) { /* sin host */ }
    }
  }

  ordenar(cambios) {
    if (window.dylanos && window.dylanos.ordenar) {
      try { window.dylanos.ordenar(JSON.stringify(cambios)); } catch (e) { /* sin host */ }
    }
  }

  ejecutar(accion) {
    if (!accion) return;
    if (accion === 'tema') { this.toggleTheme(); return; }
    if (accion === 'no-molestar') { this.toggleDnd(); return; }
    if (accion === 'wifi') { this.toggleWifiChip(); return; }
    if (accion === 'bluetooth') { this.toggleBtChip(); return; }
    if (accion === 'crimson-glass') {
      var raiz = document.querySelector('.theme-root');
      if (raiz) {
        var apagado = raiz.getAttribute('data-glass') === 'off';
        raiz.setAttribute('data-glass', apagado ? 'on' : 'off');
        this.guardar({ crimsonGlass: apagado });
      }
      return;
    }
    // Atajos con acción en el sistema. Si el host no los soporta no pasa
    // nada: nunca se simula el resultado.
    if (window.dylanos && window.dylanos.accion) {
      try { window.dylanos.accion(accion); } catch (e) { /* sin host */ }
    }
  }

  /* --- acceso -------------------------------------------------------- */

  onPwInput(e) {
    this.setState({ pwValue: e.target.value, pwError: false, mensaje: '' });
  }

  onPwKey(e) {
    if (e.key === 'Enter') this.tryUnlock();
  }

  tryUnlock() {
    var self = this;
    if (this.state.autenticando) return;

    if (!window.dylanos || !window.dylanos.entrar) {
      // Sin host (vista en navegador): se valida contra el texto de muestra
      // del prototipo, que es lo único que existe en ese contexto.
      var esperado = (this.props && this.props.password) || '1234';
      if (this.state.pwValue === esperado) {
        this.setState({ unlocked: true, pwError: false, pwValue: '' });
      } else {
        this.setState({ pwError: true, pwValue: '', shakeCount: this.state.shakeCount + 1 });
      }
      return;
    }

    var usuario = (this.state.sistema && this.state.sistema.usuario) || '';
    this.setState({ autenticando: true, mensaje: '' });
    var resultado = window.dylanos.entrar(usuario, this.state.pwValue);
    // El host puede resolver de forma síncrona (pruebas) o asíncrona (login real).
    if (resultado && typeof resultado === 'object' && resultado.then) {
      resultado.then(function (correcto) {
        self.resolverAcceso(correcto);
      });
    } else if (resultado !== undefined) {
      this.resolverAcceso(resultado);
    }
  }

  resolverAcceso(correcto) {
    if (correcto) {
      this.setState({ unlocked: true, pwError: false, pwValue: '', autenticando: false });
    } else {
      this.setState({
        pwError: true,
        pwValue: '',
        autenticando: false,
        shakeCount: this.state.shakeCount + 1,
        mensaje: 'Contraseña incorrecta'
      });
    }
  }

  /* --- datos que alimentan la plantilla ------------------------------ */

  renderVals() {
    var D = window.DylanOSDatos || {};
    var estado = this.state.sistema || {};
    var ahora = this.state.ahora || new Date();
    var config = D.configuracion ? D.configuracion() : {};
    var apariencia = config.apariencia || {};
    var relojCfg = config.reloj || {};
    var accesoCfg = config.acceso || {};
    var open = this.state.openPanel;

    var bateria = estado.bateria;
    var porcentaje = bateria && typeof bateria.porcentaje === 'number' ? bateria.porcentaje : 0;
    var hayBateria = !!(bateria && bateria.presente);
    var almacenamiento = estado.almacenamiento || null;
    var clima = estado.clima || null;
    var evento = estado.evento || null;
    var reproduccion = estado.reproduccion || null;
    var recordatorios = Array.isArray(estado.recordatorios) ? estado.recordatorios : [];
    var sesiones = Array.isArray(estado.sesiones) ? estado.sesiones : [];
    var capacidades = estado.capacidades || {};
    var red = estado.red || {};

    var pronostico = (clima && Array.isArray(clima.pronostico)) ? clima.pronostico.map(function (dia) {
      return { dia: dia.dia, max: dia.max, min: dia.min };
    }) : [];

    var listaRecordatorios = recordatorios.slice(0, 4).map(function (r) {
      return {
        texto: r.texto,
        hecho: !!r.hecho,
        colorBorde: r.hecho ? 'var(--dylanos-primario-control)' : 'rgba(255,255,255,0.3)',
        colorFondo: r.hecho ? 'var(--dylanos-primario-control)' : 'transparent',
        colorTexto: r.hecho ? 'rgba(255,255,255,0.45)' : 'rgba(255,255,255,0.75)'
      };
    });

    var calendario = D.calendario ? D.calendario(ahora, !!relojCfg.mayusculasFecha) : null;

    var activos = D.atajosActivos ? D.atajosActivos(config) : ['tema', 'no-molestar', 'wifi', 'bluetooth'];
    var porDefecto = activos.length === 4 && activos[0] === 'tema' && activos[1] === 'no-molestar'
      && activos[2] === 'wifi' && activos[3] === 'bluetooth';
    var catalogo = D.ICONOS_ATAJO || {};

    var listaAtajos = activos.map(function (id) {
      var icono = iconoDe(id, catalogo);
      var activo = id === 'tema' ? this.state.theme !== 'light'
        : id === 'no-molestar' ? this.state.dndOn
        : id === 'wifi' ? (this.state.wifiChipOn && red.wifiDisponible !== false)
        : id === 'bluetooth' ? (this.state.btChipOn && red.bluetoothDisponible !== false)
        : false;
      return {
        nombre: D.nombreAtajo ? D.nombreAtajo(id) : id,
        clase: activo ? 'activo' : '',
        accion: function () { this.ejecutar(id); }.bind(this),
        trazo: icono.trazo,
        relleno: icono.relleno,
        colorTrazo: icono.colorTrazo,
        grosor: icono.grosor
      };
    }, this);

    // La variable se llama `formato_24_horas` en la plantilla; se acepta
    // también `formato24` por compatibilidad con perfiles antiguos.
    var hora24 = relojCfg.formato_24_horas !== undefined
      ? !!relojCfg.formato_24_horas : !!relojCfg.formato24;
    var h = ahora.getHours();
    /*
     * El reloj es la pieza central y se dibuja en dos nodos separados por los
     * dos puntos. El prototipo usa dos dígitos ("09"); mantenerlos evita que
     * el bloque cambie de ancho entre las 9 y las 10, que desplazaría la
     * columna entera. En 12 h se conserva ese mismo ancho.
     */
    var hora = hora24 ? D.dosDigitos(h) : D.dosDigitos(h % 12 === 0 ? 12 : h % 12);
    var ampm = h >= 12 ? 'PM' : 'AM';
    var minutos = D.dosDigitos(ahora.getMinutes());
    var segundos = D.dosDigitos(ahora.getSeconds());

    return {
      username: estado.usuario || 'Usuario',
      avatarUrl: estado.avatar || '',
      hasAvatar: !!estado.avatar,
      noAvatar: !estado.avatar,

      timeHour: hora,
      timeMinute: minutos,
      timeAmPm: hora24 ? '' : ampm,
      dateText: D.fechaLarga ? D.fechaLarga(ahora, !!relojCfg.mayusculasFecha) : '',
      clockTimeText: hora24 ? (D.dosDigitos(h) + ':' + minutos)
        : ((h % 12 === 0 ? 12 : h % 12) + ':' + minutos + ' ' + ampm),
      batteryPercent: porcentaje,
      batteryFillWidth: Math.max(1, Math.round((porcentaje / 100) * 19)),
      batteryDashOffset: Math.round(157 - (157 * porcentaje) / 100),
      hayBateria: hayBateria,
      bateriaDetalle: bateria && bateria.detalle ? bateria.detalle : '',
      storageFree: almacenamiento && almacenamiento.texto ? almacenamiento.texto : '',
      /* El marcado ya añade el sufijo; aquí se entrega el valor limpio. */
      almacenamientoLibre: almacenamiento && almacenamiento.texto ? almacenamiento.texto : '',
      puedeBateria: hayBateria,
      puedeAlmacenamiento: !!almacenamiento,
      puedeSistema: hayBateria || !!almacenamiento,

      puedeClima: !!clima && clima.temperatura !== undefined && clima.temperatura !== null,
      weatherTemp: clima ? clima.temperatura : '',
      weatherCondition: clima ? (clima.condicion || '') : '',
      pronostico: pronostico,

      puedeEvento: !!evento,
      eventTitle: evento ? evento.titulo : '',
      eventTime: evento ? evento.cuando : '',

      puedeReproduccion: !!reproduccion,
      trackTitle: reproduccion ? reproduccion.titulo : '',
      trackArtist: reproduccion ? reproduccion.artista : '',
      trackProgress: reproduccion && reproduccion.progreso !== undefined ? reproduccion.progreso : '0%',
      trackElapsed: reproduccion ? reproduccion.transcurrido : '',
      trackDuration: reproduccion ? reproduccion.duracion : '',

      puedeCalendario: !!calendario,
      calendarMonth: calendario ? calendario.mes : '',
      weekdays: D.DIAS_CORTOS || [],
      calendarDays: calendario ? calendario.dias : [],

      puedeRecordatorios: listaRecordatorios.length > 0,
      recordatorios: listaRecordatorios,

      puedeAtajos: listaAtajos.length > 0,
      atajos: listaAtajos,
      atajosPersonalizados: !porDefecto,
      atajosDelPrototipo: porDefecto,

      sesiones: sesiones,
      puedeSesiones: sesiones.length > 0,

      openPanel: open,
      anyPanelOpen: !!open,
      isWifiOpen: open === 'wifi',
      isBtOpen: open === 'bluetooth',
      isDisplayOpen: open === 'display',
      isBatteryOpen: open === 'battery',
      wifiOpenClass: open === 'wifi' ? 'is-open' : '',
      btOpenClass: open === 'bluetooth' ? 'is-open' : '',
      displayOpenClass: open === 'display' ? 'is-open' : '',
      batteryOpenClass: open === 'battery' ? 'is-open' : '',

      onWifiClick: () => this.toggle('wifi'),
      onBtClick: () => this.toggle('bluetooth'),
      onDisplayClick: () => this.toggle('display'),
      onBatteryClick: () => this.toggle('battery'),
      closeAll: () => this.closePanel(),

      themeFilter: this.state.theme === 'light' ? 'invert(1) hue-rotate(180deg)' : 'none',
      themeLabel: this.state.theme === 'light' ? 'Modo claro' : 'Modo oscuro',
      themeChipClass: this.state.theme === 'light' ? 'is-open' : '',
      dndChipClass: this.state.dndOn ? 'is-open' : '',
      wifiChipClass: this.state.wifiChipOn ? 'is-open' : '',
      btChipClass: this.state.btChipOn ? 'is-open' : '',
      onToggleTheme: () => this.toggleTheme(),
      onToggleDnd: () => this.toggleDnd(),
      onToggleWifiChip: () => this.toggleWifiChip(),
      onToggleBtChip: () => this.toggleBtChip(),

      wifiOnClass: red.wifi ? 'on' : 'off',
      btOnClass: red.bluetooth ? 'on' : 'off',
      redActual: red.ssid || 'Sin conexión',
      btDispositivo: red.bluetoothDispositivo || 'Sin dispositivos',
      pantalla: (estado.pantallas && estado.pantallas[0]) || '',

      textoAyuda: accesoCfg.textoAyuda || 'Introduce tu contraseña',

      pwValue: this.state.pwValue,
      pwError: this.state.pwError,
      pwErrorClass: this.state.pwError ? 'is-error' : '',
      shakeClass: this.state.shakeCount === 0 ? '' : (this.state.shakeCount % 2 ? 'pw-shake-a' : 'pw-shake-b'),
      lockText: this.state.unlocked ? 'Desbloqueado' : (this.state.autenticando ? 'Comprobando…' : 'Bloqueado'),
      onPwInput: (e) => this.onPwInput(e),
      onPwKey: (e) => this.onPwKey(e),
      onUnlock: () => this.tryUnlock()
    };
  }
}

/* Traduce los trazos del catálogo a lo que espera el SVG de la plantilla. */
function iconoDe(id, catalogo) {
  var simple = {
    'tema': { trazo: 'M21 12.6A9 9 0 1 1 11.4 3a7 7 0 0 0 9.6 9.6z', relleno: 'currentColor', colorTrazo: 'none', grosor: 0 },
    'no-molestar': { trazo: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18M8 12h8', relleno: 'none', colorTrazo: 'currentColor', grosor: 2 },
    'wifi': { trazo: 'M3 8.5c5-4 13-4 18 0M6.5 12.5c3.3-2.6 7.7-2.6 11 0M10 16.5c1.2-1 2.8-1 4 0', relleno: 'none', colorTrazo: 'currentColor', grosor: 2 },
    'bluetooth': { trazo: 'M7 7l10 10-5 5V2l5 5L7 17', relleno: 'none', colorTrazo: 'currentColor', grosor: 2 },
    'apagar': { trazo: 'M12 3v9M7.5 6.5a7 7 0 1 0 9 0', relleno: 'none', colorTrazo: 'currentColor', grosor: 2 },
    'reiniciar': { trazo: 'M20 12a8 8 0 1 1-2.3-5.6M20 4v5h-5', relleno: 'none', colorTrazo: 'currentColor', grosor: 2 },
    'suspender': { trazo: 'M20 14.5A8.5 8.5 0 0 1 9.5 4a8.5 8.5 0 1 0 10.5 10.5z', relleno: 'none', colorTrazo: 'currentColor', grosor: 2 },
    'teclado': { trazo: 'M3 6h18v12H3zM7 10h.01M11 10h.01M15 10h.01M7 14h10', relleno: 'none', colorTrazo: 'currentColor', grosor: 2 },
    'contraste': { trazo: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18M12 3a9 9 0 0 1 0 18z', relleno: 'currentColor', colorTrazo: 'currentColor', grosor: 2 },
    'sesion': { trazo: 'M3 4h18v12H3zM8 20h8M12 16v4', relleno: 'none', colorTrazo: 'currentColor', grosor: 2 },
    'texto': { trazo: 'M4 7V5h16v2M12 5v14', relleno: 'none', colorTrazo: 'currentColor', grosor: 2 },
    'crimson-glass': { trazo: 'M3 4h18v16H3zM3 12h18', relleno: 'none', colorTrazo: 'currentColor', grosor: 2 }
  };
  return simple[id] || simple['tema'];
}
