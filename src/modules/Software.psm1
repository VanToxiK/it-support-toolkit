# Software.psm1
# Modulo de solo lectura que lista los programas instalados leyendo las
# claves "Uninstall" del registro, y permite exportar el listado a CSV.

$script:UninstallRegistryPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
)

function Get-ITInstalledPrograms {
    <#
        Lee (solo lectura) las claves Uninstall del registro y devuelve
        nombre, version, editor y fecha de instalacion, sin duplicados ni
        entradas vacias o de componentes del sistema, ordenado por nombre.
    #>

    $programs = @()

    foreach ($registryPath in $script:UninstallRegistryPaths) {
        try {
            $subKeys = Get-ChildItem -Path $registryPath -ErrorAction Stop
        }
        catch {
            continue
        }

        foreach ($subKey in $subKeys) {
            try {
                $entry = Get-ItemProperty -Path $subKey.PSPath -ErrorAction Stop

                if ([string]::IsNullOrWhiteSpace($entry.DisplayName)) {
                    continue
                }
                if ($entry.SystemComponent -eq 1) {
                    continue
                }
                if ([string]::IsNullOrWhiteSpace($entry.UninstallString)) {
                    continue
                }

                $installDate = 'No disponible'
                if ($entry.InstallDate) {
                    try {
                        $parsedDate = [datetime]::ParseExact($entry.InstallDate, 'yyyyMMdd', $null)
                        $installDate = $parsedDate.ToString('dd/MM/yyyy')
                    }
                    catch { }
                }

                $programs += [PSCustomObject]@{
                    Name        = $entry.DisplayName
                    Version     = if ($entry.DisplayVersion) { $entry.DisplayVersion } else { 'No disponible' }
                    Publisher   = if ($entry.Publisher) { $entry.Publisher } else { 'No disponible' }
                    InstallDate = $installDate
                }
            }
            catch {
                continue
            }
        }
    }

    $uniquePrograms = @{}
    foreach ($program in $programs) {
        $key = '{0}|{1}' -f $program.Name, $program.Version
        if (-not $uniquePrograms.ContainsKey($key)) {
            $uniquePrograms[$key] = $program
        }
    }

    return $uniquePrograms.Values | Sort-Object -Property Name
}

function Export-ITInstalledProgramsCsv {
    <#
        Exporta el listado de programas a un CSV en UTF-8 dentro de
        "Documentos\IT Support Toolkit Reports". Devuelve la ruta del
        archivo creado, o $null si algo falla.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Programs
    )

    try {
        $documentsPath = [Environment]::GetFolderPath('MyDocuments')
        $reportsFolder = Join-Path $documentsPath 'IT Support Toolkit Reports'

        if (-not (Test-Path -Path $reportsFolder)) {
            New-Item -Path $reportsFolder -ItemType Directory -Force | Out-Null
        }

        $fileName = 'ProgramasInstalados_{0}.csv' -f (Get-Date -Format 'yyyyMMdd_HHmmss')
        $filePath = Join-Path $reportsFolder $fileName

        $Programs | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8

        return $filePath
    }
    catch {
        Write-ITLog -Message ('Error al exportar el listado de programas a CSV: {0}' -f $_.Exception.Message) -Level 'ERROR'
        return $null
    }
}

function Show-ITInstalledPrograms {
    <#
        Muestra el listado de programas instalados y ofrece exportarlo a
        CSV. Registra la consulta y la exportacion en el log.
    #>

    Write-Host ''
    Write-Host '=== PROGRAMAS INSTALADOS ===' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Leyendo el registro de Windows...' -ForegroundColor Yellow

    $programs = Get-ITInstalledPrograms

    Write-Host ''
    foreach ($program in $programs) {
        Write-Host ('  {0} - v{1} - {2} - {3}' -f $program.Name, $program.Version, $program.Publisher, $program.InstallDate)
    }

    Write-Host ''
    Write-Host ('Total de programas encontrados: {0}' -f $programs.Count) -ForegroundColor Cyan

    Write-ITLog -Message ('Se ha consultado el listado de programas instalados ({0} encontrados).' -f $programs.Count) -Level 'INFO'

    if ($programs.Count -eq 0) {
        return
    }

    if (Confirm-ITAction -Message '¿Quieres exportar este listado a un archivo CSV?') {
        $exportedPath = Export-ITInstalledProgramsCsv -Programs $programs

        Write-Host ''
        if ($exportedPath) {
            Write-Host ('Listado exportado a: {0}' -f $exportedPath) -ForegroundColor Green
            Write-ITLog -Message ('Listado de programas exportado a: {0}' -f $exportedPath) -Level 'ACTION'
        }
        else {
            Write-Host 'No se ha podido exportar el listado.' -ForegroundColor Red
        }
    }
    else {
        Write-ITLog -Message 'El usuario canceló la exportación del listado de programas.' -Level 'WARN'
    }
}

Export-ModuleMember -Function Get-ITInstalledPrograms, Export-ITInstalledProgramsCsv, Show-ITInstalledPrograms
