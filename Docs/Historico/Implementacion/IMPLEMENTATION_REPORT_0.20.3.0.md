# Informe de implementación — ZEUVE 0.20.3.0

## Alcance

Limpiador 0.1.1 corrige los problemas observados en el primer recorrido de QA del inventario y de una desinstalación con una `.app` y residuos de prueba. La corrección se limita al módulo y su interfaz.

## Análisis y cobertura

El inventario y las mediciones de tamaño atienden la cancelación de `OperationCoordinator`. La lectura de tamaños utiliza propiedades de archivo obtenidas durante la enumeración. Spotlight se inicia en el hilo principal con salida única por fin de búsqueda, indisponibilidad, cancelación o límite de 30 segundos. Una búsqueda incompleta produce cobertura parcial y un aviso visible.

Solo un inventario completo puede actualizar aplicaciones históricas como ausentes. Durante un análisis parcial, las aplicaciones históricas no confirmadas como desaparecidas permanecen protegidas al clasificar sus datos asociados. No se añade telemetría ni se guardan rutas privadas en el historial global.

## Selección y ejecución

Limpieza muestra todos los candidatos del plan, incluidos los datos persistentes sin selección automática. En desinstalación, la selección segura conserva la `.app` elegida y solo incorpora elementos asociados regenerables; desmarcar la app desmarca sus asociados. La guarda de ejecución que impide limpiar esos datos si la app no se retira sigue activa.

La hoja de confirmación enumera rutas, cantidad, tamaño, riesgo y modo. El resultado conserva detalle por elemento. Después de ejecutar se renueva el análisis y se deja vacía la selección; `Deshacer` solo se ofrece cuando hubo movimientos recuperables a Papelera.

No se añaden dependencias, motores, red, permisos, cambios de almacenamiento ni borrados automáticos.
