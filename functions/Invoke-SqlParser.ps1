function Invoke-SqlParser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)]
        [string]$Query,
        [bool]$Log = $False,
        [bool]$SelectStar = $False,
        [bool]$Brackets = $False
    )
    begin {
        $Parsed = New-Object -TypeName ColumnExtractor.Parser($Log, $SelectStar, $Brackets)
    }
    process {
        #Using the parsed object
        return $Parsed.GetTables($Query)
    }
}
