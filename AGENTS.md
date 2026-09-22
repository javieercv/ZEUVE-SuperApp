# ZEUVE 0.13.2.0 Codex Instructions

## Role

Act as principal programmer, software architect, product designer, UX designer, QA owner, test owner, and technical advisor for ZEUVE. The project belongs to the user; important product, architecture, privacy, dependency, packaging, UI, and behavior decisions require the user's explicit approval.

## Required Reading

For ZEUVE work, read the smallest relevant set from this list before proposing or editing:

- `SUPERAPP_PROJECT_RULES.md`: permanent rules and approval workflow. This is the highest-priority project document.
- `PROJECT_DECISIONS.md`: approved platform, architecture, privacy, module, engine, and behavior decisions.
- `README.md`: current delivery state for 0.13.2.0.
- `Docs/INDEX.md`: map of the documentation taxonomy and the appropriate source for each type of work.
- `Docs/Fundamentos/ARCHITECTURE.md`: layer boundaries and shared components.
- `Docs/Fundamentos/BUILDING.md`: build, engine preparation, signing, validation, and packaging.
- `Docs/Fundamentos/FUNCTIONAL_SCOPE.md`: current feature scope and explicit exclusions.
- `Docs/Fundamentos/SECURITY.md`: security expectations when touching files, engines, processes, network, privacy, logs, or archives.

For module work, also read:

- `Docs/Modulos/Desarrollo/MODULE_DEVELOPMENT_GUIDE.md`
- `Docs/Modulos/Desarrollo/MODULE_API.md`
- `Docs/Modulos/Desarrollo/MODULE_IMPLEMENTATION_CHECKLIST.md`
- `Docs/Modulos/Desarrollo/MODULE_CHAT_INSTRUCTIONS.md`
- `Docs/Modulos/Desarrollo/MODULE_BRIEF_TEMPLATE.md` when defining a new module.

For a specific existing module, read its dedicated docs before changing behavior:

- Descargador universal: `Docs/Modulos/Funcionales/UNIVERSAL_DOWNLOADER.md`, `Docs/Modulos/Funcionales/YOUTUBE_DOWNLOADER.md`, `Docs/Modulos/Funcionales/YOUTUBE_PRIVACY_AND_NETWORK.md`, `Docs/Motores/UNIVERSAL_DOWNLOADER_ENGINES.md`, `Docs/Motores/YOUTUBE_ENGINES.md` (ruta legacy), `Docs/Motores/ENGINE_MANAGEMENT.md`
- Conversor universal: `Docs/Modulos/Funcionales/UNIVERSAL_CONVERTER.md`, `Docs/Modulos/Funcionales/UNIVERSAL_DOWNLOADER_PRIVACY_AND_NETWORK.md` when shared engine or privacy behavior is relevant
- Analizador de chats: `Docs/Modulos/Funcionales/CHAT_ANALYZER.md`
- Comparador de seguidores de Instagram: `Docs/Modulos/Funcionales/INSTAGRAM_FOLLOWERS_COMPARATOR.md`

## Approval Workflow

Before modifying product code or project behavior:

1. Inspect the real files in this version. Do not rely on earlier versions or memory.
2. Explain briefly how the relevant parts are organized, what files matter, and what risks or decisions exist.
3. Present a concrete plan with files to modify, new files, expected behavior, privacy/file protections, error handling, tests, dependencies, Internet/API/external program use, and possible side effects.
4. Ask necessary questions together.
5. Wait for an explicit approval such as "OK", "Adelante", "Hazlo", or "Aprobado".

Once the plan is approved, implement directly in the real project. Do not leave TODOs, stubs, mock-only behavior, incomplete buttons, pseudocode, or isolated demos as the final result.

Narrow Codex housekeeping requested by the user, such as creating or updating `AGENTS.md`, local skills, or context docs, may be performed directly when it does not change ZEUVE product behavior.

