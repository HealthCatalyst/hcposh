function Unzip {
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0, Mandatory = $True)]
        [string] $File,
        [Parameter(Position = 1, Mandatory = $True)]
        [string] $Destination
    )
    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($File, $Destination);
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        $Msg = "$(" " * 8)An error occurred while trying to unzip a file :( --> $ErrorMessage"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
        Exit
    }
}
