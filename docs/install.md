# Descargar y probar DylanOS

DylanOS está en fase Alpha y se construye para `amd64` (x86_64). La compatibilidad de hardware y los requisitos mínimos no están publicados como verificados. Consulta siempre la [página de Releases](https://github.com/dylanneymarmontalvo2014-lgtm/DylanOS/releases): si no hay una versión con ISO adjunta, todavía no existe una imagen pública lista para descargar.

> [!CAUTION]
> El flujo de instalación de Calamares no se ha validado de extremo a extremo. No instales una Alpha en un equipo con datos importantes ni sin una copia de seguridad. El particionado puede borrar o modificar discos.

## Obtener y verificar una imagen

1. Descarga la ISO y el archivo `.sha256` adjuntos a una misma Release.
2. En Linux, desde la carpeta que contiene ambos archivos, valida el checksum:

   ```bash
   sha256sum -c DylanOS-v0.1.0-amd64.iso.sha256
   ```

   Sustituye el nombre de archivo por el correspondiente a la versión descargada.
3. En Windows PowerShell, calcula el hash y compáralo con el valor publicado:

   ```powershell
   Get-FileHash .\DylanOS-v0.1.0-amd64.iso -Algorithm SHA256
   ```

El checksum detecta errores de descarga; por sí solo no autentica al publicador ni sustituye una firma criptográfica.

## Probar desde una máquina virtual

Siempre que sea posible, arranca primero la ISO en una máquina virtual sin discos con datos personales. Comprueba que el escritorio inicia y que el hardware virtual básico funciona. El smoke test automatizado solo llega hasta SDDM; no realiza la instalación.

## Crear un USB de prueba

Herramientas habituales como Rufus, balenaEtcher o Ventoy pueden escribir imágenes en una unidad USB. **La escritura puede borrar todo el contenido de la unidad**: confirma el dispositivo seleccionado y guarda antes cualquier archivo que necesites.

## Instalación

Solo procede si hay una versión publicada y aceptas los riesgos de una versión Alpha:

1. Verifica el checksum de la ISO y prepara un USB de prueba.
2. Arranca desde el USB y prueba la sesión live antes de instalar.
3. Abre el instalador Calamares y revisa cuidadosamente el destino y el esquema de particiones.
4. Continúa únicamente si tienes una copia de seguridad y entiendes los cambios que hará el instalador.
5. Después de instalar, prueba el arranque del sistema instalado y reporta cualquier fallo con pasos reproducibles.

La existencia de Calamares en la ISO o de esta guía no significa que una instalación completa haya sido certificada. Consulta [Estado del proyecto](status.md) y [Pruebas](testing.md).
