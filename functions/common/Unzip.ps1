function Unzip {
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0, Mandatory = $True)]
        [string] $File,
        [Parameter(Position = 1, Mandatory = $True)]
        [string] $Destination
    )
    [System.IO.Compression.ZipFile]::ExtractToDirectory($File, $Destination);
}
