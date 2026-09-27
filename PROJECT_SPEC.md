# IT Support Toolkit — Especificación del proyecto

Herramienta en PowerShell 5.1 para técnicos de soporte N1 en Windows 10/11.
Sin PowerShell 7 ni módulos externos. Menú interactivo en castellano.

## Reglas generales

- Windows 10/11, Windows PowerShell 5.1 (el que viene con Windows).
- Menú interactivo en castellano. Código, nombres de funciones y variables
  en inglés; comentarios en castellano.
- Los `.ps1`/`.psm1` se guardan en UTF-8 con BOM para que los acentos se
  vean bien en PowerShell 5.1.
- `Iniciar.bat` ejecuta el script con `-ExecutionPolicy Bypass` solo para
  esa ejecución, sin tocar la configuración del sistema.
- Seguridad: todo es de solo lectura por defecto. Cualquier acción que
  modifique algo pide confirmación explícita (S/N). Las acciones que
  necesitan permisos de administrador se marcan `[ADMIN]`; si no hay
  permisos, se explica y se salta. Nunca se ejecutan comandos construidos
  con texto introducido por el usuario.
- Log de acciones en `%LOCALAPPDATA%\ITSupportToolkit\logs`, con fecha y hora.

## Alcance completo v1 (3 fases)

1. **Información del sistema** — hostname, edición y versión de Windows,
   CPU, RAM total/usada, discos (espacio libre y % con aviso si <15 %),
   tiempo desde el último arranque.
2. **Diagnóstico de red** — adaptadores activos, IPv4, puerta de enlace,
   servidores DNS; prueba de ping a la puerta de enlace, resolución DNS y
   conexión a Internet (puerto 443). Conclusión en lenguaje claro.
3. **Reparación básica de red** — vaciar caché DNS; liberar y renovar IP
   (avisando del corte de conexión).
4. **Limpieza de temporales del usuario** (`%TEMP%`) — tamaño antes,
   confirmación, omitir archivos en uso, espacio liberado.
5. **Estado de servicios clave** — Cola de impresión (Spooler), Windows
   Update, Cliente DNS, DHCP, Audio. Opción `[ADMIN]` de reiniciar la cola
   de impresión.
6. **Programas instalados** — listado desde el registro (solo lectura),
   exportable a CSV.
7. **Informe HTML autónomo** — CSS incrustado, sin JavaScript, datos
   escapados, en `Documentos\IT Support Toolkit Reports`.

### Fuera de alcance v1

Cambios en el registro, desinstalar programas, reparaciones del sistema
(SFC/DISM), acceso remoto a otros equipos, conexiones a Internet salvo las
pruebas declaradas en el punto 2.

## Estado

- [x] **Fase 1** — Estructura base, logging, opciones 1 y 2 del menú.
- [x] **Fase 2** — Opciones 3 y 4 (reparación de red y limpieza de temporales).
- [x] **Fase 3 (parcial)** — Opciones 5 y 6 (servicios clave y programas instalados).
- [ ] **Fase 3 (pendiente)** — Opción 7 (informe HTML).
