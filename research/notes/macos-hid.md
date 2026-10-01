# Inspección HID en macOS: fase de solo lectura

Fecha: 2026-10-01. Este documento describe la herramienta y sus límites; los resultados del teclado físico los consolida el coordinador.

## Elección provisional

Swift con Foundation e IOKit del SDK de Apple permite consultar IORegistry sin instalar dependencias. Se usa `IOServiceGetMatchingServices("IOHIDDevice")` y se leen propiedades publicadas mediante `IORegistryEntryCreateCFProperties`. Se recorre la cadena de padres hasta el dispositivo USB para recuperar número/clase/protocolo de interfaz y propiedades USB disponibles.

La herramienta no abre dispositivos, no crea un IOHIDManager, no registra callbacks de input, no lee pulsaciones, no solicita feature reports ni realiza transacciones USB/HID. Tampoco solicita permisos de Input Monitoring ni acceso exclusivo. No requiere `sudo`. Consulta metadatos que macOS ya publica; la enumeración USB que el propio sistema realiza al conectar un teclado queda fuera de esta utilidad.

Esta elección solo fija el diagnóstico de fase inicial. No decide el lenguaje del daemon futuro. Swift ofrece APIs nativas e integración macOS; Rust, Node y Python habitualmente requieren bindings o librerías adicionales para HID. `hidapi` resulta útil posteriormente, pero abrir un handle no aporta nada necesario para esta primera instantánea. `ioreg` es una alternativa nativa para contrastar propiedades. `system_profiler SPUSBDataType` ofrece inventario USB, pero no sustituye descriptores HID ni garantiza una lista completa en todos los hosts.

## Qué obtiene

- Todos los servicios HID con VID `0x258A` por defecto; no filtra PID ni declara un S98 confirmado.
- Fabricante, producto, transporte, VID/PID, versión y propiedades de interfaz USB publicadas.
- `PrimaryUsagePage`, `PrimaryUsage` y `DeviceUsagePairs` cuando existan. Los usages primarios no representan por sí solos todas las colecciones.
- `MaxInputReportSize`, `MaxOutputReportSize`, `MaxFeatureReportSize` tal y como los publica macOS.
- Report descriptor crudo en hexadecimal, su longitud y resumen estructural offline: colecciones, usage page/usage, Report IDs y tamaño por tipo/ID.
- Campos USB/endpoints únicamente si están publicados en el servicio o sus ancestros. No se obtiene activamente el descriptor completo de configuración USB.
- Indicación explícita si falta `ReportDescriptor` y advertencias si el descriptor
  usa construcciones no cubiertas por el parser. Las demás propiedades no
  publicadas simplemente no aparecen en el JSON.

El parser suma `Report Size × Report Count` por tipo/ID, incluye padding y redondea a bytes al final. `payload_bytes` excluye el byte de Report ID; `wire_bytes_including_report_id` añade uno solo para IDs distintos de cero. Estos tamaños son los declarados por el descriptor; no prueban la longitud real de una carga TFT ni la convención de buffers de todas las APIs. Soporta globals PUSH/POP y counts de varios bytes. No decodifica campos individuales, valores lógicos, unidades ni semántica de comandos. `complete` significa que el resumen estructural no encontró advertencias; no certifica que el descriptor cumpla toda la especificación HID.

## Ejecución reproducible

Desde la raíz del repositorio, con Xcode o Command Line Tools que incluyan Swift y el SDK macOS:

```sh
mkdir -p .build
xcrun swiftc -warnings-as-errors src/keyboard/HIDDescriptor.swift src/keyboard/RegistryInspector.swift src/cli/main.swift -o .build/rk-s98
.build/rk-s98 info
```

Salida JSON. `matching_hid_service_count: 0` es un resultado válido, no confirma ausencia física: puede haber otro VID, otro modo de conexión o metadatos no disponibles.

Por defecto omite número de serie, registry IDs/paths, dirección USB y ubicación. Para correlacionar varias interfaces de varios dispositivos iguales, una captura local explícita puede conservar identificadores:

