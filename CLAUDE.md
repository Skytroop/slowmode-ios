# Slow Mode — reproductor de música para iOS

App nativa de iOS: reproductor para la música local del usuario (archivos importados y subidas originales), con una función estrella, **Slow Mode** (tempo, tono y reverb en tiempo real), y una comunidad que comparte **presets** (solo ajustes, nunca audio).

## Stack (no cambiar sin preguntar)

- Swift 6, SwiftUI, objetivo mínimo **iOS 26** (Liquid Glass nativo). Solo iPhone por ahora.
- Audio: `AVAudioEngine` (ver `docs/SPEC.md`, sección Audio). Sin librerías de audio de terceros.
- Datos: SwiftData. Ajustes de usuario: `@AppStorage`.
- Arquitectura: `@Observable` + vistas pequeñas. La lógica (audio, biblioteca, presets) vive en servicios, nunca dentro de las vistas.
- Sin dependencias externas salvo que se pidan.

## Documentos

- `docs/SPEC.md`: pantallas, comportamiento, colores y tipografía. Es la fuente de verdad del diseño.
- `docs/PLAN.md`: fases de trabajo. Trabaja una fase cada vez y para al terminarla.
- `design/prototipo-referencia.html`: código del prototipo interactivo hecho en Claude. **Solo referencia** (datos de ejemplo, colores, textos, lógica de los controles). No se ejecuta por sí solo y no hay que portar su HTML/CSS: recrea el diseño con componentes nativos.
- Prototipo visual en vivo: https://claude.ai/artifact/32rSSp5vdRiye3FLYEPFPM

## Reglas de diseño

- Usa los componentes del sistema y deja que adopten Liquid Glass solos: `TabView` con `Tab`, `NavigationStack`, `.sheet`, toolbars, `.searchable`.
- `glassEffect` solo en la capa de controles (botones, chips, minirreproductor, panel de Slow Mode). El contenido (tarjetas, listas) no es cristal: lleva color o material normal.
- Varios elementos de cristal juntos van dentro de un `GlassEffectContainer`.
- Objetivos táctiles de al menos 44×44 pt. Dynamic Type en todo el texto. Etiquetas de accesibilidad en botones de solo icono.
- Respeta "Reducir transparencia" y "Reducir movimiento".
- SF Symbols para los iconos.

## Reglas de producto

- La app nunca descarga ni comparte audio de terceros. La comunidad comparte presets (tempo, tono, reverb y el título/artista de la pista a la que se aplican) y mezclas originales subidas por el usuario.
- Slow Mode es una función destacada, no el tema de toda la app: no lo metas en pantallas donde no está en `docs/SPEC.md`.

## Entorno: sin Mac

Este ordenador **no es un Mac**: aquí no hay Xcode, `xcodebuild` ni simulador. No intentes compilar en local.
- El proyecto se define en `project.yml` (XcodeGen). No crees ni edites un `.xcodeproj`: se genera en CI. Cada carpeta nueva de código o recurso debe quedar cubierta por `project.yml`.
- Compilar y probar = hacer push a `main`. El workflow `.github/workflows/build.yml` (runner `macos-26`) genera el proyecto, pasa los tests en el simulador y produce `SlowMode.ipa` sin firmar.
- El usuario instala el `.ipa` en su iPhone con sideloading (cuenta de Apple gratuita).

## Comandos (GitHub CLI)

- Ver la ejecución en curso: `gh run watch`
- Ver errores de la última ejecución fallida: `gh run view --log-failed`
- Descargar el `.ipa`: `gh run download --name SlowMode-ipa`

## Forma de trabajar

- Como no puedes compilar en local, escribe Swift con cuidado: tipos explícitos donde la inferencia sea dudosa, APIs de iOS 26 que existan de verdad (si dudas de una firma, dilo en vez de inventarla).
- Agrupa cambios con sentido en cada push: cada compilación en CI tarda varios minutos.
- Tras cada push, espera el resultado con `gh run watch`. Si falla, lee `gh run view --log-failed`, corrige y vuelve a subir antes de seguir con otra cosa.
- Tests unitarios para los servicios (cálculo de tempo/tono, importación, presets); se ejecutan en el simulador de CI. La UI la revisa el usuario en su iPhone: al terminar cada paso, dile qué debe comprobar.
- Commits pequeños, uno por paso del plan.

## Límites de la cuenta de Apple gratuita

La app se firma con una cuenta gratuita al instalarla, así que:
- No uses capacidades que exijan cuenta de pago: iCloud/CloudKit, notificaciones push, App Groups, Sign in with Apple, extensiones (widgets, etc.).
- Audio en segundo plano, acceso a Archivos, SwiftData local y AirPlay sí funcionan.
