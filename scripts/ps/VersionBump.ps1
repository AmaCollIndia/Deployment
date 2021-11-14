[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$VersionJsonFile,
  [bool]$isPreRelease = $true
)

Write-Host "Current Version "
Write-Host ($currentVersion = Get-Content "$VersionJsonFile" | Out-String | ConvertFrom-Json)

$currentVersion.patch = $currentVersion.patch + 1

Write-Host "New Version "
Write-Host "$currentVersion"


$preReleaseTag = ''
$buildNumber = "{0}{1}" -f [DateTime]::Now.DayOfYear, [DateTime]::Now.ToString("yy")

if($isPreRelease) {
    $preReleaseTag = "-preview-$buildNumber"
}

Write-Host "New Version String :"($currentVersionString = "{0}.{1}.{2}" -f $currentVersion.major, $currentVersion.minor, $currentVersion.patch)
$version = "$currentVersionString$preReleaseTag"
$fileVersion = "$currentVersionString.$buildNumber"
$assemblyVersion = "$currentVersionString.$buildNumber"

if($env:GITHUB_ENV) {
    echo "Version=$version" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
    echo "FileVersion=$fileVersion" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
    echo "AssemblyVersion=$assemblyVersion" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
}

$currentVersion | ConvertTo-Json | Out-File $VersionJsonFile
