# Informe de implementación — ZEUVE 0.20.4.0

Limpiador 0.1.2 corrige seis causas detectadas al completar la revisión de 0.20.3.0, sin cambiar permisos, red, motores, dependencias ni esquema SQLite.

| Fallo reproducido | Causa | Corrección | Regresión |
|---|---|---|---|
| Un residuo con Bundle ID ajeno que empezaba por el ID de una app recibía asociación fuerte | `hasPrefix` | Coincidencia exacta de nombre/Bundle ID | `testBundleIDPrefixDoesNotCreateStrongAssociation` |
| Un instalador aparecía dos veces con raíces solapadas | Recorrido independiente de cada raíz | Deduplicación por ruta normalizada | `testOverlappingInstallerRootsDoNotDuplicateCandidates` |
| La desinstalación de una app sin Bundle ID podía incorporar datos de otra app también sin ID | Igualdad `nil == nil` | Filtrado por mismo nombre cuando faltan ambos ID | `testUnsignedUninstallDoesNotIncludeOtherUnsignedApplicationData` |
| «Conservar» dejaba el candidato seleccionable hasta reanalizar | Solo se desmarcaba y la ejecución confiaba en el plan anterior | Estado `keptByUser` inmediato y consulta SQLite justo antes de retirar | `testConserveImmediatelyRemovesSelectionAndBlocksReselection`, `testLateConserveDecisionSkipsPreviouslySelectedCandidate` |
| Un fallo de registro tras mover a Papelera podía figurar como fallo de retirada; un fallo de historial global ocultaba un movimiento ya hecho | Mutación y persistencia en un mismo `catch` | Rollback seguro si falla Undo; resultado real y aviso si no se puede; historial global no invalida el resultado de archivos | `testUndoRegistrationFailureRollsTrashMoveBack`, `testHistoryFailureDoesNotHideCompletedTrashMoveOrUndo` |
| Deshacer parcial perdía acceso a pendientes | UI borraba ID tras restaurar cualquier elemento | Consulta de pendientes; se conserva ID hasta completar | `testPartialUndoKeepsRemainingItemAvailableForRetry` |
| Un filtro de Espacio sin resultados mostraba texto de carpeta sin analizar | Mismo estado vacío para ambos casos | Mensaje específico de tamaño mínimo o de carpeta inaccesible | Observación UI de 100 MB sobre fixture de 1 KB |

Se añadió además `testPermanentRemovalAffectsOnlySelectedDisposableFixture`: borra solo el temporal seleccionado y comprueba que otro temporal sigue intacto. La prueba real de Papelera/Deshacer y las guardas de cambio posterior siguen vigentes.

La vista **Resumen** del análisis general no pudo recorrerse: el servicio de accesibilidad perdió la conexión al leerla, mientras ZEUVE seguía activo. Un filtro previo en **Aplicaciones** permitió revisar visualmente la app de QA, su plan, la confirmación, Papelera en Finder, Deshacer y el análisis posterior. No se interpreta el fallo de automatización como validación de Resumen ni de los casos de interfaz no recorridos.
