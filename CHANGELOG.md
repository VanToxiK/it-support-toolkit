# Changelog

Todos los cambios relevantes de este proyecto se documentan en este archivo.

## [1.0.0] - 2026-09-28

### Añadido

- Estructura base del proyecto, lanzadores (`Iniciar.bat` e `Iniciar como
  administrador.bat`) y módulo de logging (`Write-ITLog`) en
  `%LOCALAPPDATA%\ITSupportToolkit\logs`.
- Opción 1 — Información del sistema: hostname, sistema operativo, CPU, RAM,
  discos (con aviso si queda menos del 15 % libre) y tiempo de actividad.
- Opción 2 — Diagnóstico de red: adaptadores activos, puerta de enlace,
  servidores DNS, pruebas de ping/DNS/Internet y conclusión en lenguaje claro.
- Opción 3 — Reparación básica de red: vaciar caché DNS, renovar IP (DHCP)
  del adaptador principal `[ADMIN]` y reiniciar dicho adaptador `[ADMIN]`.
- Opción 4 — Limpieza de temporales del usuario (`%TEMP%`), respetando
  archivos en uso y sin seguir enlaces simbólicos ni junctions.
- Opción 5 — Estado de servicios clave (Cola de impresión, Windows Update,
  Cliente DNS, Cliente DHCP, Audio), con reinicio y vaciado de la cola de
  impresión `[ADMIN]`.
- Opción 6 — Listado de programas instalados (lectura del registro) con
  exportación a CSV.
- Opción 7 — Informe HTML autónomo (CSS incrustado, sin JavaScript, datos
  escapados), con opción de anonimizar hostname, IPs, puerta de enlace, DNS
  y nombres de adaptador antes de guardarlo en
  `Documentos\IT Support Toolkit Reports`.
- Versión de la herramienta centralizada en `Get-ITToolkitVersion`
  (`Common.psm1`), mostrada en el menú principal y en el informe HTML.
- Documentación: `README.md` completo, `docs/pruebas.md` con el plan de
  pruebas manuales y las incidencias detectadas durante el desarrollo.

### Corregido

- Reinicio del adaptador de red principal (Opción 3): `Disable-NetAdapter` y
  `Enable-NetAdapter` no admiten el parámetro `-InterfaceIndex` (solo
  `-Name`, `-InterfaceDescription` o `-InputObject`); se corrigió
  identificando el adaptador con `-InputObject` a partir del objeto
  devuelto por `Get-NetAdapter`. Ver `docs/pruebas.md`.
