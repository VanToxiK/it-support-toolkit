# IT Support Toolkit

Herramienta en PowerShell para técnicos de soporte N1 en Windows: reúne en
un único menú interactivo las tareas de diagnóstico más habituales (información
del sistema, estado de red, limpieza, servicios, inventario de software e
informes), pensada como proyecto de portfolio.

## Requisitos

- Windows 10 u 11.
- Windows PowerShell 5.1 (el que viene instalado por defecto). No requiere
  PowerShell 7 ni módulos externos.

## Cómo ejecutarlo

Doble clic en `Iniciar.bat`. El lanzador ejecuta el script con
`-ExecutionPolicy Bypass` solo para esa ejecución, sin modificar la
configuración de PowerShell del sistema.

## Estructura

```
Iniciar.bat              Lanzador
src/
  ITSupportToolkit.ps1    Menú principal
  modules/
    Logging.psm1          Registro de acciones en log
    SystemInfo.psm1        Opción 1: información del sistema
    Network.psm1            Opción 2: diagnóstico de red
docs/                     Capturas y documentación
PROJECT_SPEC.md            Alcance completo del proyecto
```

## Estado

- **Fase 1 (completa)**: estructura base, logging, información del sistema
  y diagnóstico de red.
- **Fase 2 (pendiente)**: reparación básica de red y limpieza de temporales.
- **Fase 3 (pendiente)**: estado de servicios, inventario de programas
  instalados e informe HTML.

Ver `PROJECT_SPEC.md` para el detalle completo del alcance.

## Seguridad

Todas las acciones son de solo lectura por defecto. Cualquier acción que
vaya a modificar el sistema pedirá confirmación explícita antes de
ejecutarse.

## Licencia

MIT. Ver [LICENSE](LICENSE).

## Autor

Ivan Marcos Couso
