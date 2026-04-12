# AI Text Corrector for macOS

Aplicación nativa para macOS que replica la filosofía del corrector actual del navegador, pero orientada a funcionar en todo el sistema con:

- app de menubar
- shortcut global configurable
- integración con macOS Services donde aplique
- lectura y reemplazo por Accessibility cuando sea posible
- fallback conservador al portapapeles cuando no se puede reemplazar

## Estado del proyecto

Este entregable deja una base funcional y modular con dos capas ya implementadas:

- Fase 1:
  - menubar app
  - settings
  - API key en Keychain
  - shortcut global configurable
  - corrección con OpenAI
  - chunking de textos largos
  - evaluación conservadora de salida
  - fallback universal por portapapeles
- Fase 2:
  - onboarding
  - detección de permisos
  - lectura de selección con Accessibility
  - intento de reemplazo directo con Accessibility
  - Services de macOS para varios tonos

## Estructura

```text
AITextCorrector/
  App/
  Accessibility/
  Core/
  Models/
  Storage/
  UI/
AITextCorrector.xcodeproj
README.md
```

## Requisitos

- macOS 14 o superior
- Xcode moderno
- una API key de OpenAI

## Cómo abrirlo en Xcode

1. Abre [AITextCorrector.xcodeproj](/Users/gonzalopastorp/Dev/NuevoCorrector/AITextCorrector.xcodeproj).
2. Selecciona el target `AITextCorrector`.
3. Configura tu `Team` de firma si Xcode te lo pide.
4. Compila y ejecuta la app.

## Cómo usarlo

1. Ejecuta la app.
2. Se abrirá onboarding si falta API key o permiso de Accessibility.
3. Desde el menubar abre Settings.
4. Guarda tu API key en Keychain.
5. Revisa o cambia:
   - tono predeterminado
   - modelo
   - temperature
   - máximo de caracteres de entrada
   - máximo de tokens de salida
   - shortcut global
   - notificaciones
   - reemplazo automático
6. Otorga permiso de Accessibility.
7. Selecciona texto en una app.
8. Usa el shortcut global o el Service.

## Permisos necesarios

### Accessibility

Es el permiso principal. Se usa para:

- detectar el elemento enfocado
- leer texto seleccionado en apps compatibles
- intentar reemplazar directamente la selección
- disparar el fallback de captura por copia en el shortcut global

Sin este permiso, el flujo universal con shortcut global queda muy limitado.

### Notificaciones

Opcional, pero recomendado para:

- avisos de corrección en progreso
- fallback a portapapeles
- errores de permisos o selección

### Automation

No es requerido en esta versión porque no se depende de AppleScript para automatizar otras apps.

## Shortcut global

Valor inicial:

- `Control + Option + Command + C`

Se puede cambiar desde Settings.

## Services de macOS

Se incluyen Services para:

- `Corregir con AI`
- `Corregir con AI (Friendly)`
- `Corregir con AI (Formal)`
- `Corregir con AI (Business)`
- `Corregir con AI (Technical)`
- `Corregir con AI (Concise)`

macOS solo mostrará estos Services en apps que expongan texto seleccionado al sistema mediante el mecanismo estándar de Services.

## Lógica de corrección

La app conserva la filosofía del corrector previo:

- tono configurable
- `temperature` configurable
- límite máximo de caracteres
- límite máximo de tokens de salida
- división automática en bloques
- preservación de párrafos, listas y saltos de línea
- detección de salidas sospechosas
- política conservadora: mejor portapapeles que reemplazo inseguro

Prompt base aplicado por chunk:

- corregir ortografía, gramática, puntuación y claridad
- mantener idioma original
- no traducir
- no resumir
- no explicar
- no añadir markdown ni encabezados
- devolver solo el texto corregido

## Limitaciones reales de macOS

### Dónde sí puede funcionar el reemplazo directo

Suele funcionar mejor en:

- TextEdit
- Notes en varios campos
- apps AppKit o SwiftUI que exponen `AXValue` y `AXSelectedTextRange`
- algunos campos de texto estándar del sistema

### Dónde puede fallar el reemplazo directo

Puede fallar o degradar a portapapeles en:

- Slack
- editores embebidos en Electron
- campos web complejos dentro de navegadores
- apps con vistas custom que no exponen atributos AX editables
- apps con editores enriquecidos no estándar

### Por qué no es universal

macOS no ofrece una API universal que garantice:

- leer la selección de cualquier app
- insertar texto en cualquier editor
- inyectar una opción propia de clic derecho en todos los menús contextuales del sistema

Por eso la estrategia correcta es:

1. shortcut global robusto
2. Services donde existan
3. Accessibility cuando la app destino lo permita
4. fallback seguro al portapapeles

## Flujo real esperado

### Caso ideal

1. Seleccionas texto.
2. Presionas el shortcut.
3. La app toma el texto seleccionado por Accessibility.
4. Lo corrige con OpenAI.
5. Reemplaza la selección en el mismo control.

### Caso conservador

1. Seleccionas texto.
2. Presionas el shortcut.
3. La app lo captura por copia temporal.
4. Lo corrige.
5. Si no puede reemplazar con seguridad, lo deja en el portapapeles y te avisa.

### Caso con revisión manual

Si la salida parece sospechosa, la app:

- no reemplaza automáticamente
- copia el resultado al portapapeles
- notifica que conviene revisar manualmente

## Seguridad

- la API key se guarda en Keychain
- los settings no sensibles se guardan en `UserDefaults`
- no se registran textos del usuario por defecto
- el modo de logs técnicos existe, pero está apagado por defecto

## Dependencias

No se usan dependencias externas.

Stack usado:

- Swift
- SwiftUI
- AppKit
- Accessibility API
- Carbon para hotkey global
- Keychain Services
- UserNotifications

## Compilar y probar

1. Abre el proyecto en Xcode.
2. Ajusta firma si hace falta.
3. Ejecuta la app.
4. Ve a Settings y guarda tu API key.
5. Concede Accessibility.
6. Prueba primero en TextEdit o Notes.
7. Selecciona texto y usa el shortcut.
8. Repite la prueba en apps más restrictivas para validar el fallback.

## Verificación local realizada

En este entorno:

- el código Swift pasa `swiftc -typecheck`
- el proyecto Xcode quedó generado en disco

No pude ejecutar `xcodebuild` aquí porque la instalación de Xcode del entorno está incompleta y falla cargando `IDESimulatorFoundation` / `CoreSimulator`. Si te ocurre localmente, normalmente se resuelve con una instalación completa de Xcode o ejecutando:

```bash
xcodebuild -runFirstLaunch
```

## Próximos pasos recomendados

1. Afinar reemplazo directo por app con heurísticas específicas.
2. Mejorar el recorder visual del shortcut.
3. Añadir indicador visual más rico durante la corrección.
4. Agregar tests unitarios para chunking, sanitización y evaluación de riesgo.
5. Añadir restauración opcional del portapapeles cuando el flujo termina en reemplazo directo.
