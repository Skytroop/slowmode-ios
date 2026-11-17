# Plan de trabajo

Una fase por sesión (o por petición). Al terminar cada fase: push, CI en verde (`gh run watch`), y resume lo hecho, lo pendiente y qué debe probar el usuario en el iPhone.

## Fase 0 — Proyecto
- `project.yml` y `.github/workflows/build.yml` ya existen: úsalos y ajústalos si hace falta, sin cambiar el enfoque (XcodeGen + CI).
- Código en `SlowMode/` y tests en `SlowModeTests/` (las dos carpetas que lee `project.yml`). Estructura dentro de `SlowMode/`: `App/`, `Features/{Home,Search,Library,Community,Artist,Player}/`, `Services/{Audio,Library,Presets}/`, `Models/`, `DesignSystem/`, `Resources/SampleData/`.
- Primer objetivo: una app mínima (una pantalla, un test trivial) que pase el CI y genere el `.ipa`, para que el usuario confirme que la instala en su iPhone antes de seguir.
- `DesignSystem`: colores de `docs/SPEC.md`, estilos de texto, pill, chip, insignia de origen, fondo ambiental y la opción OLED.
- Datos de ejemplo en JSON (artistas, canciones, presets) copiados del prototipo de `design/prototipo-referencia.html` (función `db()`).

## Fase 1 — Esqueleto navegable
- `TabView` de 4 pestañas con `NavigationStack` en cada una.
- Minirreproductor en `.tabViewBottomAccessory` (con datos falsos).
- Reproduciendo como pantalla completa con sus controles (sin audio aún).
- Todas las pantallas con datos de ejemplo, siguiendo `docs/SPEC.md`.

## Fase 2 — Motor de audio y Slow Mode
- `AudioEngineService` con el grafo de la sección 4 y tests del cálculo de tempo/tono/duración.
- Reproducción real de archivos de audio incluidos para pruebas (generados o libres de derechos).
- Panel Slow Mode conectado; cola, aleatorio, repetir.
- Audio en segundo plano, centro de control y pantalla bloqueada, interrupciones, `AVRoutePickerView`.

## Fase 3 — Biblioteca real
- Importación con `.fileImporter`, metadatos y portadas, insignias de origen.
- Me gusta, playlists (crear, añadir), álbumes y artistas derivados de las pistas.
- Estadísticas de Inicio a partir de `PlayEvent`.

## Fase 4 — Presets
- Guardar, compartir (local por ahora), aplicar a la pista local y emparejar pistas por título/artista/duración.
- Sección de presets guardados en Biblioteca.

## Fase 5 — Comunidad con backend
- Backend externo con API HTTP (no CloudKit: exige cuenta de pago; ver `docs/SPEC.md` §7), perfiles, seguir, subida de originales, moderación.

## Fase 6 — Pulido
- Accesibilidad (VoiceOver, Dynamic Type, reducir transparencia/movimiento), estados de carga/vacío/error, rendimiento en dispositivos antiguos, iconos y pantalla de inicio.