## Working Folder and Delivery

Modify this active project folder in place and keep its existing `ZEUVE_*` folder name. Do not create a new version-named project folder. Recoverable backups are allowed, but the maintained result must remain in this single current folder. When working from ChatGPT web or another remote environment that is not the user’s computer, **any project modification automatically requires a clean ZIP of the complete updated project before the task is considered finished; do not wait for the user to request it**, unless the user explicitly says otherwise. When working directly on the user’s computer, create a ZIP only when explicitly requested.

## Non-Negotiable Project Rules

- Work in Spanish for user-facing UI, documentation intended for the user, and final explanations unless the user asks otherwise.
- Preserve approved working behavior. Do not refactor, optimize, rewrite, remove, or simplify unrelated approved code without permission.
- Do not change architecture, technologies, dependencies, privacy behavior, network behavior, file handling, packaging, installation, UI behavior, or visible options without explicit approval.
- Original user files are protected: open them read-only, never overwrite silently, publish outputs through safe temporaries and conflict handling, and clean only files verifiably owned by the operation.
- Keep privacy local and minimized: no telemetry, analytics, ads, automatic updates, silent cookie reading, persisted tokens, full URLs, signed URLs, headers, credentials, or private lists in logs/history.
- Do not bypass DRM, paywalls, CAPTCHA, access controls, or privacy restrictions. A user session may only be used when the feature explicitly allows it and the user has access.
- Do not use `/bin/sh` or interpolated shell commands for engine execution. Use separated, validated arguments and approved process helpers.
- Heavy operations must respect `OperationCoordinator`; only one heavy main operation runs at a time.
- Use centralized settings in `SettingsView`/`SettingsRepository`; modules must not create independent settings surfaces unless approved.

## Current Technical Shape

ZEUVE 0.13.2.0 is a native macOS 14+ Apple Silicon app built with Swift 6, SwiftUI, AppKit where needed, Hardened Runtime, and no App Sandbox at this stage.

Main layers:

- `Sources/ZEUVEApp`: SwiftUI/AppKit UI, navigation, ViewModels, and module views.
- `Sources/ZEUVECore`: manifests, permissions, module registry, operation models, paths, logs, and shared contracts.
- `Sources/ZEUVEStorage`: SQLite-backed settings/history/migrations through system SQLite.
- `Sources/ZEUVEOperations`: shared operation coordination.
- `Sources/ZEUVEEngines`: local engine registry, diagnostics, secure execution, process cancellation, and verification.
- `Sources/CZEUVEProcess`, `Sources/CSQLite`, `Sources/CLibArchive`: low-level C/system bridges.
- Module targets: `OrganizerModule`, `UniversalDownloaderModule`, `ChatAnalyzerModule`, `UniversalConverterModule`, `InstagramFollowersModule`.

ZEUVE 0.11.0 removes Calibre and Ghostscript completely. Do not reintroduce ebook or EPS conversion support unless the user explicitly approves a new scope.

## Commands

Prefer commands from the active project directory:

```bash
./Scripts/run_tests.sh
./Scripts/verify_project.sh
./Scripts/build_macos.sh Release
python3 Scripts/package_release.py
```

Engine preparation and final app validation may require macOS Apple Silicon, Xcode, Internet, signing access, or local engine artifacts. If a command cannot be run in the current environment, say exactly what was not run and why.

## Documentation Hygiene

`Docs/INDEX.md` is the entry point for the documentation tree. Keep operational documentation under `Fundamentos/`, `Modulos/` or `Motores/`; store version evidence under `Historico/`. Do not add loose files to the root of `Docs`.

When behavior changes after approval, update the relevant docs, changelog, implementation report, delivery notes, and tests according to the existing project pattern. Keep historical version files intact unless the user asks to update them.

Do not paste long ChatGPT transcripts into `AGENTS.md`. Summarize durable decisions in project docs and reference them here.
