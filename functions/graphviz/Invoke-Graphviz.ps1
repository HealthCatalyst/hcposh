function Invoke-Graphviz {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName)]
        [string]$File,
        [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName)]
        [string]$OutType,
        [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName)]
        [string]$OutFile
    )
    process {
        try {
            $Graphviz = ".""$((Get-Item $PSScriptRoot).Parent.Parent.FullName)\libraries\graphviz\dot.exe"" -T$($OutType) ""$($File)"" -o ""$($OutFile)"" -q"
        }
        catch {
            $Msg = "Unable to find the graphviz dot.exe"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
        }
        Invoke-Expression $Graphviz
    }
}