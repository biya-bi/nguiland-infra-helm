# Requires PowerShell 5.1 or later
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Copy schemas
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$source = Join-Path $scriptRoot 'core\artifactory-common\values.schema.json'
$targets = @(
    Join-Path $scriptRoot 'core\artifactory-oss\values.schema.json',
    Join-Path $scriptRoot 'core\artifactory-jcr\values.schema.json'
)

foreach ($target in $targets) {
    Write-Host "Copying $source -> $target"
    Copy-Item -Path $source -Destination $target -Force
}
