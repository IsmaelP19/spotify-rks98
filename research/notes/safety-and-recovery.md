# Seguridad, conservación y recuperación del RK-S98

Fecha de investigación: 2026-10-01. Alcance: investigación documental y propuesta de observación pasiva. Este documento no registra ensayos físicos ni autoriza operaciones de escritura.

## Evidencia disponible

| Afirmación | Evidencia y límite |
| --- | --- |
| El S98 dispone de almacenamiento integrado. | La [ficha de RK](https://rkgamingstore.com/products/s98-wireless-mechanical-keyboard) lo anuncia. No identifica tecnología, capacidad, organización ni resistencia. |
| La pantalla admite GIF y controles nativos. | La ficha y el [manual enlazado por RK](https://cdn.shopify.com/s/files/1/0510/7866/0274/files/RK-S98_User_Manual_240411.pdf?v=1712824509) describen esas funciones. No verifican nuestra revisión física. |
| El software oficial puede alterar estado al iniciarse. | El manual indica calibración automática del volumen al iniciar el driver. No especifica si sucede también en la versión Web actual. |
| Hay un procedimiento de reset publicado. | El manual documenta mantener Fn + espacio durante tres segundos. **Referencia de recuperación, no instrucción para ejecutarlo en esta fase.** No enumera todo lo que borra ni garantiza restaurar un GIF anterior. |
| Hay selección de Home y navegación con dial. | El manual describe Home con reloj/GIF, clic para entrar en ajustes y pulsación breve para confirmar. No documenta suficientemente una secuencia universal de regreso desde cualquier pantalla. |

El manual es un pliego PDF de una página, identificado internamente como RK-S98 (762), actualizado en enero de 2024. Se revisaron visualmente los paneles ingleses de conexión, dial, hora y operación de pantalla. Debe cotejarse con el manual y distribución física de esta unidad antes de usar un procedimiento de recuperación.

La [guía de GIF de RK](https://rkgamingstore.com/blogs/community/how-to-upload-gifs-to-your-keyboard), publicada el 27 de septiembre de 2026, describe selección del S98, apartado TFT y confirmación/guardado. Recomienda GIF pequeño y dimensiones de entrada aproximadas; no demuestra resolución nativa ni formato de transferencia. Sus acciones de conexión y guardado no forman parte de una inspección pasiva autorizada.

## Riesgos y conclusiones que todavía no se pueden extraer

- **Persistencia del recurso TFT:** almacenamiento integrado y una acción de guardado hacen plausible una escritura persistente. No prueban que cada bloque vaya a flash, qué chip se use, ni si hay modo temporal en RAM. La política prudente es tratar toda carga de imagen como potencialmente persistente hasta obtener evidencia.
- **Desgaste:** no se puede calcular vida útil sin conocer tipo de memoria, resistencia por bloque, tamaño de borrado, distribución de escrituras y frecuencia real. No se asigna una cifra genérica de ciclos al S98. Una carga por canción podría seguir siendo excesiva si reutiliza siempre el mismo bloque.
- **Desconectar USB no prueba pérdida de alimentación:** la batería interna puede mantener RAM y RTC. Que un GIF sobreviva a una desconexión USB no demuestra por sí solo almacenamiento no volátil. No se propone abrir el teclado, desconectar su batería ni agotar deliberadamente su carga.
- **Driver conectado:** una sesión que aparentemente solo consulta puede sincronizar hora, volumen u otra configuración. Abrir una página con permisos WebHID recordados puede facilitar una reconexión automática. No conceder acceso al teclado para investigar el código.
- **Comandos de lectura:** un API llamado `get` o `read` puede requerir un output report previo o un selector propietario. En esta fase no se envían esos selectores ni se solicitan feature reports. Solo propiedades que macOS ya publica en IORegistry y análisis offline.
- **Menús nativos:** el objetivo de volver a Spotify tras 5–10 segundos depende de arbitraje de pantalla y detección de menú aún desconocidos. Un evento de volumen no demuestra que el menú esté activo; ausencia de un evento tampoco demuestra que esté cerrado.
- **Restauración incompleta:** guardar descriptores no equivale a una copia de configuración. Un reset puede borrar preferencias; tampoco hay prueba de que reponga un recurso personalizado anterior. La primera escritura debe esperar a conocer qué se sustituye y cómo se recupera.
- **Privacidad de capturas:** una captura general de input HID puede contener pulsaciones. La fase actual no captura input reports. Cuando se plantee una futura captura, debe acotarse a la interfaz investigada, a un intervalo breve y a acciones deliberadas sin introducir datos personales.

## Baseline que falta registrar de la unidad física

Los apartados siguientes son una lista de recogida, no datos ya obtenidos:

1. Foto de etiqueta de modelo/revisión, distribución del teclado y posiciones actuales de interruptores. Mantener serie y etiquetas privadas fuera de documentación pública.
2. Modelo y versión de macOS, fecha/hora, conexión USB o inalámbrica actual, cable/adaptador/hub y periféricos conectados al passthrough. No cambiar esas conexiones solo para obtener una fotografía inicial.
3. VID/PID reales, producto/fabricante, transporte, localización USB y relación entre servicios HID y ancestros USB; serie si existe, almacenada localmente.
4. Número de interfaces, clases/subclases/protocolos, colecciones, usage pages/usages, report IDs, tamaños input/output/feature y bytes de report descriptors. Marcar expresamente los campos ausentes, sin adivinarlos.
5. Endpoints y sus atributos si el registro los expone. Su ausencia en IORegistry no demuestra que no existan.
6. Foto o vídeo breve de la pantalla actual y RGB sin tocar dial ni teclas. Anotar si muestra reloj, GIF o menú y si hay algún driver oficial ya activo. No abrirlo para completar datos.
7. Anotar modificaciones históricas conocidas: GIF personalizado, macros, RGB, Win/Mac, emparejamientos. Usar memoria del usuario y copias ya existentes; no recorrer ajustes ni exportar con el driver en esta fase.
8. Conservar el archivo original del GIF y cualquier configuración previamente exportada si ya existen. Actualmente no se garantiza que pueda recuperarse el recurso desde el teclado.
9. Documentar regreso a Home a partir del manual propio y experiencia del usuario. La demostración mediante dial se reserva a una revisión explícita posterior porque cambia el estado de pantalla.
10. Identificar el procedimiento de recuperación aplicable a esa revisión y los datos que podría perder. El reset publicado arriba sigue sin ejecutarse.

## Siguiente experimento prioritario: observar IORegistry

La mayor ganancia inicial con menor riesgo es contrastar la enumeración local contra la unidad real, sin abrirla con una API HID. Si ya está conectada por USB, mantener el cableado y controles como están y ejecutar la utilidad `info` documentada en el README. El coordinador revisa primero su salida y determina si realmente contiene el S98 por USB o solo un receptor/dispositivo distinto.

Como recogida auxiliar reproducible, desde la raíz del repositorio, estos comandos leen el registro de macOS y escriben únicamente archivos locales:

```sh
mkdir -p research/original-state
/usr/sbin/ioreg -a -r -c IOHIDDevice > research/original-state/iohid-passive.plist
/usr/sbin/ioreg -a -p IOUSB -l -w 0 > research/original-state/iousb-passive.plist
```

Las capturas pueden incluir metadatos de otros periféricos: conservarlas localmente e ignoradas por Git; compartir preferentemente el informe filtrado de la utilidad del proyecto. Si el modelo no aparece, **no abrir el Web Driver ni instalar drivers como alternativa automática**. El siguiente paso es que el usuario revise junto al coordinador la conexión USB y confirme la preparación física, antes de cambiar interruptores o modo.

Esta observación puede confirmar identidad, topología e interfaces candidatas. No demuestra cuál maneja la TFT; eso exige correlación con filtros del Web Driver y análisis estático de sus rutas de comunicación. Tampoco constituye backup de RGB, keymap, TFT o configuración.

## Experimentos posteriores, todavía no autorizados

Orden propuesto después de revisar la fase actual:

1. Completar manual y baseline original; examinar archivos públicos del driver sin conceder WebHID. Si ya se agotó el análisis estático, preparar un entorno de inspección aislado del dispositivo para estudiar el flujo de conexión.
2. Una futura captura pasiva de tráfico real debe indicar qué componente captura, interfaz, cobertura y limitaciones. Registrar `sendReport`/`sendFeatureReport` en JavaScript solo observa esas llamadas; no prueba por sí solo todo el tráfico del sistema ni convierte las acciones del driver en pasivas.
3. Solo con autorización específica: observar UNA carga oficial de imagen mínima, con parámetros, secuencia y riesgos previamente explicados. Esa propuesta está en [phase-3-one-upload.md](phase-3-one-upload.md). A 2026-10-01 sigue sin ejecutarse, y este archivo no la autoriza.
4. Antes de automatizar cambios de canción, resolver persistencia y arbitraje con menú. Que una carga aislada funcione no autoriza actualización continua.

La recuperación de una futura prueba sigue la jerarquía del proyecto: detener emisor, volver a Home con controles verificados, reconexión si procede, restauración oficial conocida y reset solo como último recurso autorizado. Cada escalón se evalúa por separado; no ejecutar una cadena automática de recuperación. Firmware, DFU, bootloader y herramientas de borrado quedan fuera del plan.
