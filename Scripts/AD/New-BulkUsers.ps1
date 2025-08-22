<#
.SYNOPSIS
  Script de ejemplo en PowerShell
.DESCRIPTION
  Este script demuestra cómo estructurar y documentar un archivo.
.EXAMPLE
  .\New-BulkUsers.ps1 -Path .\usuarios.csv
#>

param(
    [string]$Path = ".\usuarios.csv"
)

Write-Host "Hola Álvaro, tu primer script está listo 🚀"
