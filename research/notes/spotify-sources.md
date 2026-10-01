# Fuentes de Now Playing y carátula en macOS

Investigación documental y lectura local, 2026-10-01. No se ha usado la Web API ni el teclado desde esta nota. Una consulta de solo lectura, `rk-s98 spotify status`, respondió `unavailable` con Spotify cerrado. Con Spotify abierto y una pista en reproducción, la misma consulta devolvió estado, título, artista, álbum, id y URL de carátula, y `render --spotify` compuso el PNG sin abrir el teclado. No se ha probado aún pausa, Spotify cerrado a medias, anuncios ni archivos locales.

## Hallazgos comprobados

### Diccionario de scripting de la instalación local

`/Applications/Spotify.app/Contents/Resources/Spotify.sdef` existe en este Mac. La versión indicada por `CFBundleShortVersionString` es `1.3.0.277`. Su clase `application` declara `current track` (solo lectura) y `player state` (solo lectura; `stopped`, `playing`, `paused`). La clase `track` declara `name`, `artist`, `album`, `id`, `artwork url`, `album artist` y `spotify url`. `artwork` figura como obsoleto y dice que nunca se rellenará; debe usarse `artwork url`. Esto demuestra la **interfaz declarada en el paquete instalado**, no que todas las propiedades funcionen en reproducción real, sin permisos o con cada tipo de contenido.

Apple documenta que AppleScript y Scripting Bridge se comunican mediante Apple Events. Una futura aplicación que envíe Apple Events necesita declarar `NSAppleEventsUsageDescription` y puede requerir permiso de Automatización. Scripting Bridge sería una envoltura tipada de la misma vía, no otra fuente de datos. [Guía Apple de scripting](https://developer.apple.com/library/archive/documentation/LanguagesUtilities/Conceptual/MacAutomationScriptingGuide/HowMacScriptingWorks.html); [NSAppleEventsUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nsappleeventsusagedescription).

### Now Playing del sistema

`MPNowPlayingInfoCenter` es una API pública para **publicar** información de medios reproducidos por la propia app; su documentación no promete leer la sesión Now Playing de otra app. La documentación actual de Now Playing se centra en proporcionar sesiones mediante una extensión. Por ello, no hay base documental para escoger `MPNowPlayingInfoCenter` como lector de Spotify. Las soluciones basadas en `MediaRemote` deben considerarse experimentales hasta verificar estabilidad, permisos y disponibilidad de API pública; no se recomienda una dependencia privada para el MVP sin esa evaluación. [MPNowPlayingInfoCenter](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter); [Now Playing framework](https://developer.apple.com/documentation/nowplaying).

### Spotify Web API como alternativa

`GET /v1/me/player/currently-playing` requiere `user-read-currently-playing` y documenta `is_playing`, `item`, tipo de elemento (`track`, `episode`, `ad`, `unknown`), ID del track, artistas, álbum y `album.images` en varios tamaños. `item` puede ser nulo. Para una app local de escritorio, Spotify recomienda Authorization Code con PKCE cuando no puede protegerse un secreto de cliente. [Endpoint](https://developer.spotify.com/documentation/web-api/reference/get-the-users-currently-playing-track); [autorización](https://developer.spotify.com/documentation/web-api/concepts/authorization); [PKCE](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow).

La Web API introduce cuenta de desarrollador, OAuth, red y límites. En modo de desarrollo, el propietario necesita Premium y se permiten hasta cinco usuarios autenticados. La cuota de desarrollo se comparte por cuenta de desarrollador, según la actualización de julio de 2026. Spotify documenta respuestas 429, `Retry-After` para rate limiting y un motivo `QUOTA_EXCEEDED` para cuotas. [Modos de cuota](https://developer.spotify.com/documentation/web-api/concepts/quota-modes); [actualización de julio de 2026](https://developer.spotify.com/blog/2026-07-23-web-api-quota-updates); [límites de llamadas](https://developer.spotify.com/documentation/web-api/concepts/rate-limits).

Los [Developer Terms](https://developer.spotify.com/terms) permiten solo caché **temporal** de metadatos y carátulas cuando sea estrictamente necesaria para el funcionamiento o rendimiento, y no almacenamiento indefinido. La [Developer Policy](https://developer.spotify.com/policy) y las [guías de diseño](https://developer.spotify.com/documentation/design) exigen atribución Spotify y enlace al contenido correspondiente al mostrar metadatos/carátula obtenidos de la plataforma; además restringen alterar la carátula (se permite ajustar tamaño). Una TFT sin interacción web plantea una cuestión práctica sobre cómo satisfacer el enlace. Antes de elegir Web API para la pantalla, hay que revisar ese diseño y las condiciones vigentes. Esto no determina por sí solo cómo se aplican los términos a los datos extraídos localmente de la app.

## Valoración y preguntas abiertas

1. **Primera opción a probar: scripting local de Spotify.** La interfaz instalada promete todos los campos necesarios, incluida URL de carátula, sin OAuth. Falta comprobar valores reales, episodios/anuncios/archivos locales, comportamiento cuando Spotify está cerrado y latencia/cambios de pista. La URL implica acceso de red para obtener los bytes de imagen; su validez y política de caché no están verificadas.
2. **Now Playing genérico:** atractivo para otros reproductores, pero no se ha identificado una API pública de lectura entre procesos que garantice los campos y carátula requeridos. No bloquear el diagnóstico local de Spotify por esta vía.
3. **Web API:** alternativa documentada si scripting no da carátula utilizable o es inestable. Añade permisos, credenciales, cuota y obligaciones de presentación. No implementarla aún.

## Siguiente diagnóstico local propuesto

Cuando el usuario quiera probar la fuente local, reproducir voluntariamente una pista en Spotify y ejecutar una **consulta de propiedades**, sin comandos de reproducción ni teclado:

```bash
osascript -e 'tell application id "com.spotify.client" to get {player state, name of current track, artist of current track, album of current track, id of current track, artwork url of current track, spotify url of current track}'
```

La primera consulta puede abrir Spotify o activar una petición de permiso de Automatización según el estado de macOS; por eso conviene que Spotify ya esté abierto. La salida contiene hábitos de escucha y URL de imagen: revisarla antes de compartirla. Comparar después pausado y cerrado, sin que el script ordene esos cambios. Un fallo de propiedad no invalida todas las demás: probar campos individualmente si ocurre. Esta prueba no toca el RK-S98.
