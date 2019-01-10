function Invoke-DataRaw {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName)]
        [string]$File,
        [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName)]
        [string]$OutDir
    )
    process {
        try {
            Test-Path $File | Out-Null;
            $InputFile = Get-Item $File
            if ($InputFile.Extension -ne '.hcx') {
                throw;
            }
            else {
                $FileDirectory = Split-Path $File -Parent
                $Msg = "DATA - $(Split-Path $File -Leaf)"; Write-Host $Msg -ForegroundColor Magenta; Write-Verbose $Msg; Write-Log $Msg;
            }
        }
        catch {
            $Msg = "$(" " * 8)Unable to find any hcx files."; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
        }
        
        try {
            $Msg = "$(" " * 4)Unzipping hcx file..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
            
            Copy-Item -Path $File -Destination $File.Replace('.hcx', '.zip') -Force | Out-Null
            $ZipFile = $File.Replace('.hcx', '.zip')
            
            $OutBin = "$($FileDirectory)\$((Split-Path $File -Leaf).Replace('.hcx', '_bin'))"
            $Zipoutdir = "$($OutBin)\$((Split-Path $File -Leaf).Replace('.hcx', '_zip'))"
            if (Test-Path $OutBin) {
                Remove-Item $OutBin -Force -Recurse | Out-Null
            }
            If (!(Test-Path $Zipoutdir)) {
                New-Item -ItemType Directory -Force -Path $Zipoutdir -ErrorAction Stop | Out-Null
            }
            Unzip -file $ZipFile -destination $Zipoutdir
            Remove-Item $ZipFile -Force | Out-Null
        }
        catch {
            $Msg = "$(" " * 8)Unable to unzip file."; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
        }
        
        try {
            $Msg = "$(" " * 4)Getting sam json object..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
            $SamFile = Get-ChildItem $Zipoutdir -Recurse | Where-Object { $_.Extension -eq ".sam" }
            
            #DATA ENTRY CSV FILES
            $CsvFiles = Get-ChildItem $Zipoutdir -Recurse | Where-Object { $_.Extension -eq ".csv" }
            if ($CsvFiles) {
                $CsvArray = @();
                ForEach ($Csv in $CsvFiles) {
                    $CsvFile = New-Object PSObject -Property @{ FullyQualifiedNM = $Csv.BaseName; Data = Import-Csv -Path $Csv.FullName; Msg = $null }
                    $CsvArray += $CsvFile
                }
            }
            
            $RawContent = Get-Content $SamFile.FullName | Select-Object -Skip 1
            try {
                $jsonSettings = New-Object Newtonsoft.Json.JsonSerializerSettings
                $jsonSettings.TypeNameHandling = 'Objects'
                $jsonSettings.PreserveReferencesHandling = 'Objects'
                $MetadataRaw = [Newtonsoft.Json.JsonConvert]::DeserializeObject($RawContent, $jsonSettings)
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                $Msg = "$(" " * 8)Unable to deserialize json object :( --> $ErrorMessage"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
                Exit
            }
            $FirstRow = Get-Content $SamFile.FullName | Select-Object -First 1
            $SamdVersionText = $FirstRow | ForEach-Object { $_.split('"')[3] }
            if ($SamdVersionText) {
                $MetadataRaw | Add-Member -Type NoteProperty -Name SAMDVersionText -Value $SamdVersionText
            }
            else {
                $Msg = "$(" " * 8)Unable to parse Sam Designer Version."; Write-Host $Msg -ForegroundColor Yellow; Write-Verbose $Msg; Write-Log $Msg 'warning';
            }
            if ($CsvFiles) {
                $Msg = "$(" " * 4)Found $($CsvFiles.Count) data entry entity file(s)..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
                $MetadataRaw | Add-Member -Type NoteProperty -Name DataEntryData -Value $CsvArray
            }
            $MetadataRaw | Add-Member -Type NoteProperty -Name _hcposh -Value (New-Object PSObject -Property @{ FileBaseName = $InputFile.BaseName; LastWriteTime = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.ffffff") })
            $Msg = "$(" " * 8)Converted from json to psobject"; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
            Remove-Item $OutBin -Recurse -Force
        }
        catch {
            $Msg = "$(" " * 8)Unable to get sam content into object."; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
        }
        $Output = New-Object PSObject
        $Output | Add-Member -Type NoteProperty -Name metadataRaw -Value $MetadataRaw
        $Output | Add-Member -Type NoteProperty -Name outdir -Value $OutDir
        return $Output
    }
}