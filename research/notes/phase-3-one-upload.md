# Fase 3: una sola carga oficial

Estado: **el frame azul enviado por `rk-s98` se ve en la TFT.** La respuesta al `0x82` fue idéntica a la de Chrome (`09 82 01 00 01 00 0a 00 06 00 00 00 00 72 00 00 70 01`) y los 215 bloques terminaron sin error. El usuario confirmó el azul, así que esta carga sustituyó al rojo en la imagen dinámica.

La primera carga fue la del Web Driver. La segunda, el azul, la envió `rk-s98 upload-solid blue`. No hay que lanzar otra.

## 1. Operación exacta

Una sola vez, en Chrome o Edge, con el teclado ya en USB (`0x258A:0x022B`):

1. Abrir `https://drive.rkgaming.com/` sin seleccionar el dispositivo.
2. Pegar en la consola el observador [webhid-observe.js](../captures/webhid-observe.js) antes de conceder WebHID.
3. Elegir el dispositivo cuyo PID sea `0x022B`. Si el diálogo muestra otro PID, parar.
4. Ir solo al apartado TFT.
5. Cargar únicamente [red.gif](../fixtures/tft/red.gif): un frame, 320×172, rojo `255,0,0`.
6. Pulsar una vez el guardado de esa pantalla. No subir las otras cuatro imágenes. No entrar en RGB, teclas ni otros ajustes.

Al seleccionar el dispositivo, el propio driver ya transmite. En el código publicado, `LO.init()` llama a `getPassword()`, y eso hace `sendFeatureReport` con report ID 9, command ID `0x82`, antes de cualquier Guardar. Las lecturas de perfil, luz y keymap también van precedidas de un envío. Guardar la imagen añade la ruta TFT: command IDs `0x0C` y `0x0D`, bloques de 519 bytes, documentados en [rk-web-driver.md](../protocol/rk-web-driver.md).

## 2. De dónde sale

Análisis estático del bundle público `index-DB3pnj7S.js`, SHA-256 `90fe162151d9a89f8dc91261cac20329c9620a4c8f06eaf426a64fa5e48d3371`, más el descriptor real de la interfaz 1 de esta unidad. No es un comando inventado aquí. Tampoco está copiado el JavaScript del fabricante.

## 3. Por qué este es el primer write admisible

La primera escritura del proyecto tiene que ser la carga que ya hace el driver oficial, no una secuencia reconstruida por nosotros. El descriptor confirma que el feature ID 9 de 519 bytes existe en `FF02/0002`. Eso no demuestra que el firmware acepte la carga ni que `0x82` sea inocuo. Usamos el programa del fabricante precisamente porque su efecto real aún no está medido.

## 4. Efecto esperado

La pantalla deja de mostrar el reloj y pasa a un rojo continuo, si esta ruta TFT es la de esta unidad y el guardado termina. El rojo es unívoco frente al home azul de la foto. 320×172 es el raster del editor S98 de ese bundle, no una resolución física ya medida: el recorte o el escalado reales se verán en la pantalla.

## 5. Riesgos

- Tratar el guardado como **persistente**. Hay almacenamiento anunciado y un botón de guardar; no hay un modo RAM identificado.
- No se puede leer antes el GIF que ya pudiera haber en la memoria. Si el reloj es un recurso sustituible, puede que no vuelva solo.
- Conectar no es «solo mirar»: `0x82` sale al iniciar, y el manual de RK describe calibración de volumen al abrir el driver. No está comprobado si la versión web también lo hace.
- El análisis estático del bundle tiene cabos sueltos (último bloque de longitud 0, progreso contado a 213 bloques frente a 215). Son del software oficial, no un motivo para corregirlo y enviarlo nosotros.
- Un cierre a medias durante la subida no es pasivo: la cancelación también transmite un comando.
- El permiso WebHID puede quedar recordado en el navegador.
- No hay copia de respaldo de RGB, keymap ni de la pantalla.

## 6. Volátil o persistente

Desconocido. Se asume persistente hasta observar si la imagen sigue tras cerrar el navegador y tras desconectar el USB. La batería puede mantener RAM; sobrevivir a desconectar el cable no prueba flash por sí solo.

## 7. Recuperación, en este orden

1. Cerrar la pestaña para que el navegador deje de enviar. Si una subida está a medias, anotarlo; no repetirla.
2. Con el dial, intentar volver al home nativo. Eso lo hace la persona, una vez, y se anota qué pasa.
3. Desconectar y reconectar el USB.
4. Si la imagen sigue y estorba, valorar en otra decisión explícita si el propio Web Driver ofrece borrarla. No recorrer el resto de ajustes.
5. El reset Fn + espacio durante tres segundos sigue sin ejecutar. Hace falta otro sí, y no está demostrado que devuelva el reloj.

Firmware, DFU y bootloader quedan fuera.

## 8. Qué recoger

- Foto de la pantalla al terminar, y otra tras cerrar el navegador.
- Si el dial abre el menú y si el rojo vuelve o vuelve el reloj.
- Si escribir, el volumen y el RGB visible siguen como antes. No cambiarlos; solo comprobar que responden.
- El JSON del observador, guardado en `research/captures/`, después de quitar cualquier dato que no sea de esta operación. El observador no registra pulsaciones; durante la prueba no hace falta escribir.
- El texto de cualquier error en pantalla. Una subida fallida no se reintenta en bucle.

## Imágenes locales

Generadas con [make_test_gifs.py](../fixtures/tft/make_test_gifs.py). Un frame, 320×172. Comprobadas al decodificarlas: el rojo es `255,0,0` en los 55040 píxeles; el tablero alterna negro y blanco en bloques de 4×4, 27520 píxeles de cada uno.

| Archivo | SHA-256 | Uso |
| --- | --- | --- |
| `red.gif` | `f846089042b518e50dd4ef6d3a2a8787a295c5f97d0899959c78760b62ef71a5` | La única candidata a subir |
| `black.gif` | `bf9bf81263af74234ba64d30d8dcf5a9796ebdd33ef20727ad2cc69a5f005064` | Reservada |
| `green.gif` | `6bafcd343fcb3c221dd0626992fc165b875f61beecb8db4b300a89d58be8f443` | Reservada |
| `blue.gif` | `bf5e63d2e8a0d0c633d7d88b5cdf03916cda3c4f6563ae6454c4efd1dca31d1f` | Reservada |
| `checkerboard.gif` | `dd7c8dfd57d9b8814e2b7a749622e204a94eb4ce2051d51f5a1cb46a1e9169a7` | Reservada |

Las cuatro restantes sirven para una comparación posterior, no para esta sesión.
