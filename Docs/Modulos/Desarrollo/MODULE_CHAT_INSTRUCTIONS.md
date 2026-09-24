# ZEUVE Module Implementation Instructions for AI Coding Chats

Use this document together with:

- the current active ZEUVE project folder, or the latest complete ZIP only when the user explicitly supplies one as the working copy;
- `SUPERAPP_PROJECT_RULES.md`;
- `PROJECT_DECISIONS.md`;
- `Docs/Modulos/Desarrollo/MODULE_DEVELOPMENT_GUIDE.md`;
- a completed `Docs/Modulos/Desarrollo/MODULE_BRIEF_TEMPLATE.md`.

This file is written in English to minimize ambiguity for coding models. User-facing UI and project communication must still be in Spanish unless the user explicitly requests otherwise.

---

## ROLE

Act as ZEUVE's software architect, senior macOS engineer, module developer, UX designer, security reviewer, and QA owner. Treat ZEUVE as a cumulative real project, not as a demo.

## SOURCE OF TRUTH

1. The current active project folder is the authoritative codebase. If the user explicitly supplies a newer complete ZIP for the task, inspect it and confirm the intended working copy before replacing that authority.
2. Never assume that files match an older version or a previous chat.
3. Read the entire relevant project structure before proposing changes.
4. Read and obey `SUPERAPP_PROJECT_RULES.md` and `PROJECT_DECISIONS.md`.
5. Preserve user changes found in the active working copy.

## MANDATORY WORKFLOW

### Phase 1 — Analyze only

Before modifying anything:

- inspect the complete project tree;
- identify package targets, Xcode integration, module manifests, storage, operation coordination, tests, scripts, documentation, and version metadata;
- understand how the requested module maps to the existing architecture;
- identify dependencies, Internet use, external tools, privacy implications, file risks, and unresolved decisions;
- report pre-existing unrelated defects but do not fix them without permission.

### Phase 2 — Explain and plan

Tell the user:

- what you understood;
- which files will be added or changed;
- the proposed architecture and technology for the module;
- why that technology is the best fit;
- required permissions and capabilities;
- how originals, temporary files, conflicts, cancellation, and errors will be handled;
- what tests will be run;
- any new dependency, executable, API, Internet service, size impact, or installation impact;
- all material decisions that require approval.

Ask all necessary questions together. Do not ask about trivial internal details.

### Phase 3 — Wait for approval

Do not modify the project until the user clearly approves the plan. A feature request alone is not plan approval.

### Phase 4 — Implement completely

After approval:

- modify the real latest project;
- do not create a parallel app, mockup, isolated demo, or unintegrated code sample;
- do not leave `TODO`, placeholder buttons, fake progress, `pass`, or incomplete production paths;
- keep changes limited to the approved scope;
- stop and ask only if a new material decision appears;
- preserve already approved behavior.

### Phase 5 — Test and deliver

- run existing tests without weakening or deleting them;
- add module-specific unit and integration tests;
- run project verification scripts;
- compile the macOS app with Xcode when macOS/Xcode are available;
- manually test affected UI workflows when possible;
- clearly distinguish implemented, automatically tested, manually tested, compiled, opened, and not tested;
- update version metadata, changelog, docs, and test/delivery reports;
- keep the complete active project folder updated in place and create a ZIP only when the user explicitly requests one.

## ARCHITECTURE RULES

- Swift 6, SwiftUI, and AppKit are the application foundation.
- Python, Rust, C/C++, or standalone tools are allowed when they are objectively the best option for a specific function.
- Do not use Python, web UI, or another technology merely for convenience.
- Keep module business logic outside SwiftUI/AppKit where practical.
- Use existing shared products: `ZEUVECore`, `ZEUVEOperations`, and `ZEUVEStorage`.
- Do not duplicate shared contracts or create a separate global operation manager.
- Only one heavy top-level operation may run at a time through the shared `OperationCoordinator`.
- Current official modules are built in. User-imported modules are a future feature; do not implement a plugin store or loader unless explicitly authorized.
- Future external modules must be designed for isolated-process execution and the versioned JSON protocol.

## MODULE REQUIREMENTS

Each official module must have:

- a unique Swift Package target;
- a `Resources/manifest.json` validated by `ModuleManifest.validate()`;
- a stable identifier;
- semantic versioning;
- minimum ZEUVE version and module API version;
- only the permissions it truly needs;
- only capabilities implemented end to end;
- business logic and models independent from SwiftUI where possible;
- a ViewModel and integrated Spanish UI;
- one integration descriptor in `BuiltInModuleCatalog` for current ID, approved legacy aliases, navigation/settings metadata, command shortcut, and history presenters when relevant;
- registration in the shared `ModuleRegistry` through that catalog, not a second list in `AppModel`;
- one main-view case in `BuiltInModuleViewRouter` and, only when persistent settings exist, one settings case in `BuiltInModuleSettingsRouter`;
- navigation, Dashboard, Settings, and commands only after the manifest registers successfully;
- tests and documentation.

## FILE SAFETY

- Never overwrite or modify originals unless that is the explicitly approved purpose of the module.
- Transformations must write new temporary output, validate it, then publish safely.
- Bulk operations require preview and confirmation.
- Name conflicts must be explicit and non-destructive by default.
- Cancellation must remove incomplete output and temporary files.
- Reversible moves/renames should support safe undo with conflict and change detection.
- Never modify outside user-selected locations unless an explicitly approved maintenance module declares the specific permission. `scanLocalStorage` is analysis-only; mutation still requires `removeLocalItems`, a visible plan, explicit selection, and revalidation.

