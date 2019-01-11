function Zip {
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0, Mandatory = $True)]
        [string] $Directory,
        [Parameter(Position = 1, Mandatory = $True)]
        [string] $Destination
    )
    try {
        [System.IO.Compression.ZipFile]::CreateFromDirectory($Directory, $Destination, 'Optimal', $true);
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        $Msg = "$(" " * 8)An error occurred while trying to zip a file :( --> $ErrorMessage"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
        Exit
    }
}
