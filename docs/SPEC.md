# Especificación — Slow Mode

Fuente de verdad del diseño. Prototipo en vivo: https://claude.ai/artifact/32rSSp5vdRiye3FLYEPFPM (dos filas: tema oscuro y negro puro OLED).

## 1. Estilo visual

- **Base oscura** con cristal Liquid Glass del sistema en la navegación y los controles.
- **Acentos pastel** para tarjetas destacadas y estados activos:
  - Periwinkle: `#CBD6F8` → `#AEBFF0` (degradado 145°). Acento sólido `#B9C8F2`.
  - Rosa: `#F6D3E8` → `#EDB9D8`. Acento sólido `#F1C4DF`.
  - Neutros de apoyo: arena `#D2BDB8`, crema `#F4F1EA`, índigo `#3A3F78`.
- Texto principal `#F4F4F5`; secundario `#A3A3AD`; tinta sobre pastel `#101014`.
- Tipografía: SF Pro (sistema). Cifras grandes en peso light con tracking negativo; títulos en medium. Cifras tabulares (`.monospacedDigit()`) en contadores y tiempos.
- Esquinas: tarjetas 28 pt, listas 24 pt, pills en cápsula.
- **Fondo ambiental**: manchas de color muy desenfocadas (periwinkle, rosa, índigo) detrás del contenido. En Reproduciendo toman el color de la portada y se mueven despacio mientras suena.

### Apariencia "Negro puro (OLED)"

Opción en Ajustes (y botón de luna en Inicio), guardada con `@AppStorage("oledBlack")`.
- Fondo `Color.black` exacto.
- Fondo ambiental casi apagado fuera de Reproduciendo (opacidad ~0.05–0.1); en Reproduciendo, algo más tenue que en el tema oscuro.
- Superficies de contenido muy oscuras y translúcidas; el borde de luz del cristal hace el trabajo.

## 2. Navegación

`TabView` con 4 pestañas: **Inicio**, **Buscar**, **Biblioteca**, **Comunidad**.
- Buscar como `Tab(role: .search)` si el SDK lo permite, para que iOS lo coloque a la manera del sistema.
- **Minirreproductor** en `.tabViewBottomAccessory`: portada redonda, título, artista o "@creador del preset", botón play/pausa y, solo si Slow Mode está activo, una pill con la velocidad (p. ej. `0.85×`) que lo apaga al tocarla. Tocar el minirreproductor abre Reproduciendo a pantalla completa.
- `.tabBarMinimizeBehavior(.onScrollDown)`.
- Las páginas de artista se abren con push dentro del `NavigationStack` de la pestaña de origen.

## 3. Pantallas

### 3.1 Inicio
1. Cabecera: "Noviembre · 42 pistas en este iPhone" y título "Tu escucha". Botón de luna (apariencia OLED) a la derecha.
2. **Mapa "Descubre"** (tarjeta periwinkle grande): burbuja central con tu artista más escuchado y 6 burbujas alrededor (artistas similares por género y estilo) sobre anillos concéntricos. Cada burbuja es un botón con cristal ligero; tocarla abre ese artista. VoiceOver lee "Nombre, género, 94 % de afinidad".
3. Fila de dos columnas:
   - **Top géneros**: gráfico de burbujas con porcentajes (Indie 37 %, Electrónica 26 %, Dream Pop 26 %, R&B 11 %). Tocar un género filtra la lista de artistas.
   - Columna derecha: **Canciones escuchadas** (tarjeta rosa, p. ej. 1.988) y **Racha** (p. ej. 23 días).
4. **Todos los artistas**: título, contador, botón de orden (reproducciones / A-Z), selector Lista/Cuadrícula y chips de género.
   - Fila: avatar circular, nombre, pill de género, reproducciones y una barra horizontal fina de afinidad.
   - Cuadrícula: 2 columnas con la misma información.

