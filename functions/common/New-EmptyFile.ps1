function New-EmptyFile {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$OutFile
    )
    try {
        if (Test-Path $OutFile) {
            Remove-Item $OutFile -Force | Out-Null
        }New-Item -ItemType File -Force -Path $OutFile -ErrorAction Stop | Out-Null    
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        $Msg = "$(" " * 4)Unable to create output directory (""$(Split-Path $OutDir -Leaf)"") --> $ErrorMessage"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error'; 
        Exit
    }
}