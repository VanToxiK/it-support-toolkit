# Cleanup.psm1
# Modulo para la limpieza de archivos temporales del usuario (%TEMP%).
# Solo borra archivos con mas de 24 horas de antiguedad, nunca sigue
# enlaces simbolicos ni junctions, y nunca borra la carpeta %TEMP% en si.

function Get-ITReparsePointFlag {
    <#
        Comprueba si un elemento (archivo o carpeta) es un enlace simbolico
        o una junction, para no seguirlo ni contarlo.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileSystemInfo]$Item
    )

    return (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
}

function Get-ITTempFilesRecursive {
    <#
        Recorre una carpeta de forma manual (no con -Recurse) para poder
        saltar carpetas que sean enlaces simbolicos o junctions antes de
        entrar en ellas. Devuelve los archivos normales que encuentra.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $foundFiles = @()

    try {
        $items = Get-ChildItem -Path $Path -Force -ErrorAction Stop
    }
    catch {
        return $foundFiles
    }

    foreach ($item in $items) {
        if (Get-ITReparsePointFlag -Item $item) {
            # Enlace simbolico o junction: no se sigue ni se cuenta.
            continue
        }

        if ($item.PSIsContainer) {
            $foundFiles += Get-ITTempFilesRecursive -Path $item.FullName
        }
        else {
            $foundFiles += $item
        }
    }

    return $foundFiles
}

function Get-ITTempFiles {
    <#
        Devuelve los archivos de %TEMP% con mas de $MinAgeHours horas de
        antiguedad (segun ultima modificacion), junto con el recuento total
        y el tamano total en bytes. Es de solo lectura, no borra nada.
    #>
    param(
        [Parameter(Mandatory = $false)]
        [int]$MinAgeHours = 24
    )

    $tempPath = $env:TEMP
    $cutoff = (Get-Date).AddHours(-$MinAgeHours)

    $allFiles = Get-ITTempFilesRecursive -Path $tempPath
    $oldFiles = $allFiles | Where-Object { $_.LastWriteTime -lt $cutoff }

    $totalSize = 0
    foreach ($file in $oldFiles) {
        $totalSize += $file.Length
    }

    return [PSCustomObject]@{
        Files          = $oldFiles
        TotalCount     = $oldFiles.Count
        TotalSizeBytes = $totalSize
    }
}

function Remove-ITTempFiles {
    <#
        Borra los archivos indicados. Los archivos en uso u otros errores
        individuales no detienen el proceso: se cuentan como omitidos.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Files
    )

    $deletedCount = 0
    $skippedCount = 0
    $freedBytes = 0

    foreach ($file in $Files) {
        $size = $file.Length
        try {
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
            $deletedCount++
            $freedBytes += $size
        }
        catch {
            $skippedCount++
        }
    }

    return [PSCustomObject]@{
        DeletedCount = $deletedCount
        SkippedCount = $skippedCount
        FreedBytes   = $freedBytes
    }
}

function Show-ITTempCleanup {
    <#
        Orquesta la opcion 4: calcula, muestra, pide confirmacion, borra y
        muestra el resultado. Registra la accion en el log.
    #>

    Write-Host ''
    Write-Host '=== LIMPIEZA DE TEMPORALES DEL USUARIO ===' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Buscando archivos con más de 24 horas de antigüedad en la carpeta temporal...' -ForegroundColor Yellow

    $tempInfo = Get-ITTempFiles -MinAgeHours 24
    $sizeMB = [math]::Round($tempInfo.TotalSizeBytes / 1MB, 2)

    Write-Host ''
    Write-Host ('Archivos encontrados : {0}' -f $tempInfo.TotalCount)
    Write-Host ('Espacio ocupado      : {0} MB' -f $sizeMB)

    if ($tempInfo.TotalCount -eq 0) {
        Write-Host ''
        Write-Host 'No hay archivos temporales antiguos que borrar.' -ForegroundColor Green
        Write-ITLog -Message 'Limpieza de temporales: no había archivos antiguos que borrar.' -Level 'INFO'
        return
    }

    if (-not (Confirm-ITAction -Message 'Se van a borrar estos archivos temporales. Los archivos en uso se omitirán automáticamente.')) {
        Write-ITLog -Message 'El usuario canceló la limpieza de temporales.' -Level 'WARN'
        return
    }

    $result = Remove-ITTempFiles -Files $tempInfo.Files
    $freedMB = [math]::Round($result.FreedBytes / 1MB, 2)

    Write-Host ''
    Write-Host ('Archivos borrados    : {0}' -f $result.DeletedCount) -ForegroundColor Green
    Write-Host ('Archivos omitidos    : {0} (en uso o sin permisos)' -f $result.SkippedCount) -ForegroundColor DarkYellow
    Write-Host ('Espacio liberado     : {0} MB' -f $freedMB) -ForegroundColor Green

    Write-ITLog -Message ('Limpieza de temporales: {0} borrados, {1} omitidos, {2} MB liberados.' -f $result.DeletedCount, $result.SkippedCount, $freedMB) -Level 'ACTION'
}

Export-ModuleMember -Function Get-ITTempFiles, Remove-ITTempFiles, Show-ITTempCleanup