### 3.2 Artista
- Cabecera periwinkle: atrás, avatar grande, nombre, pill de género, "412 reproducciones · nº 1 más escuchado" y botón grande de play.
- Selector de dos pestañas: **Más escuchadas** (por defecto) y **Presets de la comunidad**.
- Más escuchadas: lista limpia (posición, portada, título, reproducciones · duración). Sin insignias de Slow Mode en las filas.
- Presets: la lista de presets (3.6) filtrada por este artista.

### 3.3 Buscar
- Campo de búsqueda ("Artistas, canciones, presets") y chips de ámbito: Artistas, Canciones, Mezclas, Presets.
- Sin texto: cuadrícula 2 columnas de tarjetas de género y estado de ánimo en tonos pastel (Indie, Electrónica, Dream Pop, R&B, Noche, Día de lluvia, Domingo por la mañana, Ralentizado) y lista de **búsquedas recientes** con botón "Borrar".
- Con texto: resultados mezclados con una etiqueta de tipo; las canciones llevan su insignia de origen.
- Estado vacío: "Sin resultados".

### 3.4 Biblioteca
- Título y botón **Crear playlist**.
- Botón **Importar o subir audio** → hoja con "Importar desde Archivos" (MP3, AAC, FLAC, WAV de Archivos o iCloud Drive) y "Subir un original" (grabaciones y mezclas propias que se pueden compartir).
- 4 tiles: **Canciones que te gustan**, **Playlists**, **Álbumes**, **Artistas**. El tile activo cambia la lista de debajo.
- Insignia de origen en cada canción: **Archivo local** (cristal neutro) u **Original subido** (rosa).
- Sección **Presets de Slow Mode guardados**: los que has marcado con me gusta o compartido.

### 3.5 Comunidad
1. **Mezclas originales**: carrusel horizontal de tarjetas cuadradas (autor y duración).
2. **Oyentes como tú**: carrusel de tarjetas con avatar, "% de afinidad" y botón Seguir/Siguiendo.
3. **Presets de Slow Mode**: "Recetas de tempo, tono y reverb para pistas que tienes. No se comparte audio." Muestra los 6 más usados.

### 3.6 Fila de preset (Comunidad, Artista, Biblioteca)
- Avatar del creador, nombre del preset (p. ej. "Daycore"), número de usos a la derecha.
- "@creador · Título — Artista".
- Pills: velocidad (`0.85×`, periwinkle; rosa si es > 1), tono (`−2 st`), reverb (`20 % reverb`, solo si > 0).
- Botón de play: aplica el preset a la pista **local** del usuario. Si no la tiene, mostrar "Necesitas esta pista en tu biblioteca" y ofrecer importarla.
- Corazón con contador (me gusta).
- Filtros: Todos, Ralentizado, Acelerado, Solo tono, Me gusta. Orden: Popular / Recientes.

### 3.7 Reproduciendo (pantalla completa)
De arriba abajo:
1. Bajar (cerrar) · "Reproduciendo desde [Artista]".
2. Portada grande (~300 pt; se encoge a ~168 pt al abrir el panel de Slow Mode).
3. Título, subtítulo (artista · "Archivo local" / "Original subido" / "Daycore de @creador"), botón **Añadir a playlist** y **corazón**. Si Slow Mode cambia algo, una pill con el resumen (`0.85× · −2 st`).
4. Barra de progreso con tiempos. Con Slow Mode activo los tiempos reflejan la duración estirada (3:34 a 0.85× → 4:12).
5. Controles: **Aleatorio** · Anterior · Play/Pausa · Siguiente · **Repetir** (no / todo / una).
6. Fila: **Salida de audio** (`AVRoutePickerView`, AirPlay/Bluetooth) a la izquierda, **A continuación** (cola en hoja) a la derecha.
7. **Panel Slow Mode** (plegado por defecto): icono, "Slow Mode", resumen ("Desactivado" o `0.85× · −2 st · 20 % reverb`), interruptor y chevron. Activarlo despliega el panel. Desplegado:
   - **Tempo**: 0.50×–1.50×, paso 0.01, marca central en 1.00×, botones −/+.
   - **Tono**: −12 a +12 semitonos, paso 1, botones −/+.
   - **Reverb**: 0–100 %, paso 5.
   - **Vincular tono al tempo** (como un vinil): el tono sigue a la velocidad y su control queda deshabilitado.
   - Presets rápidos: Original, Ralentizado 0.85× (−2 st, 20 %), Profundo 0.75× (−4 st, 45 %), Acelerado 1.15× (+2 st, 0 %).
   - Texto: "15 % más lento · 3:34 pasa a ser 4:12".
   - Botones: **Compartir preset** (publica solo los ajustes) y "N presets" (abre los presets de esa canción).
