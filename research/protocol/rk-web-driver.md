# RK-S98: investigación pasiva del RK Web Driver

Fecha de consulta: 2026-10-01. Alcance: HTTP GET de páginas y JavaScript públicos, lectura estática y aritmética offline. Posteriormente se contrastó el descriptor binario recogido por el coordinador, sin volver a acceder al hardware. No se ejecutó código del fabricante ni se abrió un dispositivo HID en esta investigación. No se concedieron permisos WebHID. Los resultados del driver describen **el software publicado**; el contraste físico se identifica en su propia sección.

## Fuentes y evidencia reproducible

| Fuente | Uso |
| --- | --- |
| [RK Web App](https://drive.rkgaming.com/) | HTML de entrada; referencia el bundle de esta revisión |
| [Bundle principal](https://drive.rkgaming.com/assets/index-DB3pnj7S.js) | Definiciones S98, selección HID, transporte, conversión y UI TFT |
| [Worker de comunicaciones](https://drive.rkgaming.com/assets/communication-DV8bKwpo.js) | Cola y temporización de envíos BeiYing |
| [Producto S98 oficial](https://rkgamingstore.com/products/s98-wireless-mechanical-keyboard) | TFT, dial, GIF y compatibilidad anunciada con macOS |
| [Descargas oficiales](https://rkgamingstore.com/pages/software) | Entrada oficial a software y documentación |
| [Guía oficial de GIF](https://rkgamingstore.com/blogs/community/how-to-upload-gifs-to-your-keyboard) | Flujo publicado de GIF y enlace al Web Driver |

Identidad de los bytes consultados:

- `index-DB3pnj7S.js`: 20 077 723 bytes; SHA-256 `90fe162151d9a89f8dc91261cac20329c9620a4c8f06eaf426a64fa5e48d3371`.
- `communication-DV8bKwpo.js`: 610 bytes; SHA-256 `9b77ecd0960c3e27a09f0c3dd122e8644c03140da18caf74291d5623c920adcc`.
- También se inspeccionó `home-BrBrXVfU.js` (67 105 bytes; SHA-256 `6dc1ecaa8f5e51cc5e1760f5accf6c81f29ceb086545a29eb1fec755a464600e`); no contenía la implementación TFT. Está en el bundle principal.

No se incorpora código propietario al repositorio. Los símbolos minificados siguientes son puntos de búsqueda de esta versión; pueden cambiar. Las posiciones indicadas son índices base cero del texto decodificado UTF-8 en Python, **no offsets de bytes ni números de línea**. Se prefieren símbolos y hash para localizar la evidencia.

## Identidades declaradas por el driver

Todas estas entradas USB usan VID `0x258A`, `usagePage=0xFF00`, `usage=0x0001`, familia `BeiYing` y factoría `LO.create`:

| Nombre declarado | PID decimal | PID hexadecimal |
| --- | ---: | --- |
| RK-S98 | 431 | `0x01AF` |
| RK-S98 TH | 547 | `0x0223` |
| RK-S98 RU | 560 | `0x0230` |
| RK-S98 JP | 559 | `0x022F` |
| RK-S98 ES | 555 | `0x022B` |
| RK-S98 FR | 577 | `0x0241` |
| RK-S98 KR | 576 | `0x0240` |
| RK-S98 TC | 575 | `0x023F` |
| RK-S98 DE | 548 | `0x0224` |
| RK-S98 POR | 542 | `0x021E` |

La entrada base es `oGt` alrededor de la posición 2609731; las variantes están inmediatamente después. Las entradas dongle S98 declaran PID `336` / `0x0150`, usage page `0xFF02`, usage `2` y factoría `RO.create`. Ese receptor es compartido por definiciones de otros modelos: su PID no identifica inequívocamente un S98.

La búsqueda literal `productId:372` no encontró ninguna definición en este bundle. Por tanto, el PID histórico `0x0174` del encargo no debe imponerse al diagnóstico ni sustituirse ciegamente por `0x01AF`. Hace falta enumerar el teclado concreto y registrar su transporte, producto, interfaces y descriptores.

La selección WebHID construye filtros por VID/PID. Solo la rama QMK añade usage page/usage al selector. Después de seleccionar, el código BeiYing comprueba las colecciones y busca coincidencia de usage page/usage antes de escoger el controlador. El selector inicial no demuestra qué interfaz resulta utilizable. Punto de búsqueda: `this.hid.requestDevice`, posición aproximada 19619226.

## Contraste offline con el descriptor de la unidad física

Se verificó directamente [interface-1.bin](../original-state/hid-report-descriptors/interface-1.bin), recogido por el coordinador: **304 bytes**, SHA-256 `776202fdfdf10d8104b2a668957a0583358758967114ba9766aa2ef5ab1be329`. La inspección hexadecimal y un recorrido independiente de items HID concuerdan:

| Colección top-level, numerada desde 1 | Usage page / usage | Reports declarados | Payload, sin ID |
| --- | --- | --- | --- |
| 5 | `FF00/0001` | Feature ID `5` | 5 bytes |
| 6 | `FF00/0001` | Feature ID `6` | 1031 bytes |
| 7 | `FF02/0002` | Input ID `9`; Feature ID `9` | Input: 7 bytes; Feature: **519 bytes** |

En el binario, la colección 7 comienza en offset `0xC0`; sus items Input y Feature están en `0xD4` y `0xE4`. El report size es 8 bits; report count vale 7 para Input y `0x0207` (519) para Feature.

Esto distingue dos niveles que no deben confundirse: **`FF00/0001` es la coincidencia que usa el driver para seleccionar el dispositivo/interfaz; el report ID 9 candidato a TFT está declarado dentro de la colección `FF02/0002` del mismo descriptor de interfaz 1.** La coincidencia exacta ID 9 + payload 519 con `LO` es evidencia fuerte del camino hacia TFT, pero no demuestra todavía que esa colección transporte una subida real ni que el driver abra correctamente esta unidad. No se ha realizado ninguna transmisión para comprobarlo.

Por tanto, la colección `FF00/0001` no debe etiquetarse por sí sola como "la colección TFT". Tampoco debe confundirse la colección `FF02/0002` de esta interfaz USB con el PID de receptor inalámbrico de la tabla anterior: una usage page no determina el transporte.

## Seleccionar el dispositivo en la web ya supera esta fase pasiva

Cadena observada en el código publicado:

1. La vista `KeyboardView_Beiying` encuentra la definición por VID/PID y crea su protocolo.
2. El montaje de la vista llama `init()` del protocolo.
3. Para S98 USB, `LO.init()` arranca la cola y llama `getPassword()`.
4. `LO.getPassword()` llama `setFeature()` antes de `getFeature()`.
5. `Vot.setFeature()` delega en `device.sendFeatureReport()`.

Localizadores: `KeyboardView_Beiying` aproximadamente 11137200; `class LO extends Vot` 2587662; `class Vot` 2555207; `tGt=class` 2585369; constante `Gh=9` 2550952.

El paquete de `getPassword` lleva command ID `0x82`, valor `1` y longitud declarada `10` dentro de un payload de 519 bytes. No se deduce de su nombre que sea seguro ni que solo lea. El hecho relevante es que **el driver transmite un feature report automáticamente durante la inicialización**, antes de cualquier clic en Guardar TFT. Las consultas de perfil, iluminación y keymap también usan un envío previo a la lectura.

Por ello no se debe pedir al usuario que seleccione/conecte el S98 en el Web Driver para "solo mirar". La inspección de archivos descargados mediante HTTP GET es suficiente para esta fase. Cualquier futura sesión con acceso al teclado necesita revisión propia del flujo de conexión, además del permiso para la eventual imagen.

## Ruta TFT trazada estáticamente

Esta información sirve como hipótesis de protocolo para contrastar con una captura futura; no constituye autorización ni una receta validada de envío.

### Conversión de imagen del host

La store `tftinfo_rk_s98` (`OKa`, aproximadamente 7594000) y su componente TFT (`s3a`, aproximadamente 7598130) hacen lo siguiente:

- El editor usa recorte de **320 × 172**. El canvas del que se extraen los píxeles también tiene esas dimensiones.
- Cada píxel RGBA se convierte a un entero **RGB565**: rojo de 5 bits, verde de 6 y azul de 5. El alfa no entra en ese entero.
- `LO.setTftPic` transforma cada entero de 16 bits en dos bytes, primero el alto y después el bajo: **big endian en el payload de píxeles**.
- El GIF se decodifica en el navegador y se recorre por frames; el transporte recibe buffers de píxeles. En esta ruta no se manda el archivo GIF comprimido original.
- La UI limita la lista a 100 frames y rechaza archivos de entrada mayores de 2 MiB. Esto es un límite del software, no una capacidad física de flash demostrada.
- La UI resta 25 al intervalo solicitado cuando este es al menos 25; la unidad y temporización efectiva del firmware deben contrastarse.

Un frame calculado por ese software contiene 55 040 píxeles, es decir, 110 080 bytes RGB565. Es evidencia más específica que la guía comercial: la guía oficial da tanto 240 × 240 como 240 × 135 en distintos apartados. Ninguna cifra comercial acredita el framebuffer físico. **320 × 172 está confirmado como raster de esta ruta S98 del driver; la resolución nativa de la unidad física sigue pendiente.**

### Transporte y framing

`LO` usa `sendFeatureReport` con report ID **9** (`Gh`) y un array de **519 bytes**. Esos 519 excluyen el ID que WebHID recibe por separado. No deben confundirse con el tamaño máximo que macOS publique ni con los paquetes USB de bajo nivel.

| Elemento | Evidencia del software |
| --- | --- |
| Datos TFT | Clase `aGt`, command ID `0x0C` |
| Control TFT | Clase `t0e`, command ID `0x0D` |
| Capacidad nominal de bloque de píxeles | `ote=512` bytes |
| Inicio | Control con modo `1` desplazado 6 bits, número de frames e intervalo |
| Fin | Control con modo `0`, número de frames e intervalo |
| Cancelación | Control con modo `2`, cero frames e intervalo cero |
| Acuse reconocido | `LO.onGetReport` comprueba byte de payload `[1] == 6`; `[2] == 1` avanza el bloque |
| Respuesta distinta de éxito | Reenvía el buffer actual; el fragmento no impone máximo explícito de reintentos |

Offsets del array que se pasa a WebHID (sin report ID):

| Offset | Datos `0x0C` | Control `0x0D` |
| ---: | --- | --- |
| 0 | Command ID | Command ID |
| 1 | Cero | Cero |
| 2 | Índice de frame | Cero inicial |
| 3 | Índice de bloque | Uno inicial |
| 4 | Suma de bytes de píxeles módulo 256 | Cero inicial |
| 5–6 | Longitud de píxeles del bloque, little endian | Longitud de datos declarada 5 |
| 7 | Comienzo de píxeles | Modo desplazado 6 bits |
| 8 | Píxeles | Cantidad de frames |
| 9 | Píxeles | Cero inicial |
| 10–11 | Píxeles | Intervalo, little endian |

No se vio CRC polinómico en esta construcción de datos; el campo en offset 4 es una suma truncada. No se afirma que esta tabla cubra toda variante de firmware o el modo inalámbrico.

La cola `communication-DV8bKwpo.js` comprueba cada 20 ms y tiene una ventana nominal de desbloqueo de 180 ms. También emite un mensaje interno `heartbeat` tras inactividad; `LO` lo descarta y no lo convierte en un envío HID. Estas constantes no son intervalos USB medidos ni garantizan el tiempo total de subida.

### Inconsistencias que impiden copiar el algoritmo

1. El último bloque de `aGt.setPayload()` usa `buffer.length % 512`. Pero `320 × 172 × 2 = 110080 = 215 × 512`: el campo de longitud sale a cero. La captura [upload-red-2026-10-01.md](../captures/upload-red-2026-10-01.md) lo confirma en el bloque 214 y, además, muestra que ese paquete sigue lleno de píxeles. No se debe "corregir" por intuición ni reproducir contra el teclado.
2. El progreso visual usa una constante de **213** bloques por frame, aunque el buffer calculado daría 215. El 100 % visual no prueba recepción íntegra.
3. Antes del control de inicio, `setTftPic` construye internamente un paquete con índice `-1`; los bytes truncados y contenido inicial requieren atención si se produce un acuse negativo. El código observado no lo transmite inmediatamente por esa línea, pero lo retiene como buffer actual.
4. La cancelación también transmite un comando: cerrar un diálogo de subida no debe considerarse una acción pasiva.

Estas observaciones son análisis estático del fabricante, no fallos reproducidos en el teclado del usuario.

## Persistencia, menús y cuestiones sin respuesta

No se ha encontrado en la ruta S98 analizada una selección explícita RAM/flash, un comando identificado de preview volátil ni un framebuffer temporal. La palabra Guardar, los límites de frames o que exista un comando de fin **no prueban por sí solos** el medio de almacenamiento.

Permanecen desconocidos:

- Flash frente a RAM, vida útil, borrado previo, atomicidad y recuperación de una subida interrumpida.
- Resolución, orientación y reproducción de colores reales de esta unidad.
- Apertura real por WebHID de la interfaz 1 y uso efectivo del report ID 9 para TFT; el descriptor confirma su presencia y tamaño, no su semántica.
- Correspondencia completa entre PID/firmware de la unidad y la revisión del driver; debe consultarse el inventario consolidado del coordinador.
- Semántica de los input reports ID 9 de 7 bytes: su existencia está confirmada en el descriptor, pero no se ha observado un acuse TFT real ni el significado completo de sus bytes.
- Si dial/menú emite eventos distinguibles y si el firmware toma automáticamente el control de pantalla.
- Si el menú vuelve por sí solo al GIF, si la imagen sobrevive reconexión y cómo recuperar el GIF original.
- Si otra revisión de S98 usa una ruta distinta de la publicada actualmente.

## Próximo experimento de menor riesgo

Primero, revisar el inventario READ-ONLY del proyecto en USB cableado y comparar VID/PID, colecciones, report IDs y tamaños con estas declaraciones del driver. El descriptor de interfaz 1 ya permitió la comparación ID 9 / 519 bytes anterior; no hace falta repetirla ni abrir Chrome para confirmarla.

Después de revisar ese inventario, se puede continuar con inspección estática del mismo bundle o una versión nueva. Para reproducir la descarga sin ejecutar JavaScript ni abrir Chrome:

```bash
curl --fail --silent --show-error https://drive.rkgaming.com/
```

La etiqueta `script` indica el asset actual. Se puede descargar ese asset mediante HTTP GET, calcular SHA-256 y buscar los símbolos anteriores en un visor de texto. Si el hash cambia, hay que volver a trazar la ruta. No se necesita instalar el software oficial, ejecutar bundles ni descargar firmware.

El inventario de esta unidad ya está contrastado con estas declaraciones. La captura de UNA subida oficial queda descrita en [phase-3-one-upload.md](../notes/phase-3-one-upload.md): incluye la escritura automática de la conexión y el guardado TFT. Sigue sin ejecutarse.
