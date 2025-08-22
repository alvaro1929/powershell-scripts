<#
.SYNOPSIS
  Crea múltiples usuarios en Active Directory desde un archivo CSV.

.DESCRIPTION
  Este script lee un CSV con columnas definidas (Name, SamAccountName, OU, Password, etc.)
  y crea usuarios en Active Directory. Incluye validaciones, logging y soporte para -WhatIf.

.EXAMPLE
  .\New-BulkUsers.ps1 -Path .\usuarios.csv -Verbose -WhatIf
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "Medium")]
param (
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ })]
    [string]$Path,

    [string]$Log = ".\logs\New-BulkUsers_$((Get-Date).ToString('yyyyMMdd_HHmmss')).log"
)

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "$ts [$Level] $Message"
    $line | Out-File -FilePath $Log -Append -Encoding utf8
    Write-Verbose $line
}

try {
    # Importar CSV
    $users = Import-Csv -Path $Path
    Write-Log "Iniciando creación de $($users.Count) usuarios desde $Path"

    foreach ($u in $users) {
        $name   = $u.Name
        $sam    = $u.SamAccountName
        $ou     = $u.OU
        $pwd    = (ConvertTo-SecureString $u.Password -AsPlainText -Force)

        if ($PSCmdlet.ShouldProcess("Usuario $sam en OU=$ou", "Crear usuario")) {
            try {
                # Validar si ya existe
                $exists = Get-ADUser -Filter { SamAccountName -eq $sam } -ErrorAction SilentlyContinue
                if ($exists) {
                    Write-Log "Usuario $sam ya existe, se omite" "WARN"
                    continue
                }

                # Crear usuario
                New-ADUser `
                    -Name $name `
                    -SamAccountName $sam `
                    -Path $ou `
                    -AccountPassword $pwd `
                    -Enabled $true `
                    -ChangePasswordAtLogon $true `
                    -ErrorAction Stop

                Write-Log "Usuario $sam creado correctamente"
            }
            catch {
                Write-Log "Error creando usuario $sam: $($_.Exception.Message)" "ERROR"
            }
        }
    }

    Write-Log "Proceso completado"
}
catch {
    Write-Log "Error global: $($_.Exception.Message)" "ERROR"
    throw
}