- Hojas (con cristal del sistema): A continuación, Salida de audio, Añadir a playlist (playlists + "Nueva playlist").

## 4. Audio

Grafo: `AVAudioPlayerNode` → `AVAudioUnitTimePitch` → `AVAudioUnitReverb` → `mainMixerNode`.
- Tempo → `timePitch.rate` (0.5–1.5).
- Tono → `timePitch.pitch` en cents (semitonos × 100).
- Reverb → `reverb.wetDryMix` (0–100), preset de sala tipo `.largeHall` o `.mediumHall`.
- **Vincular tono al tempo**: cambia `AVAudioUnitTimePitch` por `AVAudioUnitVarispeed` (tono = 12·log2(velocidad), como en el prototipo) o calcula el pitch equivalente. Elige y documenta la decisión.
- Slow Mode desactivado: rate 1, pitch 0, reverb 0 (bypass), sin cortes de audio al alternar.
- Cambios en tiempo real y suaves (sin clics al mover los sliders).
- Sesión `AVAudioSession` en `.playback`, modo de fondo "audio", `MPNowPlayingInfoCenter` (con `playbackRate` real) y `MPRemoteCommandCenter` (play, pausa, siguiente, anterior, posición).
- Interrupciones (llamadas) y cambios de ruta (quitar auriculares → pausa).

## 5. Modelo de datos (SwiftData)

- `Track`: id, título, artista, álbum, duración, archivo (bookmark/ruta en el sandbox), origen (`localFile` | `originalUpload`), portada, reproducciones, me gusta, fecha de importación.
- `Playlist`: nombre, pistas ordenadas, fecha.
- `SlowPreset`: id, nombre, tempo, tono, reverb, vinculado, referencia de pista (título + artista + duración aproximada para emparejar con la copia local), creador, usos, me gusta, fecha, `isMine`.
- Estadísticas de escucha derivadas de un registro `PlayEvent` (pista, fecha, segundos, tempo).

## 6. Importación

- `.fileImporter` con `UTType.audio`, selección múltiple. Copiar al contenedor de la app (acceso con security-scoped resource). Leer metadatos y portada con `AVURLAsset`.
- Formatos: MP3, AAC/M4A, WAV, AIFF, FLAC (comprobar compatibilidad con AVFoundation).
- Errores: archivo no compatible, sin espacio, duplicado (ofrecer omitir).

## 7. Comunidad (fases posteriores)

- Fase inicial: datos de ejemplo locales (JSON en el bundle) con la misma forma que el backend final.
- Backend: **no CloudKit** (exige cuenta de desarrollador de pago y la app se instala con una gratuita). Opción propuesta: un backend externo con API HTTP (p. ej. Supabase o Firebase) para presets, perfiles y mezclas originales; se decidirá en la Fase 5. Requiere moderación y denuncias antes de abrirlo.

## 8. Estados obligatorios

Cada pantalla con datos tiene estado de carga, vacío y error con reintento. Ejemplos de vacíos: biblioteca sin pistas ("Importa tu música para empezar" + botón), sin presets guardados, búsqueda sin resultados.
