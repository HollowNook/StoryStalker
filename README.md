# StoryStalker

StoryStalker is a cross-platform reading companion application built with Flutter.

The application is designed to allow users to track, organize, and manage their personal book library without requiring cloud accounts or third-party service dependencies.

The project is currently in early development, with the foundational architecture and initial UI implementation complete.

---

## Project Status

Version: Pre-v1 (Foundation Complete)

Completed:

* Flutter application scaffolding
* Cross-platform configuration (Android, iOS, Windows, macOS, Linux, Web)
* Book list UI
* Repository abstraction layer
* Initial application structure and navigation

In Progress:

* Local database integration (SQLite)
* Data persistence implementation

Planned:

* External book metadata API integration (optional autofill)
* Backup/export functionality
* Filtering and categorization
* Editing and book management workflows

---

## Objectives

The primary goals for this application are:

* Provide a local-first book tracking solution
* Avoid mandatory cloud dependency
* Maintain cross-platform compatibility
* Build a clean, maintainable architecture suitable for future expansion

The architecture has been intentionally structured to separate UI, business logic, and data layers to allow flexibility as features are added.

---

## Architecture Overview

The application currently follows a layered structure:

UI Layer
↓
Repository Layer
↓
Data Layer (to be implemented)

This ensures that UI components are not tightly coupled to storage mechanisms or external APIs.

Future integrations (such as SQLite or external metadata services) will plug into the repository layer without requiring UI refactors.

---

## Technology Stack

* Flutter
* Dart
* Planned: SQLite for local persistence
* Planned: External book metadata API (optional usage)

---

## Running the Project

Install dependencies:

```
flutter pub get
```

Run on connected device or platform:

```
flutter run
```

Build for a specific platform:

```
flutter build <platform>
```

Examples:

```
flutter build windows
flutter build android
flutter build web
```

---

## Scope of Version 1

The first milestone release will include:

* Add books manually
* View book list
* Store data locally
* Basic editing capabilities

No account system or cloud synchronization is planned for version 1.

---

## Future Direction

Future iterations may include:

* Metadata autofill via external APIs
* Manual backup and restore
* Advanced filtering and tagging
* Reading statistics and analytics
* Optional sync mechanisms

Development prioriti
