function Zip {
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0, Mandatory = $True)]
        [string] $Directory,
        [Parameter(Position = 1, Mandatory = $True)]
        [string] $Destination
    )
    [System.IO.Compression.ZipFile]::CreateFromDirectory($Directory, $Destination, 'Optimal', $true);
}