```sh
.build/rk-s98 info --include-identifiers
```

No publicar esa salida sin revisarla. El flag no amplía operaciones sobre el teclado; solo amplía los campos JSON. VID alternativo, si existe evidencia:

```sh
.build/rk-s98 info --vid 0x258A
```

Descriptor binario ya guardado, análisis totalmente offline:

```sh
.build/rk-s98 descriptor path/to/report-descriptor.bin
```

## Validación realizada por el subagente

```sh
./tests/run.sh
```

Compilación con `-warnings-as-errors` en Swift 6.4, macOS arm64: correcta. Pasan 30 aserciones unitarias, incluida la asociación de un report con su colección de nivel superior. El offset guardado es el byte del item `COLLECTION`, no el byte de usage anterior. El smoke añade dos verificaciones sobre el JSON de un descriptor binario sintético. Se verifican además ayuda, rechazo de VID inválido, opción desconocida y comando `display` inexistente. El script nunca ejecuta una enumeración válida contra el teclado. Se probó inicialmente `plutil -lint` para validar JSON, pero no acepta JSON como plist en este host; se sustituyó por `JSONSerialization` del propio test Swift.

Casos relevantes cubiertos: teclado boot con padding, separación input/output, report ID 0 frente a ID explícito, feature report, count de 16 bits, PUSH/POP, redondeo, item truncado, long item no soportado, pila/colecciones desbalanceadas, ID cero explícito inválido, overflow y Usage extendido de 32 bits.

No se han ejecutado operaciones físicas desde este subagente. Una ejecución por el coordinador debe confirmar qué propiedades expone el dispositivo concreto. No hay tests para Spotify/TFT porque no se implementa ninguna de esas integraciones en esta fase.

## Evidencia comunicada por el coordinador

La inspección pasiva IOUSB encontró `Gaming Keyboard`, fabricante `SINO WEALTH`, VID `0x258A`, PID `0x022B`, bajo un hub USB 2.0. No se sustituye por el PID `0x0174` citado como referencia. Una ejecución posterior de `info` guardó los report descriptors de las interfaces 0 y 1. El 2026-10-01 a las 01:55, con la pantalla del teclado encendida, la misma lectura volvió a devolver ese único `258A:022B`, y el usuario lo identificó como su RK-S98. El detalle está en `research/original-state/`.

## Límites y siguiente evidencia

Un VID es un filtro de candidatos, no prueba del fabricante comercial/modelo. Un descriptor vendor-defined tampoco confirma que su interfaz sea la TFT. Debe cruzarse con la tabla de selección del driver oficial y con la identificación física del usuario. El número de servicios HID puede diferir del número de dispositivos físicos o interfaces USB; conservar la relación de ancestros permite distinguirlos.

No hay fallback automático a abrir un dispositivo si falta el descriptor; esa ausencia se conserva como desconocida. No se exporta configuración persistente ni estado de TFT: leerlos puede requerir comandos propietarios, ajenos al alcance autorizado. Los datos de IORegistry son una instantánea y pueden cambiar al desconectar/reconectar.

## Fuentes primarias

- [Apple: IOServiceGetMatchingServices](https://developer.apple.com/documentation/iokit/1514494-ioservicegetmatchingservices), enumeración de servicios registrados.
- [Apple: IOKitLib.h](https://developer.apple.com/documentation/iokit/iokitlib_h), funciones de consulta de IORegistry.
- [Apple Open Source: IOHIDKeys.h](https://github.com/apple-oss-distributions/IOHIDFamily/blob/main/IOHIDFamily/IOHIDKeys.h), clave IOHIDDevice, alcance de primary usages y DeviceUsagePairs, efecto de seize/exclusividad.
- [USB-IF: HID 1.11](https://www.usb.org/sites/default/files/hid1_11.pdf), estructura de items y cálculo de longitud/IDs de report.
- SDK macOS instalado: `IOKit/hid/IOHIDDeviceKeys.h`, constantes de propiedades HID; compilación contrastada con el SDK local.
