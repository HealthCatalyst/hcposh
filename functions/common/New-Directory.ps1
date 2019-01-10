function New-Directory {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Dir,
        [switch] $Force
    )
    try {
        if ((Test-Path $Dir) -and $Force) {
            Remove-Item $Dir -Recurse -Force | Out-Null
        }
        if (!(Test-Path $Dir)) {
            New-Item -ItemType Directory -Force -Path $Dir -ErrorAction Stop | Out-Null
        }
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        $Msg = "$(" " * 8)An error occurred while trying to create a new directory :( --> $ErrorMessage"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
        Exit
    }
}