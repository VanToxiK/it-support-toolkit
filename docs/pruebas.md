# Pruebas manuales — IT Support Toolkit v1.0.0

- **Fecha de las pruebas**: 28/09/2026
- **Versión probada**: 1.0.0
- **Entorno de prueba**: Windows 10, red con IP fija, ejecutado tanto en
  modo usuario como en modo administrador (sin datos identificativos del
  equipo utilizado).

Tabla de pruebas manuales para las 7 opciones del menú. "Resultado obtenido"
y "OK/FALLO" se rellenan al ejecutar cada prueba sobre un equipo real.

| ID | Opción | Modo | Pasos | Resultado esperado | Resultado obtenido | OK/FALLO |
|----|--------|------|-------|---------------------|---------------------|----------|
| P01 | 1. Información del sistema | Usuario | Elegir la opción 1 en el menú principal. | Se muestran hostname, SO, CPU, RAM y discos; los discos con menos del 15 % libre aparecen resaltados y con aviso. Si algún dato no se puede leer, aparece "No disponible" y el resto se muestra igual. | Conforme a lo esperado | OK |
| P02 | 2. Diagnóstico de red | Usuario | Elegir la opción 2 en el menú principal. | Se muestran adaptadores activos, puerta de enlace, DNS, el resultado de las 3 pruebas (ping/DNS/Internet) y una conclusión en castellano coherente con esos resultados. | Conforme a lo esperado | OK |
| P03 | 3. Reparación de red — vaciar caché DNS | Usuario | Opción 3 → 1, confirmar con "S". | Se vacía la caché DNS y se muestra el mensaje de éxito. | Conforme a lo esperado | OK |
| P04 | 3. Reparación de red — vaciar caché DNS (cancelar) | Usuario | Opción 3 → 1, responder "N" a la confirmación. | No se ejecuta ninguna acción; se registra en el log que el usuario canceló. | Conforme a lo esperado | OK |
| P05 | 3. Reparación de red — renovar IP (DHCP) | Administrador | Opción 3 → 2, confirmar con "S". | Se libera y renueva la IP del adaptador principal; se informa del resultado (éxito, IP fija, o error). | Conforme a lo esperado | OK |
| P06 | 3. Reparación de red — renovar IP (DHCP) sin permisos | Usuario | Opción 3 → 2, sin ejecutar como administrador. | Se explica que la acción necesita permisos de administrador y cómo relanzar el programa; no se ejecuta nada. | Conforme a lo esperado | OK |
| P07 | 3. Reparación de red — reiniciar adaptador principal | Administrador | Opción 3 → 3, confirmar con "S". | El adaptador se desactiva y se reactiva; tras esperar hasta 20 segundos, se informa si ha quedado "Up", sin enlace o desactivado. | Conforme a lo esperado | OK |
| P08 | 4. Limpieza de temporales | Usuario | Opción 4, confirmar con "S" cuando haya archivos antiguos. | Se muestran archivos encontrados y espacio ocupado antes de borrar, y borrados/omitidos/espacio liberado después. Los archivos en uso se omiten sin detener el proceso. | Conforme a lo esperado | OK |
| P09 | 4. Limpieza de temporales (sin archivos) | Usuario | Opción 4 en un equipo sin archivos temporales de más de 24 h. | Se informa de que no hay archivos antiguos que borrar y no se pide confirmación. | Conforme a lo esperado | OK |
| P10 | 5. Estado de servicios clave | Usuario | Opción 5. | Se muestra el estado (en ejecución/detenido) y tipo de inicio de los 5 servicios clave. | Conforme a lo esperado | OK |
| P11 | 5. Reiniciar cola de impresión | Administrador | Opción 5 → 1, confirmar con "S". | La cola de impresión se reinicia y se confirma el éxito. | Conforme a lo esperado | OK |
| P12 | 5. Reiniciar cola de impresión sin permisos | Usuario | Opción 5 → 1, sin ejecutar como administrador. | Se explica que la acción necesita permisos de administrador; no se ejecuta nada. | Conforme a lo esperado | OK |
| P13 | 5. Vaciar cola de impresión atascada | Administrador | Opción 5 → 2, confirmar con "S". | Se detiene el servicio, se borran los trabajos pendientes (contando borrados/omitidos) y se reinicia el servicio siempre, incluso si el borrado falla. | Conforme a lo esperado | OK |
| P14 | 6. Programas instalados | Usuario | Opción 6. | Se muestra el listado completo (nombre, versión, editor, fecha) y el total de programas encontrados. | Conforme a lo esperado | OK |
| P15 | 6. Exportar a CSV | Usuario | Opción 6, confirmar "S" al ofrecer exportar. | Se crea un CSV en `Documentos\IT Support Toolkit Reports\ProgramasInstalados_<fecha>.csv` y se muestra la ruta. | Conforme a lo esperado | OK |
| P16 | 7. Informe HTML (normal) | Usuario | Opción 7, responder "N" a la pregunta de anonimizar. | Se genera `informe-AAAAMMDD-HHMMSS.html` en `Documentos\IT Support Toolkit Reports` con el hostname y las IPs reales del equipo, discos con aviso si aplica, red con su conclusión, servicios y número de programas instalados. | Conforme a lo esperado | OK |
| P17 | 7. Informe HTML (anonimizado) | Usuario | Opción 7, responder "S" a la pregunta de anonimizar. | El informe generado muestra "EQUIPO-01" como hostname, "192.168.x.x" en las IPs, puerta de enlace y DNS, y "Adaptador de red 1/2/…" en vez de los nombres reales. | Conforme a lo esperado | OK |
| P18 | 7. Informe HTML — abrir tras generarlo | Usuario | Opción 7, al finalizar responder "S" a "¿Quieres abrir el informe ahora?". | El informe se abre en el navegador predeterminado y se ve correctamente formateado (cabecera, tablas, colores de aviso). | Conforme a lo esperado | OK |
| P19 | 0. Salir | Usuario | Elegir la opción 0 en el menú principal. | El programa muestra "Hasta pronto." y termina sin errores. | Conforme a lo esperado | OK |

## Incidencias encontradas

### Reinicio del adaptador de red principal fallaba con "-InterfaceIndex" no válido

- **Dónde**: función `Restart-ITMainAdapter` en `src/modules/Network.psm1`
  (Opción 3 → 3, "Reiniciar adaptador de red principal").
- **Síntoma**: al intentar desactivar y reactivar el adaptador identificándolo
  por `-InterfaceIndex`, tanto `Disable-NetAdapter` como `Enable-NetAdapter`
  fallaban siempre con un error de "parámetro no reconocido".
- **Causa**: `Disable-NetAdapter` y `Enable-NetAdapter` no tienen ningún
  parámetro `-InterfaceIndex`; solo aceptan `-Name`, `-InterfaceDescription`
  o `-InputObject`.
- **Corrección**: se obtiene primero el objeto completo del adaptador con
  `Get-NetAdapter -InterfaceIndex $interfaceIndex` y se pasa ese objeto con
  `-InputObject` a ambos cmdlets. Además, se usa `try/finally` para
  garantizar que siempre se intenta reactivar el adaptador aunque la
  desactivación falle, y se espera hasta 20 segundos comprobando el estado
  antes de dar el reinicio por bueno o por fallido.
