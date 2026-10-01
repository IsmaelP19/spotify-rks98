# Carga oficial del rojo, 2026-10-01

Fuente: `window.__rkHidLog` de Chrome, report ID 9, payloads de 519 bytes. El observador no registra input reports. Entre el arranque (`00:16:09Z`) y la imagen (`00:21:08Z`–`00:21:50Z`) no hay otros envíos.

La pantalla quedó de un rojo continuo: [tft-red-2026-10-01.jpg](tft-red-2026-10-01.jpg). El rectángulo ocupa toda la TFT y es más ancho que alto, coherente con el raster 320×172, sin medir aún los píxeles físicos. La iluminación de las teclas siguió encendida.

Al pulsar el dial, el firmware sustituyó el rojo por el menú nativo «Modo BT», con BT1 y BT2: [menu-modo-bt-2026-10-01.jpg](menu-modo-bt-2026-10-01.jpg). Al salir sin confirmar un modo, el usuario vio de nuevo el rojo, no el reloj. El firmware toma la pantalla durante el menú y después restaura la imagen cargada.

Al desconectar el USB y volver a conectarlo, la pantalla volvió al reloj. El rojo no sustituye ese home. Después, al elegir en el dial la opción que el usuario describe como imagen dinámica o interfaz dinámica, el rojo volvió a mostrarse. La carga oficial queda almacenada y el firmware la recupera en ese modo; el reloj y esa imagen son pantallas distintas. No se ha medido si cada guardado reescribe el mismo bloque.

Después, `rk-s98 upload-solid blue` envió un frame azul con la misma secuencia. El teclado contestó al `0x82` con los mismos 18 bytes de la sesión Chrome, y el programa cerró los 215 bloques sin error de IOKit. El usuario confirmó que la pantalla muestra el azul: el envío propio sustituyó al rojo.

## Lo que salió

218 `sendFeatureReport` y una sola `receiveFeatureReport`, la del arranque.

| Momento | Comando | Contenido |
| --- | --- | --- |
| 00:16:09.844Z | `0x82` | `82 01 00 01 00 0a` y 513 ceros |
| 00:16:09.862Z | respuesta | 18 bytes, con el ID `09` delante: `82 01 00 01 00 0a 00 06 00 00 00 00 72 00 00 70 01` |
| 00:21:08.355Z | `0x0D` inicio | `0d 00 00 01 00 05 00 40 01 00 00` |
| 00:21:08.531Z–00:21:50.250Z | `0x0C` × 215 | bloques 0 a 214, píxeles `f8 00` |
| 00:21:50.431Z | `0x0D` fin | `0d 00 00 01 00 05 00 00 01 00 00` |

`0x40` es el modo 1 desplazado 6 bits. El byte siguiente, `01`, es un frame. El cierre usa modo 0 y conserva ese frame. El intervalo de ambos controles es 0.

## Bloque de imagen

Cada `0x0C` cumple la tabla estática:

- offset 2: frame `00`
- offset 3: índice de bloque, un byte, de `00` a `d6`
- offset 4: suma de los bytes de píxel módulo 256
- offsets 5–6: longitud little endian
- desde offset 7: RGB565 big endian

Un bloque lleno declara longitud `00 02` (512) y repite `f8 00`, que es rojo `255,0,0` en RGB565. `256 × 0xF8 = 0xF800`, así que la suma módulo 256 es 0 y coincide con el offset 4.

215 × 512 = 110080 bytes = 320 × 172 × 2. El host envió un frame entero.

El bloque 214 declara longitud `00 00`, pero a partir del offset 7 sigue llevando `f8 00`. El fallo estático del operador módulo se confirma en el campo de longitud; el paquete no viaja vacío.

## Ritmo y acuses

Los envíos de la imagen van separados unos 180–200 ms. En este log no hay ningún `receiveFeatureReport` durante los bloques. Los acuses, si llegaron, lo hicieron por input reports, que este observador no guarda. El registro demuestra el envío, no la aceptación del firmware ni el aspecto de la pantalla.
