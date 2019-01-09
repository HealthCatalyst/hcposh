function Write-Log {
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0, Mandatory = $True)]
        [string]$Message,
        [Parameter(Position = 1)]
        [psobject]$Type = "info",
        [Parameter(Position = 2)]
        [psobject]$Identifier
    )
    if ($LogFile) {
        $Output = New-Object PSObject
        $Output | Add-Member -Type NoteProperty -Name DateDTS -Value (Get-Date -Format G)
        $Output | Add-Member -Type NoteProperty -Name MessageTXT -Value $Message.Trim()
        $Output | Add-Member -Type NoteProperty -Name Type -Value $Type
        if ($Identifier) {
            $Output | Add-Member -Type NoteProperty -Name Identifier -Value $Identifier
        }			
        Add-content $LogFile -Value ($Output | ConvertTo-Json -Depth 100 -Compress);
    }
}
