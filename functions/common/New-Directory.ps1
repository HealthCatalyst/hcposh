function New-Directory {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $Dir
    )
    if (!(Test-Path $Dir)) {
        New-Item -ItemType Directory -Force -Path $Dir -ErrorAction Stop | Out-Null
    }
}