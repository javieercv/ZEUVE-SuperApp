#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

SWIFT_JOBS="${ZEUVE_SWIFT_JOBS:-1}"

run_check() {
  local label="$1"
  local script="$2"
  echo "==> $label"
  python3 "$script"
}

swift test --jobs "$SWIFT_JOBS"
swift build -c release --jobs "$SWIFT_JOBS"

run_check "Integración de la aplicación" Scripts/verify/app_integration.py
run_check "Estructura del proyecto" Scripts/verify/project_structure.py
run_check "Motores y preparación" Scripts/verify/engines.py
run_check "Documentación y reglas permanentes" Scripts/verify/documentation.py
run_check "Regresiones de rendimiento" Scripts/verify/performance.py
run_check "Conversor universal" Scripts/verify/converter.py
run_check "Descargador universal" Scripts/verify/downloader.py
run_check "Analizador de chats" Scripts/verify/chat_analyzer.py
run_check "Comparador de seguidores de Instagram" Scripts/verify/instagram_followers.py
run_check "Inspector multimedia" Scripts/verify/multimedia_inspector.py
run_check "Limpiador" Scripts/verify/cleaner.py

bash -n \
  Scripts/verify_project.sh \
  Scripts/verify_app_macos.sh \
  Scripts/prepare_engines_macos.sh \
  Scripts/verify_engines_macos.sh \
  Scripts/sign_embedded_engines.sh \
  Scripts/verify_packaged_engines_macos.sh \
  Scripts/build_macos.sh \
  Scripts/run_youtube_integration_tests_macos.sh

python3 -m compileall -q Scripts Tests/ScriptTests
python3 -m unittest discover -s Tests/ScriptTests -p 'test_*.py' -v
python3 Scripts/validate_module_docs.py
run_check "Manifiestos" Scripts/verify/manifests.py
run_check "Parseo de ZEUVEApp" Scripts/verify/app_sources.py

python3 Scripts/generate_xcode_project.py
run_check "Coherencia SwiftPM/Xcode" Scripts/verify/xcode_integration.py
Scripts/verify_app_macos.sh
