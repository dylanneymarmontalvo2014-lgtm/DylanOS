/*
 * Perfil de datos del prototipo.
 *
 * Solo se usa en las capturas de fidelidad: reproduce los datos simulados del
 * prototipo para comparar el render enlazado contra la referencia. En el
 * greeter nunca se carga.
 *
 * Se declara como `window.DYLANOS_LOGIN_PERFIL` para que el puente lo aplique
 * al construirse, antes de que el runtime evalúe el componente.
 */
(function () {
  'use strict';

  var momento = new Date(2025, 7, 4, 21, 0, 0);

  var estado = {
    usuario: 'DylanOS live',
    avatar: '',
    bateria: { presente: true, porcentaje: 78, detalle: 'Tiempo restante estimado: 4h 40min' },
    almacenamiento: { texto: '237 GB libres' },
    clima: {
      temperatura: 19,
      condicion: 'Nublado',
      pronostico: [
        { dia: 'Mié', max: 23, min: 14 },
        { dia: 'Jue', max: 24, min: 15 },
        { dia: 'Vie', max: 22, min: 13 },
        { dia: 'Sáb', max: 20, min: 12 },
        { dia: 'Dom', max: 21, min: 13 }
      ]
    },
    evento: { titulo: 'Reunión de proyecto', cuando: 'Mañana · 10:00 AM – 11:30 AM' },
    reproduccion: {
      titulo: 'Dream It Possible', artista: 'Delacey',
      progreso: '42%', transcurrido: '1:23', duracion: '3:24'
    },
    recordatorios: [
      { texto: 'Estudiar para examen', hecho: false },
      { texto: 'Editar video de DylanTube', hecho: true },
      { texto: 'Revisar proyecto DylanOS', hecho: false },
      { texto: 'Entrenar', hecho: false }
    ],
    red: { wifi: true, bluetooth: true, ssid: 'Casa-Dylan-5G', bluetoothDispositivo: 'Audífonos Crimson' },
    pantallas: ['TV Sala Crimson'],
    capacidades: { apagar: true, reiniciar: true, suspender: true, hibernar: false }
  };

  var configuracion = {
    apariencia: { crimsonGlass: true, modo: 'dark' },
    reloj: { formato24: false, mayusculasFecha: false },
    atajos: { maximo: 4, activos: ['tema', 'no-molestar', 'wifi', 'bluetooth'] },
    acceso: { textoAyuda: 'Usa tu huella o presiona cualquier tecla para desbloquear' }
  };

  /* Congela la fecha para que la captura sea determinista. Reproduce el
     constructor de Date, incluido el día 0 (último día del mes anterior), que
     usa el cálculo del calendario. */
  var FechaReal = Date;
  function FechaFija() {
    if (arguments.length === 0) return new FechaReal(momento.getTime());
    if (arguments.length === 1) return new FechaReal(arguments[0]);
    var partes = [];
    for (var i = 0; i < arguments.length; i++) partes.push(arguments[i]);
    return new (Function.prototype.bind.apply(FechaReal, [null].concat(partes)))();
  }
  FechaFija.prototype = FechaReal.prototype;
  FechaFija.now = function () { return momento.getTime(); };
  FechaFija.parse = FechaReal.parse;
  FechaFija.UTC = FechaReal.UTC;
  window.Date = FechaFija;

  window.DYLANOS_LOGIN_PERFIL = {
    estadoDelSistema: function () { return estado; },
    configuracion: function () { return configuracion; },
    alCambiarEstado: function () { },
    /*
     * El prototipo dibujaba un calendario fijo de cinco filas y una fecha que
     * no corresponde a un año real ("Martes, 04 de agosto"). Para comparar la
     * fidelidad gráfica hay que alimentarlo con esos mismos valores: así la
     * diferencia entre ambos renders mide solo el dibujo, nunca los datos.
     */
    fechaLarga: function () { return 'Martes, 04 de agosto'; },
    calendario: function () {
      var numeros = [27, 28, 29, 30, 31, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14,
                     15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30];
      var dias = numeros.map(function (n, i) {
        var esHoy = n === 4 && i >= 7 && i < 14;
        var otroMes = i < 7 && n > 20;
        return {
          n: n,
          color: esHoy ? '#ffffff' : (otroMes ? 'rgba(255,255,255,0.25)' : 'rgba(255,255,255,0.75)'),
          bg: esHoy ? '#e11d2a' : 'transparent'
        };
      });
      return { mes: 'Agosto 2025', dias: dias };
    },
    entrar: function (usuario, clave) { return clave === 'dylanos'; },
    accion: function () { },
    guardarPreferencia: function () { },
    ordenar: function () { }
  };

  window.dylanos = {
    entrar: function (usuario, clave) { return clave === 'dylanos'; },
    accion: function () { },
    guardarPreferencia: function () { },
    ordenar: function () { }
  };
})();
