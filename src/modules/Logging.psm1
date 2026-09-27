# Logging.psm1
# Modulo encargado de registrar en un archivo de log cada accion relevante
# que se realiza desde IT Support Toolkit (incluso las de solo lectura).

function Write-ITLog {
    <#
        Escribe una linea en el archivo de log del dia actual.
        Si no se puede escribir (por ejemplo, sin permisos), avisa por
        consola pero no detiene el programa.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'ACTION')]
        [string]$Level = 'INFO'
    )

    try {
        $logFolder = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'ITSupportToolkit\logs'

        if (-not (Test-Path -Path $logFolder)) {
            New-Item -Path $logFolder -ItemType Directory -Force | Out-Null
        }

        $logFileName = 'ITSupportToolkit_{0}.log' -f (Get-Date -Format 'yyyyMMdd')
        $logFilePath = Join-Path -Path $logFolder -ChildPath $logFileName

        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $line = '[{0}] [{1}] {2}' -f $timestamp, $Level, $Message

        Add-Content -Path $logFilePath -Value $line -Encoding UTF8
    }
    catch {
        Write-Host "No se ha podido escribir en el log: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
}

Export-ModuleMember -Function Write-ITLog
