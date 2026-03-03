# Copilot Instructions for LED Matrix App

## Language & Localization

- All code (variable names, function names, class names, enums, etc.) **must be written in English**.
- All comments, documentation, and commit messages **must be in English**.
- UI-facing strings can be in French if intended for end-users.

## Comments Policy

- **Do not add comments** unless they are strictly necessary to explain a complex or non-obvious piece of logic.
- Never add decorative comment headers (e.g., `// ====`, `// 📁 file.dart`).
- Never add trivial comments that repeat what the code already expresses (e.g., `// Returns the value`).
- When a comment is needed, keep it concise and in English.

## Flutter & Dart Best Practices

### General

- Target the latest stable Flutter SDK (currently 3.x) and Dart 3.x features.
- Use `const` constructors wherever possible for widgets and values.
- Prefer `final` over `var` for local variables that are not reassigned.
- Use pattern matching and sealed classes when appropriate (Dart 3+).
- Use records and destructuring when they improve readability.
- Prefer expression bodies (`=>`) for simple one-line members.

### Widgets

- Prefer `StatelessWidget` over `StatefulWidget` when no mutable state is needed.
- Extract reusable UI into small, focused widget classes — avoid large `build()` methods.
- Always use `const` for widget constructors and children when possible.
- Use `super.key` in constructor parameters (e.g., `const MyWidget({super.key})`).
- Avoid deeply nested widget trees — extract helper widgets or methods.
- Use `SizedBox` instead of `Container` when only size constraints are needed.

### State Management

- Keep business logic out of widgets — delegate to services, models, or state management classes.
- Minimize `setState` scope: only rebuild what is necessary.

### Naming Conventions

- Classes: `UpperCamelCase` (e.g., `LedMatrix`, `BleService`).
- Files: `snake_case` (e.g., `ble_service.dart`, `led_matrix.dart`).
- Variables, functions, parameters: `lowerCamelCase`.
- Constants: `lowerCamelCase` (Dart convention, not `SCREAMING_SNAKE_CASE`).
- Private members: prefix with `_`.
- Boolean variables/getters: use prefixes like `is`, `has`, `should`, `can`.

### Imports

- Use relative imports for intra-package files (e.g., `import '../services/ble_service.dart';`).
- Group imports: Dart SDK → Flutter SDK → packages → relative imports, separated by blank lines.
- Remove unused imports.

## Project Architecture

This project follows a feature-layered structure under `lib/`:

```
lib/
├── main.dart          # Entry point (minimal, delegates to app.dart)
├── app.dart           # MaterialApp configuration
├── config/            # App-wide constants and configuration
├── models/            # Data models (plain Dart classes)
├── screens/           # Full-page widgets (one per screen)
├── services/          # Business logic, BLE, storage, rendering
├── utils/             # Pure utility functions and helpers
└── widgets/           # Reusable UI components
```

- **Do not mix concerns**: screens should not contain business logic; services should not contain UI code.
- New features should respect this folder structure. If a new layer is needed (e.g., `providers/`, `repositories/`), discuss it first.
- Keep `main.dart` minimal — only initialization and `runApp`.
- Keep `app.dart` focused on `MaterialApp` setup (theme, routes, navigation).

## ESP32 / Hardware Code

- The `esp32/` directory contains Arduino/C++ code for the LED matrix hardware.
- When modifying ESP32 code, follow Arduino C++ conventions.
- Keep BLE protocol definitions consistent between the Flutter app (`ble_service.dart`) and the ESP32 firmware.

## Code Quality

- Run `flutter analyze` before considering code complete — fix all warnings and errors.
- **Never use deprecated APIs.** Always use the recommended replacement:
  - `Color.withOpacity(x)` → `Color.withValues(alpha: x)`.
  - `Switch(activeColor: …)` → `Switch(activeThumbColor: …)`.
  - Check the Flutter/Dart deprecation notices and migrate proactively.
- Prefer strong typing over `dynamic`. Avoid `dynamic` unless interfacing with untyped APIs.
- Handle errors gracefully: use `try/catch` for I/O, network, and BLE operations.
- Use `async/await` instead of raw `Future.then()` chains.
- Avoid `print()` in production code — use a proper logging mechanism or `debugPrint()`.

## Formatting

- Follow `dart format` standards (line length 80 by default).
- Use trailing commas for multi-argument widget constructors and function calls to get better formatting.
