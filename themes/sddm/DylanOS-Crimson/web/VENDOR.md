# Recursos de terceros

El login manager reutiliza el prototipo HTML del usuario tal cual. Estos son
los recursos que no son código propio:

| Recurso | Versión | Licencia |
|---|---|---|
| `vendor/react.production.min.js` | React 18.3.1 (UMD, producción) | MIT |
| `vendor/react-dom.production.min.js` | ReactDOM 18.3.1 (UMD, producción) | MIT |
| `vendor/dc-runtime.js` | runtime del prototipo | según el paquete original |
| `fonts/inter-latin.woff2` | Inter, subconjunto latino | SIL OFL 1.1 |

La cabecera `@license React` de los ficheros de React se conserva intacta: es
la condición de la licencia MIT para redistribuirlos. El resto del tema es
código propio de DylanOS, bajo GPL-3.0-or-later como el resto del repositorio.

## Por qué están vendorizados

El login no tiene red: todo se sirve desde el propio tema. Los ficheros son
los mismos bytes que publica cada proyecto, sin modificaciones.
