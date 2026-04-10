# Requires PowerShell 5.1 or later
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$source = Join-Path $scriptRoot 'charts\artifactory\common\values.schema.json'
$targets = @(
    Join-Path $scriptRoot 'charts\artifactory\oss\core\values.schema.json',
    Join-Path $scriptRoot 'charts\artifactory\jcr\core\values.schema.json'
)

foreach ($target in $targets) {
    Write-Host "Copying $source -> $target"
    Copy-Item -Path $source -Destination $target -Force
}
