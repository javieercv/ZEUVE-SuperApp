# Plantilla de definición de módulo

Completa este documento antes de pedir la implementación de un módulo.

## Identificación

**Nombre visible:**  
**Nombre técnico provisional:**  
**Objetivo principal:**  
**Problema que resuelve:**  
**Usuarios o situaciones de uso:**

## Alcance funcional

**Funciones obligatorias:**

- 

**Funciones deseables pero no obligatorias:**

- 

**Funciones expresamente fuera de alcance:**

- 

## Entradas y salidas

**Entradas admitidas:**  
**Salidas generadas:**  
**¿Acepta archivos, carpetas, URLs o texto?:**  
**¿Procesamiento individual o por lotes?:**  
**Carpeta de salida esperada:**  
**Nombres de resultados:**

## Modos de uso

**Modo simple:**  
**Modo avanzado:**  
**Valores predeterminados seguros:**

## Archivos y seguridad

**¿Modifica originales?:**  
**Vista previa necesaria:**  
**Política de conflictos:**  
**Temporales:**  
**Cancelación:**  
**Deshacer:**  
**Metadatos que deben conservarse:**

## Tecnología

**Tecnología propuesta:**  
**Motivo:**  
**Alternativas consideradas:**  
**Motores o dependencias externas:**  
**Tamaño aproximado:**  
**Compatibilidad Apple Silicon:**

## Internet y privacidad

**¿Necesita Internet?:**  
**Servidores o dominios:**  
**Datos enviados:**  
**Datos recibidos:**  
**Datos almacenados:**  
**Comportamiento sin conexión:**  
**Cookies, navegador, portapapeles o apps externas:**

## Permisos previstos

Marca los necesarios:

- [ ] Leer archivos elegidos por el usuario.
- [ ] Escribir en carpeta elegida.
- [ ] Mantener acceso persistente a carpetas.
- [ ] Acceder a Internet.
- [ ] Ejecutar herramientas incluidas.
- [ ] Mostrar contenido web.
- [ ] Acceder a cookies del navegador.
- [ ] Acceder al portapapeles.
- [ ] Abrir aplicaciones externas.

## Capacidades previstas

- [ ] Vista previa.
- [ ] Progreso.
- [ ] Cancelación.
- [ ] Historial.
- [ ] Presets.
- [ ] Favoritas.
- [ ] Deshacer.
- [ ] Arrastrar y soltar.
- [ ] Diagnóstico.

## Interfaz

**Pantalla principal del módulo:**  
**Flujo de pasos:**  
**Filtros o búsqueda:**  
**Resumen final:**  
**Acciones rápidas:**  
**Consideraciones de accesibilidad:**

## Errores y casos límite

**Entradas dañadas:**  
**Falta de permisos:**  
**Espacio insuficiente:**  
**Interrupción o cierre:**  
**Errores parciales en lotes:**  
**Otros casos límite:**

## Persistencia

**Ajustes a recordar:**  
**Historial:**  
**Presets:**  
**Favoritas:**  
**Información que no debe almacenarse:**

## Pruebas de aceptación

1. 
2. 
3. 

## Decisiones pendientes para aprobación

- 

### Mantenimiento local

Si el módulo inspecciona almacenamiento fuera de selecciones puntuales, documenta por separado: ubicaciones de scan, permiso `scanLocalStorage`, condiciones de `removeLocalItems`, guardas, revalidación, tratamiento de symlinks, datos persistentes, privilegios y estrategia de Undo.
