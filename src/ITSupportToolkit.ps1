# ITSupportToolkit.ps1
# Punto de entrada del programa: muestra el menu principal y llama a las
# funciones de cada modulo segun la opcion elegida por el usuario.
# La entrada del usuario solo se usa para elegir una rama del switch,
# nunca para construir comandos.

$modulesPath = Join-Path -Path $PSScriptRoot -ChildPath 'modules'

Import-Module (Join-Path $modulesPath 'Logging.psm1') -Force
Import-Module (Join-Path $modulesPath 'Common.psm1') -Force
Import-Module (Join-Path $modulesPath 'SystemInfo.psm1') -Force
Import-Module (Join-Path $modulesPath 'Network.psm1') -Force
Import-Module (Join-Path $modulesPath 'Cleanup.psm1') -Force
Import-Module (Join-Path $modulesPath 'Services.psm1') -Force
Import-Module (Join-Path $modulesPath 'Software.psm1') -Force
Import-Module (Join-Path $modulesPath 'Report.psm1') -Force

# El modo (usuario/administrador) se calcula una sola vez al arrancar.
$script:isAdminMode = Test-ITIsAdmin

function Show-ITMenu {
    Clear-Host
    Write-Host '======================================' -ForegroundColor Cyan
    Write-Host '        IT SUPPORT TOOLKIT' -ForegroundColor Cyan
    Write-Host ('              v{0}' -f (Get-ITToolkitVersion)) -ForegroundColor Cyan
    Write-Host '======================================' -ForegroundColor Cyan

    if ($script:isAdminMode) {
        Write-Host '        Modo: Administrador' -ForegroundColor Green
    }
    else {
        Write-Host '        Modo: Usuario' -ForegroundColor Yellow
    }

    Write-Host ''
    Write-Host ' 1. Información del sistema'
    Write-Host ' 2. Diagnóstico de red'
    Write-Host ' 3. Reparación básica de red'
    Write-Host ' 4. Limpieza de temporales del usuario'
    Write-Host ' 5. Estado de servicios clave'
    Write-Host ' 6. Programas instalados'
    Write-Host ' 7. Generar informe HTML'
    Write-Host ''
    Write-Host ' 0. Salir'
    Write-Host ''
}

function Wait-ITKeyPress {
    Write-Host ''
    Read-Host 'Pulsa Enter para volver al menú' | Out-Null
}

$exit = $false

while (-not $exit) {
    Show-ITMenu
    $choice = Read-Host 'Elige una opción'

    switch ($choice) {
        '1' { Show-SystemInfo; Wait-ITKeyPress }
        '2' { Show-NetworkDiagnostics; Wait-ITKeyPress }
        '3' { Show-ITNetworkRepairMenu }
        '4' { Show-ITTempCleanup; Wait-ITKeyPress }
        '5' { Show-ITServicesMenu }
        '6' { Show-ITInstalledPrograms; Wait-ITKeyPress }
        '7' { Show-ITHtmlReport; Wait-ITKeyPress }
        '0' { $exit = $true }
        default {
            Write-Host ''
            Write-Host 'Opción no válida.' -ForegroundColor Red
            Wait-ITKeyPress
        }
    }
}

Write-Host ''
Write-Host 'Hasta pronto.' -ForegroundColor Cyan
