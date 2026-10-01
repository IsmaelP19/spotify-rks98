# Estado original del RK-S98

No se han enviado reports HID ni se ha cambiado la configuración durante esta fase.

## Identidad y conexión

- Fecha y versión de macOS: 2026-10-01, macOS 27.0.1 (26A434).
- VID/PID leídos en caliente, con el teclado conectado y la pantalla encendida: `0x258A` / `0x022B`.
- Producto y fabricante publicados por macOS: `Gaming Keyboard` / `SINO WEALTH`.
- Transporte: USB. La primera lectura IOUSB lo situó bajo un `USB 2.0 Hub`. La posición del selector físico no se ve en la foto.
- Número de serie: no se guardó ni se publicó.
- Dos servicios HID, interfaces USB 0 y 1, del mismo dispositivo USB. Detalle en [usb-descriptors.txt](usb-descriptors.txt) y en los binarios de `hid-report-descriptors/`.

La lectura de las 01:55 (hora local; `2026-09-30T23:55:05Z`) encontró un único dispositivo `0x258A`. El PID `0x022B` es la entrada RK-S98 ES del Web Driver publicado. El usuario mostró a esa misma hora la pantalla del teclado físico. Con eso, esta unidad queda identificada como su RK-S98. El nombre comercial no aparece en el texto USB. Una lectura posterior, a las 02:00 (`hid-inventory-2026-10-01-confirmed.json`), repitió el mismo VID, PID e interfaces y añade el enlace de cada report con su colección.

La utilidad solo leyó IORegistry. No abrió el HID ni pidió ni envió reports.

## Comportamiento original

Fotografía: [original-tft/home-2026-10-01.jpg](original-tft/home-2026-10-01.jpg), pantalla a las 01:51:50.

- Home nativo de reloj, no un GIF a pantalla completa.
- Fecha `2026-10-01`, batería `100%` con icono de carga, distintivo `MAC`.
- Fila inferior de iconos de estado; uno de ellos se lee `A1`.
- Teclas visibles con iluminación cálida. Brillo, velocidad y modo RGB concretos siguen sin anotar.
- Tras la carga del rojo, un toque del dial abrió «Modo BT» (BT1/BT2) y tapó la imagen. Al salir sin confirmar un modo, volvió el rojo. Al desconectar y reconectar el USB, volvió el reloj. Eligiendo en el dial la imagen dinámica o interfaz dinámica, el rojo vuelve a verse: la carga permanece guardada. Después, `rk-s98 upload-solid blue` sustituyó ese rojo y el usuario vio el azul.
- Teclas, volumen y comportamiento al escribir: pendiente de una prueba explícita.
- GIF personalizado ya guardado: no se ve en esta pantalla. Sigue sin saberse si hay uno almacenado.

## Recuperación

Orden previsto: detener nuestra aplicación, volver a Home con el dial, desconectar/reconectar si hace falta, usar el software oficial si se hubiera cambiado una imagen o configuración. El reset de fábrica publicado (Fn + espacio, tres segundos) queda sin ejecutar y sin verificar en esta unidad.

La prueba de una sola imagen oficial está descrita en [../notes/phase-3-one-upload.md](../notes/phase-3-one-upload.md). Sigue sin ejecutarse. Conectar el teclado en el RK Web Driver ya envía un feature report al inicializar.
