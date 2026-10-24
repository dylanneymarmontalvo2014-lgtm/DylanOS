# DylanOS Calculator

Calculadora nativa Qt 6/QML. Abre desde el menú de aplicaciones o desde una terminal:

```sh
dylanos-calculator
```

El ejecutable se compila desde `src/main.cpp`, `qml/` y `CMakeLists.txt`; su entrada de escritorio es `data/org.dylanos.calculator.desktop`. La imagen instala esta aplicación como calculadora oficial y omite KCalc. Esta breve guía documenta el punto de entrada y empaquetado; no atribuye funciones avanzadas no comprobadas en la interfaz actual.

Consulta la [guía general de DylanOS](../../docs/guia-de-uso.md) y la [arquitectura](../../docs/architecture.md).