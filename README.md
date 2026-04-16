# OverText Corrector

OverText Corrector es una app open source para macOS que corrige texto seleccionado usando OpenAI. Vive en la menubar y está pensada para trabajar entre aplicaciones mediante un atajo global, `Services` de macOS y `Accessibility`.

Seleccionas texto, ejecutas la acción y la app intenta devolver el resultado corregido en el mismo campo. Si la aplicación de destino no permite reemplazo directo, deja el texto corregido en el portapapeles para pegarlo manualmente.

## Estado del proyecto

El proyecto está funcional para uso local y pensado como base abierta para seguir iterando.

Incluye hoy:

- app nativa de menubar para macOS
- onboarding inicial
- integración con OpenAI
- corrección de texto por bloques
- evaluación conservadora de salida
- atajo global configurable
- atajo secundario para traducir al inglés
- `Services` de macOS para distintos tonos
- integración con `Accessibility`
- almacenamiento de API key en `Keychain`

## Características

- Corrige ortografía, gramática, puntuación y claridad.
- Mantiene el idioma original del texto.
- Permite elegir tono de salida.
- Intenta reemplazo directo en la app activa.
- Usa fallback al portapapeles cuando no puede escribir de vuelta.
- Muestra notificaciones opcionales del flujo.
- Permite configurar modelo, temperatura y límites.

## Requisitos

- macOS 14 o superior
- Xcode
- una API key de OpenAI

## Instalación

La forma recomendada de usar este repositorio hoy es compilarlo localmente.

1. Clona este repositorio.
2. Abre [AITextCorrector.xcodeproj](/Users/gonzalopastorp/Dev/NuevoCorrector/AITextCorrector.xcodeproj) en Xcode.
3. Selecciona el target `AITextCorrector`.
4. Configura tu `Team` de firma si Xcode lo solicita.
5. Compila y ejecuta la app.

## Primer arranque

Al abrir la app por primera vez:

1. abre `Settings`
2. guarda tu API key de OpenAI
3. concede permiso de `Accessibility`
4. opcionalmente permite notificaciones
5. prueba primero en `TextEdit` o `Notes`

## Uso

### Atajo global

1. Selecciona texto en cualquier app compatible.
2. Usa el atajo global.
3. La app intentará leer la selección, corregirla y reemplazarla.

Atajo por defecto para corregir:

- `Control + Option + Command + C`

Atajo por defecto para traducir al inglés:

- `Control + Option + Command + E`

### Services de macOS

En aplicaciones compatibles con `Services`, también puedes usar:

- `Corregir con AI`
- `Corregir con AI (Friendly)`
- `Corregir con AI (Formal)`
- `Corregir con AI (Business)`
- `Corregir con AI (Technical)`
- `Corregir con AI (Concise)`

## Cómo funciona

El flujo general es este:

1. capturar el texto seleccionado
2. enviarlo a OpenAI con instrucciones para corregir sin traducir ni resumir
3. revisar si la salida parece segura
4. intentar reemplazar el texto en la app activa
5. si eso falla, dejar el resultado en el portapapeles

La app sigue una estrategia conservadora: prioriza no romper el texto del usuario cuando la integración con la app destino no es confiable.

## Permisos

### Accessibility

Es el permiso principal. Se usa para:

- leer la selección
- detectar el campo enfocado
- intentar reemplazo directo
- mejorar el comportamiento del atajo global

Sin este permiso, la utilidad del proyecto baja bastante fuera de apps muy cooperativas.

### Notificaciones

Es opcional, pero útil para saber:

- cuándo terminó una corrección
- si hubo reemplazo directo
- si el resultado quedó en el portapapeles
- si falta algún permiso o hubo un error

## Limitaciones

Funciona mejor en aplicaciones que exponen correctamente sus campos de texto a macOS, por ejemplo:

- `TextEdit`
- `Notes`
- campos estándar en apps AppKit o SwiftUI

Puede fallar o degradar al portapapeles en:

- apps Electron
- editores web complejos
- campos enriquecidos personalizados
- apps que no exponen bien `Accessibility`

macOS no ofrece una API universal que garantice lectura y reemplazo de selección en todas las apps. Por eso el proyecto combina:

- atajo global
- `Services`
- `Accessibility`
- fallback al portapapeles

## Distribución y seguridad

Esta versión **no está firmada ni notarizada por Apple**.

Eso implica que:

- no está empaquetada como app lista para distribución masiva
- lo normal es usarla compilándola localmente desde Xcode
- si exportas la app manualmente, macOS puede mostrar advertencias de seguridad

Si macOS bloquea la apertura:

1. intenta abrir la app una vez
2. ve a `System Settings > Privacy & Security`
3. permite la apertura manualmente
4. vuelve a abrirla

La API key se guarda en `Keychain`. La configuración no sensible se guarda en `UserDefaults`.

## Configuración

Desde `Settings` puedes cambiar:

- API key
- modelo
- tono predeterminado
- temperatura
- máximo de caracteres de entrada
- máximo de tokens de salida
- atajo global de corrección
- atajo para traducir al inglés
- notificaciones
- reemplazo automático cuando sea posible
- restauración del portapapeles
- logs técnicos opcionales

## Stack

- Swift
- SwiftUI
- AppKit
- Accessibility API
- Carbon Hot Keys
- Keychain Services
- UserNotifications

## Contribuir

Las contribuciones son bienvenidas.

Áreas especialmente interesantes para seguir mejorando:

- compatibilidad con más apps y editores
- heurísticas de reemplazo por aplicación
- tests para chunking, sanitización y evaluación de riesgo
- experiencia de onboarding y permisos
- firma, notarización y distribución

Si vas a proponer cambios grandes, abrir un issue primero puede ayudar a alinear el enfoque.

## Licencia

Este repositorio no declara todavía una licencia en este README. Si planeas publicarlo como open source para contribuciones externas, conviene añadir un archivo `LICENSE`.
