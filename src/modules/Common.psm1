# Common.psm1
# Utilidades compartidas por el resto de modulos: deteccion de permisos de
# administrador, confirmaciones S/N, aviso de accion que requiere admin,
# la funcion segura para leer datos sin detener el programa si algo falla,
# y la version de la herramienta.

function Get-ITToolkitVersion {
    <#
        Devuelve la version de IT Support Toolkit. Unico sitio del proyecto
        donde se define el numero de version.
    #>

    return '1.0.0'
}

function Test-ITIsAdmin {
    <#
        Comprueba si el script se esta ejecutando con permisos de
        administrador. Si por lo que sea la comprobacion falla, se asume
        que NO hay permisos (opcion mas segura) y no se detiene el programa.
    #>

    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Confirm-ITAction {
    <#
        Muestra un mensaje de aviso y pregunta si se quiere continuar.
        Devuelve $true solo si el usuario responde "S".
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host ''
    Write-Host $Message -ForegroundColor Yellow
    $answer = Read-Host '¿Deseas continuar? (S/N)'
    return ($answer -eq 'S' -or $answer -eq 's')
}

function Show-ITAdminRequiredMessage {
    <#
        Explica que una accion necesita permisos de administrador y como
        conseguirlos, sin mostrar trazas tecnicas. Registra el intento
        en el log como aviso.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ActionName
    )

    Write-Host ''
    Write-Host ("La acción ""{0}"" necesita permisos de administrador." -f $ActionName) -ForegroundColor DarkYellow
    Write-Host 'Cierra el programa y vuelve a abrirlo con "Iniciar como administrador.bat".' -ForegroundColor DarkYellow

    Write-ITLog -Message ('Acción omitida por falta de permisos de administrador: {0}' -f $ActionName) -Level 'WARN'
}

function Get-ITSafeValue {
    <#
        Ejecuta un bloque de codigo y, si falla, devuelve "No disponible"
        en lugar de detener el resto del programa. Se usa para que un dato
        que no se puede leer no impida ver el resto de la informacion.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock
    )

    try {
        & $ScriptBlock
    }
    catch {
        'No disponible'
    }
}

Export-ModuleMember -Function Get-ITToolkitVersion, Test-ITIsAdmin, Confirm-ITAction, Show-ITAdminRequiredMessage, Get-ITSafeValue
