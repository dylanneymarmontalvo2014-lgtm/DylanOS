/*
 * Puente de datos del DylanOS Login Manager.
 *
 * El prototipo es una plantilla HTML con un componente que recibe props. Este
 * archivo es lo único que cambia entre el prototipo y el login real: sustituye
 * los valores simulados por datos del sistema y conecta el desbloqueo con el
 * servicio de sesión.
 *
 * Reglas que se respetan aquí:
 *  - El HTML, los estilos y la composición NO se tocan. Solo se alimentan props.
 *  - Un dato que el greeter no puede conocer (clima sin proveedor, música sin
 *    reproductor, agenda sin calendario) se declara vacío y se oculta; nunca se
 *    rellena con cifras inventadas.
 *  - Sin red: todo se sirve desde el propio tema.
 *
 * Fuentes de datos:
 *  - Nativas (window.dylanos): el host del greeter, ya en marcha. Datos reales
 *    del sistema y del servicio de sesión de SDDM.
 *  - Navegador (sin host): se leen del JSON de configuración y del navegador,
 *    para poder abrir el tema y verlo tal cual quedará.
 */
(function () {
  'use strict';

  var ICONOS_ATAJO = {
    'tema': '<path d="M21 12.6A9 9 0 1 1 11.4 3a7 7 0 0 0 9.6 9.6z" fill="currentColor"></path>',
    'no-molestar': '<circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="2"></circle><path d="M8 12h8" stroke="currentColor" stroke-width="2" stroke-linecap="round"></path>',
    'wifi': '<path d="M3 8.5c5-4 13-4 18 0" stroke="currentColor" stroke-width="2" stroke-linecap="round"></path><path d="M6.5 12.5c3.3-2.6 7.7-2.6 11 0" stroke="currentColor" stroke-width="2" stroke-linecap="round"></path><path d="M10 16.5c1.2-1 2.8-1 4 0" stroke="currentColor" stroke-width="2" stroke-linecap="round"></path><circle cx="12" cy="19.5" r="1.3" fill="currentColor"></circle>',
    'bluetooth': '<path d="M7 7l10 10-5 5V2l5 5L7 17" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></path>',
    'apagar': '<path d="M12 3v9" stroke="currentColor" stroke-width="2" stroke-linecap="round"></path><path d="M7.5 6.5a7 7 0 1 0 9 0" stroke="currentColor" stroke-width="2" stroke-linecap="round"></path>',
    'reiniciar': '<path d="M20 12a8 8 0 1 1-2.3-5.6" stroke="currentColor" stroke-width="2" stroke-linecap="round"></path><path d="M20 4v5h-5" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></path>',
    'suspender': '<path d="M20 14.5A8.5 8.5 0 0 1 9.5 4a8.5 8.5 0 1 0 10.5 10.5z" stroke="currentColor" stroke-width="2" stroke-linejoin="round"></path>',
    'teclado': '<rect x="3" y="6" width="18" height="12" rx="2" stroke="currentColor" stroke-width="2"></rect><path d="M7 10h.01M11 10h.01M15 10h.01M7 14h10" stroke="currentColor" stroke-width="2" stroke-linecap="round"></path>',
    'contraste': '<circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="2"></circle><path d="M12 3a9 9 0 0 1 0 18z" fill="currentColor"></path>',
    'sesion': '<rect x="3" y="4" width="18" height="12" rx="2" stroke="currentColor" stroke-width="2"></rect><path d="M8 20h8" stroke="currentColor" stroke-width="2" stroke-linecap="round"></path><path d="M12 16v4" stroke="currentColor" stroke-width="2" stroke-linecap="round"></path>',
    'texto': '<path d="M4 7V5h16v2" stroke="currentColor" stroke-width="2" stroke-linecap="round"></path><path d="M12 5v14" stroke="currentColor" stroke-width="2" stroke-linecap="round"></path>',
    'crimson-glass': '<rect x="3" y="4" width="18" height="16" rx="3" stroke="currentColor" stroke-width="2"></rect><path d="M3 12h18" stroke="currentColor" stroke-width="2" stroke-linecap="round" opacity=".55"></path>'
  };

  var NOMBRES_ATAJO = {
    'tema': 'Modo oscuro',
    'no-molestar': 'No molestar',
    'wifi': 'Wi-Fi',
    'bluetooth': 'Bluetooth',
    'apagar': 'Apagar',
    'reiniciar': 'Reiniciar',
    'suspender': 'Suspender',
    'teclado': 'Teclado',
    'contraste': 'Contraste',
    'sesion': 'Sesión',
    'texto': 'Texto',
    'crimson-glass': 'Crimson Glass'
  };

  var DIAS = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
  /* Cabecera del calendario: iniciales, como en el prototipo. Cambiarlas por
     abreviaturas de tres letras ensancha la rejilla y rompe la composición. */
  var DIAS_CORTOS = ['D', 'L', 'M', 'M', 'J', 'V', 'S'];
  var MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
               'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
  var MESES_MAYUS = ['ENERO', 'FEBRERO', 'MARZO', 'ABRIL', 'MAYO', 'JUNIO', 'JULIO',
                     'AGOSTO', 'SEPTIEMBRE', 'OCTUBRE', 'NOVIEMBRE', 'DICIEMBRE'];

  function dosDigitos(n) {
    return (n < 10 ? '0' : '') + n;
  }

  function fechaLarga(ahora, mayusculas) {
    var texto = DIAS[ahora.getDay()] + ', ' + dosDigitos(ahora.getDate()) + ' de ' + MESES[ahora.getMonth()];
    return mayusculas ? texto.toUpperCase() : texto;
  }
  function hora12(ahora) {
    var h = ahora.getHours() % 12;
    if (h === 0) h = 12;
    return dosDigitos(h);
  }

  /* Configuración: la del sistema si el host la entrega, si no la del tema. */
  function configuracion() {
    var perfil = window.DYLANOS_LOGIN_PERFIL;
    if (perfil && typeof perfil.configuracion === 'function') {
      try {
        var propia = perfil.configuracion();
        if (propia) return propia;
      } catch (e) { /* se sigue con la siguiente fuente */ }
    }
    if (window.dylanos && window.dylanos.config) {
      try {
        var leida = window.dylanos.config();
        if (leida) return typeof leida === 'string' ? JSON.parse(leida) : leida;
      } catch (e) { /* se usa la plantilla local */ }
    }
    return window.DYLANOS_LOGIN_CONFIG || {};
  }

  /*
   * Estado real del sistema. El host entrega datos ya resueltos: aquí no se
   * inventan. Cada bloque ausente se marca como no disponible para que el
   * widget muestre su estado vacío.
   */
  function estadoDelSistema() {
    /*
     * El perfil se consulta en cada llamada, no al cargar: el host lo publica
     * cuando su canal con el servicio de sesión está listo, y eso puede pasar
     * después de que este archivo se evalúe.
     */
    var perfil = window.DYLANOS_LOGIN_PERFIL;
    if (perfil && typeof perfil.estadoDelSistema === 'function') {
      try {
        var resuelto = perfil.estadoDelSistema();
        if (resuelto) return resuelto;
      } catch (e) { /* se sigue con la lectura directa */ }
    }

    var nativo = window.dylanos || {};
    var ahora = new Date();
    var estado = {
      ahora: ahora,
      usuario: 'Usuario',
      avatar: '',
      bateria: null,
      almacenamiento: null,
      clima: null,
      evento: null,
      reproduccion: null,
      recordatorios: [],
      sesiones: [],
      capacidades: { apagar: false, reiniciar: false, suspender: false, hibernar: false },
      red: { wifi: false, bluetooth: false, disponible: false },
      teclado: { distribucion: '', disponible: false },
      version: '',
      mensajeAdmin: ''
    };

    ['usuario', 'avatar', 'bateria', 'almacenamiento', 'clima', 'evento',
     'reproduccion', 'recordatorios', 'sesiones', 'capacidades', 'red',
     'teclado', 'version', 'mensajeAdmin'].forEach(function (clave) {
      if (nativo[clave] !== undefined && nativo[clave] !== null) {
        estado[clave] = nativo[clave];
      }
    });
    return estado;
  }

  /* Calendario real del mes en curso, con el día de hoy resaltado. */
  function calendario(ahora, mayusculas) {
    var anyo = ahora.getFullYear();
    var mes = ahora.getMonth();
    var primero = new Date(anyo, mes, 1);
    var diasEnMes = new Date(anyo, mes + 1, 0).getDate();
    var desplazamiento = primero.getDay();
    var dias = [];
    var i;

    var mesPrevio = new Date(anyo, mes, 0).getDate();
    for (i = desplazamiento - 1; i >= 0; i--) {
      dias.push({ n: mesPrevio - i, color: 'rgba(255,255,255,0.25)', bg: 'transparent' });
    }
    for (i = 1; i <= diasEnMes; i++) {
      var esHoy = i === ahora.getDate();
      dias.push({
        n: i,
        color: esHoy ? '#ffffff' : 'rgba(255,255,255,0.75)',
        bg: esHoy ? 'var(--dylanos-primario)' : 'transparent'
      });
    }
    // Cola del mes siguiente: los días ya escritos más los que faltan para
    // completar la última semana.
    var siguiente = 1;
    while (dias.length % 7 !== 0) {
      dias.push({ n: siguiente, color: 'rgba(255,255,255,0.25)', bg: 'transparent' });
      siguiente += 1;
    }

    var nombreMes = (mayusculas ? MESES_MAYUS[mes] : MESES[mes]) + ' ' + anyo;
    return { mes: nombreMes, dias: dias };
  }

  function iconoAtajo(id) {
    return ICONOS_ATAJO[id] || ICONOS_ATAJO['tema'];
  }

  function nombreAtajo(id) {
    return NOMBRES_ATAJO[id] || id;
  }

  function atajosActivos(config) {
    var lista = (config.atajos && config.atajos.activos) || ['tema', 'no-molestar', 'wifi', 'bluetooth'];
    var maximo = (config.atajos && config.atajos.maximo) || 4;
    return lista.slice(0, maximo);
  }

  var api = {
    ICONOS_ATAJO: ICONOS_ATAJO,
    NOMBRES_ATAJO: NOMBRES_ATAJO,
    DIAS_CORTOS: DIAS_CORTOS,
    configuracion: configuracion,
    estadoDelSistema: estadoDelSistema,
    calendario: calendario,
    fechaLarga: fechaLarga,
    hora12: hora12,
    dosDigitos: dosDigitos,
    iconoAtajo: iconoAtajo,
    nombreAtajo: nombreAtajo,
    atajosActivos: atajosActivos
  };

  /*
   * Un perfil puede sustituir las fuentes de datos antes de que el runtime
   * evalúe el componente. Lo usan las capturas de fidelidad (para reproducir
   * los datos del prototipo) y el host del greeter (para inyectar el estado
   * real resuelto fuera del HTML).
   */
  if (window.DYLANOS_LOGIN_PERFIL && typeof window.DYLANOS_LOGIN_PERFIL === 'object') {
    Object.assign(api, window.DYLANOS_LOGIN_PERFIL);
  }

  window.DylanOSDatos = api;
})();
