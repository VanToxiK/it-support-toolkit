# ITSupportToolkit.ps1
# Punto de entrada del programa: muestra el menu principal y llama a las
# funciones de cada modulo segun la opcion elegida por el usuario.
# La entrada del usuario solo se usa para elegir una rama del switch,
# nunca para construir comandos.

$modulesPath = Join-Path -Path $PSScriptRoot -ChildPath 'modules'

Import-Module (Join-Path $modulesPath 'Logging.psm1') -Force
Import-Module (Join-Path $modulesPath 'SystemInfo.psm1') -Force
Import-Module (Join-Path $modulesPath 'Network.psm1') -Force

function Show-ITMenu {
    Clear-Host
    Write-Host '======================================' -ForegroundColor Cyan
    Write-Host '        IT SUPPORT TOOLKIT' -ForegroundColor Cyan
    Write-Host '======================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host ' 1. Información del sistema'
    Write-Host ' 2. Diagnóstico de red'
    Write-Host ' 3. Reparación básica de red         [Disponible próximamente]' -ForegroundColor DarkGray
    Write-Host ' 4. Limpieza de temporales           [Disponible próximamente]' -ForegroundColor DarkGray
    Write-Host ' 5. Estado de servicios clave        [Disponible próximamente]' -ForegroundColor DarkGray
    Write-Host ' 6. Programas instalados             [Disponible próximamente]' -ForegroundColor DarkGray
    Write-Host ' 7. Generar informe HTML             [Disponible próximamente]' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host ' 0. Salir'
    Write-Host ''
}

function Wait-ITKeyPress {
    Write-Host ''
    Read-Host 'Pulsa Enter para volver al menú' | Out-Null
}

function Show-ITComingSoon {
    Write-Host ''
    Write-Host 'Disponible próximamente.' -ForegroundColor DarkYellow
}

$exit = $false

while (-not $exit) {
    Show-ITMenu
    $choice = Read-Host 'Elige una opción'

    switch ($choice) {
        '1' { Show-SystemInfo; Wait-ITKeyPress }
        '2' { Show-NetworkDiagnostics; Wait-ITKeyPress }
        '3' { Show-ITComingSoon; Wait-ITKeyPress }
        '4' { Show-ITComingSoon; Wait-ITKeyPress }
        '5' { Show-ITComingSoon; Wait-ITKeyPress }
        '6' { Show-ITComingSoon; Wait-ITKeyPress }
        '7' { Show-ITComingSoon; Wait-ITKeyPress }
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