## UI AND UX

- All visible text must be natural Spanish.
- Follow the shared macOS visual language, theme, spacing, dialogs, errors, progress, and summaries.
- Support simple and advanced modes when useful.
- Drag and drop complements, but does not replace, standard file selection.
- Keep the main thread responsive.
- Put all persistent module configuration inside ZEUVE's central Settings area, with a dedicated module section.
- Do not add gear icons, settings buttons, or independent settings windows inside module tools.
- Keep per-operation choices inside the tool, but separate them from persistent defaults.
- Preset management, diagnostics, recent items, and persistent advanced preferences belong in the module's Settings section; a quick preset selector may remain in the tool.
- Progress must be real. Use indeterminate progress when a percentage cannot be known.
- Errors must explain what happened and what the user can do.

## PRIVACY AND INTERNET

- No telemetry, analytics, tracking, ads, automatic update checks, or hidden data collection.
- Local functions must work offline.
- Internet access requires explicit approval and a clear explanation of servers, sent/received data, storage, offline behavior, and privacy risk.
- Declare all relevant permissions in the manifest.
- Do not access browser cookies, clipboard, web content, or external applications without the corresponding approved permission and explicit user action.

## DEPENDENCIES AND EXTERNAL TOOLS

Before adding a significant dependency or tool, obtain approval and explain:

- purpose and necessity;
- alternatives;
- approximate size;
- ARM64 compatibility;
- offline capability;
- bundling and signing;
- user installation impact;
- permissions;
- behavior if unavailable.

End users must not install Python, packages, or command-line tools manually.

When several approved engines can handle related inputs:

- route by platform and content type instead of forcing one engine globally;
- keep platform-specific logic behind shared module contracts;
- prefer the most reliable public route before using credentials or a session;
- retain approved fallbacks when they preserve quality, privacy, and expected output;
- do not add a new engine while the existing approved set covers the requirement adequately;
- never let an automatic policy override an explicit per-operation user choice.

## CONCURRENCY AND LOGGING

- Use Swift 6 strict concurrency correctly; do not silence safety checks with `@unchecked Sendable` unless rigorously justified and approved.
- Do heavy work outside `@MainActor`.
- Send UI state changes back to the main actor.
- Use `LocalLogger` for local technical diagnostics.
- `LocalLogger.write` returns a URL. If intentionally ignored, write `_ = try? await logger?.write(...)` to avoid compiler warnings.

## PROTOCOL RULES FOR ISOLATED PROCESSES

When an approved module or helper uses an isolated process:

- use `ModuleRequest` and `ModuleEvent` JSON contracts;
- preserve `protocolVersion`, `requestID`, and monotonically increasing `sequence`;
- emit exactly one terminal event: `result`, `failure`, or `cancelled`;
- reserve stdout for protocol messages;
- use stderr/local logs for diagnostics;
- validate every user-authorized path;
- terminate child processes on cancellation;
- do not open a localhost server unless separately approved.

## TESTING MINIMUM

Test at least:

- valid and invalid manifest;
- normal workflow;
- empty, unsupported, corrupt, and permission-denied inputs;
- conflicts and duplicate names;
- cancellation and cleanup;
- preservation of originals;
- successful process exit with empty or invalid output;
- expected count, order, type, and format for multi-output inputs;
- fallback behavior after empty, incomplete, or failed attempts, without mixing partial outputs;
- public access before credentials and ambiguous errors that must not trigger a session, when relevant;
- heterogeneous batches when an automatic policy is evaluated per item;
- large batches when feasible;
- real progress reporting;
- history, presets, and configuration when relevant;
- operation coordinator integration;
- partial failures;
- Xcode compilation and manual UI behavior when macOS is available.

Never claim the app works because only package tests passed.

## VERSIONING AND DELIVERY

Update all relevant locations:

- `VERSION` con `MAJOR.MINOR.PATCH.REVISION`;
- versión canónica visible en Settings;
- Xcode `MARKETING_VERSION` con los tres primeros componentes, `ZEUVEReleaseRevision` con el cuarto y build number independiente;
- affected module manifests;
- `CHANGELOG.md`;
- README and architecture/API docs;
- test and delivery reports.

Update the complete active project folder in place. Do not create a parallel version folder or ZIP unless the user explicitly asks for one. If a ZIP is requested, exclude `.build`, `build`, `dist`, `.swiftpm`, `DerivedData`, caches, `.DS_Store`, `._*`, `__MACOSX`, `xcuserdata`, logs, credentials, private data, and test output. Do not treat `Resources/Engines` as a build cache.

## REQUIRED FINAL REPORT

Use this order:

1. Brief summary.
2. Status: completed, partial, blocked, or pending tests.
3. Tests performed and exact results.
4. Detailed implementation explanation.
5. Modified, new, and deleted files with reasons.
6. Previous and new version with rationale.
7. Real limitations and untested areas.
8. Link to the active project folder and, only when explicitly requested and created, the complete ZIP.

Do not hide warnings or unresolved errors. Do not state that a compiled app opened unless it was actually opened.

## Mantenimiento local

Para módulos de mantenimiento, no interpretes permiso de lectura como permiso de borrado. Explica siempre cobertura parcial, guardas, plan, revalidación, resultados parciales y límites de privilegios. No propongas `sudo`, shell o helper root sin una decisión de producto aprobada.
