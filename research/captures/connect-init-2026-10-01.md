# Arranque del RK Web Driver, 2026-10-01

Fuente: consola de Chrome en `https://drive.rkgaming.com/`, bundle `index-DB3pnj7S.js`. El observador se instaló antes de elegir el dispositivo. Esta nota transcribe lo visible en la captura de pantalla; el JSON del portapapeles no se pegó en el repositorio. No se pulsó Guardar y no aparece ningún comando `0x0C` ni `0x0D`.

## Dispositivo

`Gaming Keyboard`, VID `0x258A`, PID `0x022B`. El driver lo abrió. Las colecciones que imprimió coinciden con la interfaz USB 1 ya guardada:

- `000C/0001`, input ID 2, 2 bytes
- `FF02/0001`, input ID 3, 3 bytes
- `FF00/0001`, feature ID 5, 5 bytes
- `FF00/0001`, feature ID 6, 1031 bytes
- `FF02/0002`, input ID 9, 7 bytes, y feature ID 9, 519 bytes
- `0001/0002`, input ID 7, 7 bytes

Queda observado, no solo deducido del descriptor, que el Web Driver usa esa interfaz y el feature ID 9.

## Envío de arranque

`SetFeature`, 519 bytes. Los primeros valores visibles son `130, 1, 0, 1, 0, 10` y el resto de las líneas mostradas son ceros. `130` es el command ID `0x82` previsto para `getPassword`.

## Respuesta

`GetFeature`, anunciado como 18 bytes. En la línea se leen 17 valores: `9, 130, 1, 0, 1, 0, 10, 0, 6, 0, 0, 0, 114, 0, 0, 112, 1`. El primer `9` es el report ID. Falta un byte para llegar a 18; no se inventa.

Después el driver imprimió `Password data received from device.` y `meunid:0`. Luego `Received reportId: 9` y `GetReport` de 7 bytes: `10, 6, 0, 1, 0, 0, 0`. Esos 7 bytes caben en el input ID 9. El segundo byte es `6`, el valor que el código estático comprueba en los acuses TFT; aquí el driver lo trató como respuesta de arranque, no como avance de un bloque de imagen.

## Qué no demuestra

No demuestra el formato de una imagen, si el arranque cambió volumen, luz o keymap, ni el significado de `meunid` o de los bytes `114` y `112`.
