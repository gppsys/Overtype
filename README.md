# OverText Corrector para macOS

AI Text Corrector es una app de menubar para macOS que corrige texto seleccionado usando OpenAI. Está pensada para usarse desde cualquier app posible del sistema mediante un atajo global, `Services` de macOS y `Accessibility`.

Seleccionas texto, ejecutas la acción y la app intenta devolverte el texto corregido en el mismo lugar. Si la app de destino no permite reemplazo directo, el resultado queda en el portapapeles para pegarlo manualmente.

## Qué hace

- Corrige ortografía, gramática, puntuación y claridad.
- Mantiene el idioma original del texto.
- Permite elegir tono de salida.
- Tiene atajo global configurable.
- Incluye `Services` de macOS para varios tonos.
- Intenta reemplazo directo por `Accessibility` cuando la app lo permite.
- Usa fallback seguro al portapapeles cuando no puede escribir de vuelta.
- Guarda la API key en `Keychain`.

## Qué incluye esta versión

- App nativa para macOS en menubar.
- Onboarding inicial.
- Configuración de modelo, tono, temperatura y límites.
- Integración con OpenAI.
- Corrección de textos largos por bloques.
- Evaluación conservadora de salida antes de reemplazar.
- Atajo para corrección.
- Atajo secundario para traducir al inglés.
- Integración con `Accessibility`.
- `Services` de macOS.

## Importante

Esta versión **no está firmada ni notarizada por Apple**.

Eso significa que:

- no está pensada para instalarse como app distribuida al público general con doble clic y ya
- lo más simple es usarla desde Xcode y compilarla localmente
- si exportas la app manualmente, macOS puede mostrar advertencias de seguridad o bloquear el primer arranque

Si macOS bloquea la app al abrirla, normalmente puedes:

1. intentar abrirla una vez
2. ir a `System Settings > Privacy & Security`
3. permitir su apertura manualmente
4. volver a abrirla

Si quieres distribuirla como app lista para terceros, tendrías que firmarla y notarizarla aparte.

## Requisitos

- macOS 14 o superior
- Xcode
- una API key de OpenAI

## Instalación

Hoy la forma recomendada de usar este repo es **compilarlo localmente**.

1. Clona este repositorio.
2. Abre [AITextCorrector.xcodeproj](/Users/gonzalopastorp/Dev/NuevoCorrector/AITextCorrector.xcodeproj) en Xcode.
3. Selecciona el target `AITextCorrector`.
4. Configura tu `Team` de firma si Xcode lo pide para compilar localmente.
5. Ejecuta la app.

## Configuración inicial

La primera vez que abras la app:

1. abre `Settings`
2. guarda tu API key de OpenAI
3. concede permiso de `Accessibility`
4. opcionalmente permite notificaciones
5. prueba primero en `TextEdit` o `Notes`

## Cómo usarla

### Opción 1: atajo global

1. Selecciona texto en una app.
2. Usa el atajo global.
3. La app leerá la selección, la corregirá y tratará de reemplazarla.

Atajo por defecto para corregir:

- `Control + Option + Command + C`

Atajo por defecto para traducir al inglés:

- `Control + Option + Command + E`

### Opción 2: Services de macOS

En apps compatibles con `Services`, también puedes usar:

- `Corregir con AI`
- `Corregir con AI (Friendly)`
- `Corregir con AI (Formal)`
- `Corregir con AI (Business)`
- `Corregir con AI (Technical)`
- `Corregir con AI (Concise)`

## Cómo funciona

El flujo real es este:

1. capturar el texto seleccionado
2. enviarlo a OpenAI con instrucciones para corregirlo sin resumirlo ni traducirlo
3. validar si la salida parece segura
4. intentar reemplazar el texto en la app activa
5. si eso falla, dejar el resultado en el portapapeles

La app prioriza un comportamiento conservador: es mejor pedir un pegado manual que reemplazar texto de forma insegura.

## Permisos

### Accessibility

Es el permiso principal. Se usa para:

- leer selección
- detectar el campo enfocado
- intentar reemplazo directo
- mejorar el flujo universal del atajo global

Sin este permiso, la integración entre apps será mucho más limitada.

### Notificaciones

Es opcional, pero útil para saber:

- si la corrección terminó
- si hubo reemplazo directo
- si el resultado quedó en el portapapeles
- si falta algún permiso

## Limitaciones reales

Funciona mejor en apps que exponen sus controles de texto correctamente a macOS, por ejemplo:

- `TextEdit`
- `Notes`
- campos estándar en apps AppKit o SwiftUI

Puede fallar o degradar al portapapeles en:

- apps Electron
- editores web complejos
- campos enriquecidos personalizados
- apps que no exponen bien `Accessibility`

No existe una API universal en macOS que permita leer y escribir selección en absolutamente todas las apps. Por eso este proyecto combina:

- atajo global
- `Services`
- `Accessibility`
- fallback al portapapeles

## Configuración disponible

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

## Seguridad

- La API key se guarda en `Keychain`.
- La configuración no sensible se guarda en `UserDefaults`.
- El texto corregido puede pasar por el portapapeles cuando no hay reemplazo directo.
- La app no está firmada ni notarizada en esta versión.

## Stack

- Swift
- SwiftUI
- AppKit
- Accessibility API
- Carbon Hot Keys
- Keychain Services
- UserNotifications

## Resumen

Este repo entrega una versión funcional del corrector como utilidad nativa de macOS. No es una app distribuida oficialmente por Apple, pero sí una base usable para compilar localmente y trabajar con texto seleccionado en múltiples apps del sistema.
