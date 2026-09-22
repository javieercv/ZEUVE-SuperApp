#!/usr/bin/env python3
from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)

# Regresiones de rendimiento de ZEUVE 0.7.4.
from pathlib import Path
checks = {
    'Sources/ZEUVECore/LatestValueCoalescer.swift': ['generation', 'deliveryLock', 'minimumIntervalNanoseconds'],
    'Sources/ChatAnalyzerModule/Analysis/ChatStoreAnalytics.swift': ['ChatStoreAnalytics', 'forEachBatch', 'searchResult', 'ConversationScratch', 'FrequencyScratch'],
    'Sources/ChatAnalyzerModule/Storage/ChatAnalyzerStorage.swift': ['executeBatch'],
    'Sources/ZEUVEStorage/StorageMigrations.swift': ['history_created'],
    'Sources/ZEUVEApp/AppModel.swift': ['sharedEngineRegistry', 'sharedEngineDiagnostics'],
    'Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerViewModel.swift': ['ChatStoreCoreAnalyticsSnapshot', 'ChatStoreAnalytics.coreSnapshot', 'ChatStoreAnalytics.searchResult'],
    'Sources/ZEUVEApp/UniversalConverter/UniversalConverterViewModel.swift': ['inputScanner', 'engineDiagnostics: EngineDiagnosticService?'],
}
for filename, snippets in checks.items():
    text = Path(filename).read_text()
    missing = [value for value in snippets if value not in text]
    if missing:
        raise SystemExit(f'Regresión de rendimiento en {filename}: {missing}')
service = Path('Sources/ChatAnalyzerModule/ChatAnalyzerService.swift').read_text()
if '_ = ChatAnalytics.summary(all: messages, included: messages)' in service:
    raise SystemExit('Se ha recuperado el cálculo descartado del resumen del Analizador.')

# Regresión 0.12.4: la sesión real del Analizador no puede volver a materializar el chat completo.
view_model = Path('Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerViewModel.swift').read_text()
service = Path('Sources/ChatAnalyzerModule/ChatAnalyzerService.swift').read_text()
storage = Path('Sources/ChatAnalyzerModule/Storage/ChatAnalyzerStorage.swift').read_text()
for forbidden in ['result.messages', 'coreSnapshot.messages', 'coreSnapshot.filteredMessages', 'store.allMessages(', 'searchTextCache']:
    if forbidden in view_model + service:
        raise SystemExit('El Analizador vuelve a materializar mensajes completos en la sesión real: ' + forbidden)
for required in ['append(messages:', 'prepareTimeline()', 'forEachBatch(', 'forEachIndexedBatch(', 'messages(offset:']:
    if required not in storage + service:
        raise SystemExit('Falta almacenamiento/paginación incremental del Analizador 0.12.4: ' + required)
