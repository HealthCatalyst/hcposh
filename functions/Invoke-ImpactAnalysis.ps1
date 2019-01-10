function Invoke-ImpactAnalysis {
    [CmdletBinding()]
    [OutputType([PSObject])]
    param
    (
        [Parameter(Mandatory = $True)]
        [string]$Server,
        [Parameter(Mandatory = $False)]
        [string]$ConfigPath = "./_impactConfig.json",
        [Parameter(Mandatory = $False)]
        [string]$OutDir = "./_impact"
    )
    begin {
        $Msg = "Impact analysis [$($Server)]"; Write-Host $Msg -ForegroundColor Magenta; Write-Verbose $Msg; Write-Log $Msg;
        if (!(Test-Path $ConfigPath)) {
            $Msg = "$(" " * 4)Unable to find configuration file in current directory or specified path"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
            Do { $TemplateFlag = Read-Host -Prompt 'Create a config template? (Y/N)' }
            while ('y', 'n' -notcontains $TemplateFlag)
            
            if ($TemplateFlag -eq 'y') {
                New-Directory -Dir './_impactConfig.json' -Force; Add-Content ./_impactConfig.json "{`n  ""Columns"": {`n    ""SQL"": {`n      ""Connection"": {`n        ""Database"": ""<database>""`n      },`n      ""FilePath"": ""./columns.sql""`n    }`n  },`n  ""Queries"": {`n    ""SQL"": {`n      ""Connection"": {`n        ""Database"": ""<database>""`n      },`n      ""FilePath"": ""./queries.sql""`n    }`n  },`n  ""Mappings"": {`n    ""CSV"": {`n      ""FilePath"": ""./mappings.csv""`n    }`n  }`n}";
                New-Directory -Dir './columns.sql' -Force; Add-Content ./columns.sql "SELECT`n   /******REQUIRED******/`n    tbl.DatabaseNM`n   ,tbl.SchemaNM`n   ,tbl.TableNM`n   ,col.ColumnNM`n   /********************/`n   /* ADD ANY OTHER GROUPERS YOU NEED`n   ,Grouper1NM?`n   ,Grouper2NM?`n   */`nFROM CatalystAdmin.TableBASE AS tbl`nINNER JOIN CatalystAdmin.DatamartBASE AS dm`n   ON dm.DatamartID = tbl.DatamartID`nINNER JOIN CatalystAdmin.ColumnBASE AS col`n   ON col.TableID = tbl.TableID`n      AND col.IsSystemColumnFLG = 'N'`nWHERE dm.DatamartNM = '<MY_DATAMART>'`n      AND tbl.PublicFLG = 1;"
                New-Directory -Dir './mappings.csv' -Force; '' | Select-Object FromDatabaseNM, FromSchemaNM, FromTableNM, FromColumnNM, ToDatabaseNM, ToSchemaNM, ToTableNM, ToColumnNM | Export-Csv './mappings.csv' -NoTypeInformation
                New-Directory -Dir './queries.sql' -Force; Add-Content ./queries.sql "SELECT`n   /******REQUIRED******/`n    obj.AttributeValueLongTXT AS QueryTXT`n   /********************/`n   /* ADD ANY OTHER GROUPERS YOU NEED`n   ,tbl.ViewNM+' ('+b.BindingNM+')' AS QueryNM`n   ,'SAM Designer' AS Grouper1NM`n   ,dm.DatamartNM AS Grouper2NM`n   */`nFROM CatalystAdmin.ObjectAttributeBASE AS obj`nINNER JOIN CatalystAdmin.BindingBASE AS b`n   ON b.BindingID = obj.ObjectID`nINNER JOIN CatalystAdmin.TableBASE AS tbl`n   ON tbl.TableID = b.DestinationEntityID`nINNER JOIN CatalystAdmin.DataMartBASE AS dm`n   ON dm.DatamartID = tbl.DatamartID`nWHERE obj.ObjectTypeCD = 'Binding'`n      AND obj.AttributeNM = 'UserDefinedSQL'`n      AND b.BindingClassificationCD != 'SourceMart'`n      AND LEN(obj.AttributeValueLongTXT) > 0`n      AND tbl.TableID NOT IN`n(`n SELECT`n     tbl.TableID`n FROM CatalystAdmin.TableBASE AS tbl`n INNER JOIN CatalystAdmin.DatamartBASE AS dm`n    ON dm.DatamartID = tbl.DatamartID`n WHERE dm.DatamartNM = '<MY_DATAMART>'`n);"
                
                $Msg = "Configuration files created, rerun when you are ready.`r`n"; Write-Host $Msg -ForegroundColor Green; Write-Verbose $Msg; Write-Log $Msg;
            }
            Break;
        }
        else {
            $Msg = "$(" " * 4)Creating output directory..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
            try {
                if (Test-Path $OutDir) {
                    Remove-Item $OutDir -Recurse -Force | Out-Null
                }
                New-Item -ItemType Directory -Force -Path $OutDir -ErrorAction Stop | Out-Null
                $Msg = "$(" " * 8)Created ""$(Split-Path $OutDir -Leaf)"" directory"; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
                
                New-Item -ItemType Directory -Force -Path "$($OutDir)/raw/csv" -ErrorAction Stop | Out-Null
                $Msg = "$(" " * 8)Created ""$(Split-Path $OutDir -Leaf)/raw/csv"" directory"; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
                
                New-Item -ItemType Directory -Force -Path "$($OutDir)/raw/json" -ErrorAction Stop | Out-Null
                $Msg = "$(" " * 8)Created ""$(Split-Path $OutDir -Leaf)/raw/json"" directory"; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
            }
            catch {
                $Msg = "$(" " * 4)Unable to create output directory (""$(Split-Path $OutDir -Leaf)"" or ""$(Split-Path $OutDir -Leaf)/raw"")"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
            }
            
            try {
                $Config = Get-Content $ConfigPath | ConvertFrom-Json
                
                $Properties = ($Config | Get-Member | Where-Object MemberType -eq NoteProperty).Name
                if (!($Properties -contains 'Columns' -and $Properties -contains 'Queries')) {
                    $Msg = "$(" " * 8)Configruation file (""$(Split-Path $ConfigPath -Leaf)"") must contain all of the the following properies: Columns, Queries"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
                    Break;
                }
                $MappingsFlag = $False;
                if ($Properties -contains 'Mappings') {
                    $MappingsFlag = $True;
                }
                
                $Msg = "$(" " * 4)Getting data..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
                #region Columns  (REQUIRED)
                $ColumnsPath = $Config.Columns.SQL.FilePath
                if (!(Test-Path $ColumnsPath)) {
                    $Msg = "$(" " * 4)Unable to find ""$(Split-Path $ColumnsPath -Leaf)"" specified in the configuration file"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
                    Break;
                }
                else {
                    try {
                        $ColumnsSQL = Get-Content $ColumnsPath | Out-String
                        
                        try {
                            $ColumnsDb = $Config.Columns.SQL.Connection.Database
                            if (!($ColumnsDb)) {
                                $Columns = Invoke-Sqlcmd -Query $ColumnsSQL -ServerInstance $Server
                            }
                            else {
                                $Columns = Invoke-Sqlcmd -Query $ColumnsSQL -ServerInstance $Server -Database $ColumnsDb
                            }
                            $Msg = "$(" " * 8)$(($Columns | Measure-Object).Count) records from query ""$(Split-Path $ColumnsPath -Leaf)"""; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
                            
                            $Properties = ($Columns[0] | Get-Member | Where-Object MemberType -eq Property).Name
                            
                            if (!($Properties.ToLower() -contains 'databasenm' -and $Properties.ToLower() -contains 'schemanm' -and $Properties.ToLower() -contains 'tablenm' -and $Properties.ToLower() -contains 'columnnm')) {
                                $Msg = "$(" " * 8)Sql query must contain the following columns: DatabaseNM, SchemaNM, TableNM, and ColumnNM"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
                                Break;
                            }
                            
                            $UpdatedColumns = @()
                            $I = 0
                            foreach ($Column in $Columns) {
                                $Fqn = "$($Column.DatabaseNM.ToLower()).$($Column.SchemaNM.ToLower()).$($Column.TableNM.ToLower() -replace 'base$', '').$($Column.ColumnNM.ToLower())"
                                $UpdatedColumn = New-Object PSObject
                                $UpdatedColumn | Add-Member -Type NoteProperty -Name `$ColumnId -Value $I
                                $UpdatedColumn | Add-Member -Type NoteProperty -Name `$Fqn -Value $Fqn
                                $UpdatedColumn | Add-Member -Type NoteProperty -Name `$Queries -Value @()
                                if ($MappingsFlag) {
                                    $UpdatedColumn | Add-Member -Type NoteProperty -Name `$Mappings -Value @()
                                }
                                foreach ($Property in $Properties) {
                                    $UpdatedColumn | Add-Member -Type NoteProperty -Name $Property -Value $Column.$Property
                                }
                                $UpdatedColumns += $UpdatedColumn
                                $I++
                            }
                            $Columns = $UpdatedColumns;
                        }
                        catch {
                            $Msg = "$(" " * 8)Unable to establish a connection to db or execute query"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
                            $Msg = "$(" " * 8)$($Error[0])"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
                        }
                    }
                    catch {
                        $Msg = "$(" " * 4)Unable to get the contents of the ""$(Split-Path $Config.Queries.SQL.FilePath -Leaf)"" file"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
                        Break;
                    }
                }
                #endregion
                #region Queries  (REQUIRED)
                $QueriesPath = $Config.Queries.SQL.FilePath
                if (!(Test-Path $QueriesPath)) {
                    $Msg = "$(" " * 4)Unable to find ""$(Split-Path $QueriesPath -Leaf)"" specified in the configuration file"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
                    Break;
                }
                else {
                    try {
                        $QueriesSQL = Get-Content $QueriesPath | Out-String
                        
                        try {
                            $QueriesDb = $Config.Queries.SQL.Connection.Database
                            if (!($QueriesDb)) {
                                $Queries = Invoke-Sqlcmd -Query $QueriesSQL -ServerInstance $Server -MaxCharLength 8000000
                            }
                            else {
                                $Queries = Invoke-Sqlcmd -Query $QueriesSQL -ServerInstance $Server -Database $QueriesDb -MaxCharLength 8000000
                            }
                            $Msg = "$(" " * 8)$(($Queries | Measure-Object).Count) records from query ""$(Split-Path $QueriesPath -Leaf)"""; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
                            
                            $Properties = ($Queries[0] | Get-Member | Where-Object MemberType -eq Property).Name
                            
                            if (!($Properties.ToLower() -contains 'querytxt')) {
                                $Msg = "$(" " * 8)Sql query must contain the following column: QueryTXT"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
                                Break;
                            }
                            
                            $I = 0
                            $UpdatedQueries = @()
                            foreach ($Query in $Queries) {
                                $UpdatedQuery = New-Object PSObject
                                $UpdatedQuery | Add-Member -Type NoteProperty -Name `$QueryId -Value $I
                                $UpdatedQuery | Add-Member -Type NoteProperty -Name `$Query -Value $Query.querytxt
                                $UpdatedQuery | Add-Member -Type NoteProperty -Name `$Columns -Value @()
                                foreach ($Property in $Properties | Where-Object { $_.ToLower() -ne 'querytxt' }) {
                                    $UpdatedQuery | Add-Member -Type NoteProperty -Name $Property -Value $Query.$Property
                                }
                                $UpdatedQueries += $UpdatedQuery
                                $I++
                            }
                            $Queries = $UpdatedQueries;
                        }
                        catch {
                            $Msg = "$(" " * 8)Unable to establish a connection to db or execute query"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
                            $Msg = "$(" " * 8)$($Error[0])"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
                        }
                    }
                    catch {
                        $Msg = "$(" " * 4)Unable to get the contents of the ""$(Split-Path $Config.Queries.SQL.FilePath -Leaf)"" file"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
                        Break;
                    }
                }
                #endregion
                #region Mappings (OPTIONAL)
                if ($MappingsFlag) {
                    $MappingsPath = $Config.Mappings.CSV.FilePath
                    if (!(Test-Path $MappingsPath)) {
                        $Msg = "$(" " * 4)Unable to find ""$(Split-Path $MappingsPath -Leaf)"" specified in the configuration file"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
                        Break;
                    }
                    else {
                        try {
                            $Mappings = Get-Content $MappingsPath | ConvertFrom-Csv
                        }
                        catch {
                            $Msg = "$(" " * 4)Unable to parse the contents of the ""$(Split-Path $Config.Mappings.CSV.FilePath -Leaf)"" file"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
                            Break;
                        }
                        $Msg = "$(" " * 8)$(($Mappings | Measure-Object).Count) records from csv ""$(Split-Path $MappingsPath -Leaf)"""; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
                        
                        $Properties = ($Mappings[0] | Get-Member | Where-Object MemberType -eq NoteProperty).Name
                        
                        if (!($Properties.ToLower() -contains 'fromdatabasenm' -and $Properties.ToLower() -contains 'fromschemanm' -and $Properties.ToLower() -contains 'fromtablenm' -and $Properties.ToLower() -contains 'fromcolumnnm' -and `
                                    $Properties.ToLower() -contains 'todatabasenm' -and $Properties.ToLower() -contains 'toschemanm' -and $Properties.ToLower() -contains 'totablenm' -and $Properties.ToLower() -contains 'tocolumnnm')) {
                            
                            $Msg = "$(" " * 8)Csv file must contain the following columns: FromDatabaseNM, FromSchemaNM, FromTableNM, FromColumnNM, ToDatabaseNM, ToSchemaNM, ToTableNM, ToColumnNM"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
                            Break;
                        }
                        
                        foreach ($Mapping in $Mappings) {
                            $Fqn = "$($Mapping.FromDatabaseNM.ToLower()).$($Mapping.FromSchemaNM.ToLower()).$($Mapping.FromTableNM.ToLower() -replace 'base$', '').$($Mapping.FromColumnNM.ToLower())"
                            $Index = $Columns.'$Fqn'.indexOf($Fqn)
                            if ($Index -gt -1) {
                                $AddMapping = New-Object PSObject
                                $AddMapping | Add-Member -Type NoteProperty -Name ToDatabaseNM -Value $Mapping.ToDatabaseNM
                                $AddMapping | Add-Member -Type NoteProperty -Name ToSchemaNM -Value $Mapping.ToSchemaNM
                                $AddMapping | Add-Member -Type NoteProperty -Name ToTableNM -Value $Mapping.ToTableNM
                                $AddMapping | Add-Member -Type NoteProperty -Name ToColumnNM -Value $Mapping.ToColumnNM
                                $Columns[$Index].'$Mappings' += $AddMapping
                            }
                        }
                        $Msg = "$(" " * 8)$(($Columns.'$Mappings' | Measure-Object).Count) columns assigned mappings"; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
                        
                        $MappingsFlag = $Columns | Where-Object { ($_.'$Mappings' | Measure-Object).Count -eq 0 } | Select-Object @{ n = 'FromDatabaseNM'; e = { $_.DatabaseNM } }, @{ n = 'FromSchemaNM'; e = { $_.SchemaNM } }, @{ n = 'FromTableNM'; e = { $_.TableNM } }, @{ n = 'FromColumnNM'; e = { $_.ColumnNM } }, ToDatabaseNM, ToSchemaNM, ToTableNM, ToColumnNM
                    }
                }
                #endregion
            }
            catch {
                $Msg = "$(" " * 4)Unable to parse the contents of ""$(Split-Path $ConfigPath -Leaf)"""; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
                $Msg = "$(" " * 4)$($Error[0])"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
                Break;
            }
        }
    }
    process {
        $Msg = "$(" " * 4)Parsing queries..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
        
        $ScriptStart = (Get-Date)
        
        $DataColumns = $Columns
        
        if ($MappingsFlag) {
            $DataMappings = @()
            foreach ($Column in $Columns) {
                foreach ($Mapping in $Column.'$Mappings') {
                    $ColumnMapping = New-Object PSObject
                    $ColumnMapping | Add-Member -Type NoteProperty -Name `$ColumnId -Value $Column.'$ColumnId'
                    $ColumnMapping | Add-Member -Type NoteProperty -Name ToDatabaseNM -Value $Mapping.ToDatabaseNM
                    $ColumnMapping | Add-Member -Type NoteProperty -Name ToSchemaNM -Value $Mapping.ToSchemaNM
                    $ColumnMapping | Add-Member -Type NoteProperty -Name ToTableNM -Value $Mapping.ToTableNM
                    $ColumnMapping | Add-Member -Type NoteProperty -Name ToColumnNM -Value $Mapping.ToColumnNM
                    $DataMappings += $ColumnMapping
                }
            }
        }
        
        try {
            $I = 0; $J = 0; $Total = ($Queries | Measure-Object).Count;
            $DataQueriesToColumns = @()
            $DataQueries = @()
            foreach ($Query in $Queries) {
                if ($I -eq 0) {
                    $Msg = "$(" " * 8)$(("{0:P0}" -f ($J/$Total)).PadLeft(5)) $($J.ToString().PadLeft($Total.ToString().Length))/$($Total) ...parsing..."; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
                }
                $Q = $True;
                $ParsedTables = $(Invoke-SqlParser -Query $Query.'$Query' -Log $False -SelectStar $False -Brackets $False)
                
                foreach ($ParsedTable in $ParsedTables) {
                    foreach ($ParsedColumn in $ParsedTable.Columns) {
                        $Fqn = "$($ParsedTable.FullyQualifiedNM.ToLower() -replace 'base$', '').$($ParsedColumn.ColumnNM.ToLower())"
                        $Index = $DataColumns.'$Fqn'.indexOf($Fqn)
                        if ($Index -gt -1) {
                            $Match = New-Object PSObject
                            $Match | Add-Member -Type NoteProperty -Name `$QueryId -Value $Query.'$QueryId'
                            $Match | Add-Member -Type NoteProperty -Name `$ColumnId -Value $DataColumns[$Index].'$ColumnId'
                            
                            $DataQueriesToColumns += $Match
                            if ($Q) {
                                $DataQueries += $Query;
                                $Q = $False;
                            }
                        }
                    }
                }
                $I++; $J++;
                if ($I -eq 100) { $I = 0; }
            }
            $ScriptEnd = (Get-Date)
            $RunTime = New-Timespan -Start $ScriptStart -End $ScriptEnd
            $Msg = "$(" " * 8)$(("{0:P0}" -f ($Total/$Total)).PadLeft(5)) $($Total)/$($Total) Done ~ $("Elapsed Time: {0}:{1}:{2}" -f $RunTime.Hours, $Runtime.Minutes, $RunTime.Seconds)"; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
        }
        catch {
            $Msg = "$(" " * 8)An error occurred during query parsing"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
            $Msg = "$(" " * 8)$($Error[0])"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
            Break;
        }
        
        foreach ($Column in $DataQueriesToColumns) {
            $IXColumn = $DataColumns.'$ColumnId'.IndexOf($Column.'$ColumnId')
            $IXQuery = $DataQueries.'$QueryId'.IndexOf($Column.'$QueryId')
            $QueryObj = New-Object PSObject; $QueryObj | Add-Member -Type NoteProperty -Name '$QueryId' -Value $DataQueries[$IXQuery].'$QueryId';
            $ColumnObj = New-Object PSObject; $ColumnObj | Add-Member -Type NoteProperty -Name '$ColumnId' -Value $DataColumns[$IXColumn].'$ColumnId';
            $DataColumns[$IXColumn].'$Queries' += $QueryObj;
            $DataQueries[$IXQuery].'$Columns' += $ColumnObj;
        }
        
        #region CSV files
        $Msg = "$(" " * 4)Creating output csv files..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
        try {
            $DataColumns | Select-Object * -ExcludeProperty '$Mappings', '$Queries' | Export-Csv -Path "$($OutDir)/raw/csv/columns.csv" -NoTypeInformation -Force
            $Msg = "$(" " * 8)File created ""$(Split-Path $OutDir -Leaf)/raw/csv/columns.csv"""; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
        }
        catch {
            $Msg = "$(" " * 8)Something failed when creating the ""$(Split-Path $OutDir -Leaf)/raw/csv/columns.csv"" files"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
        }
        
        try {
            $DataQueries | Select-Object * -ExcludeProperty '$Query', '$Columns' | Export-Csv -Path "$($OutDir)/raw/csv/queries.csv" -NoTypeInformation -Force
            $Msg = "$(" " * 8)File created ""$(Split-Path $OutDir -Leaf)/raw/csv/queries.csv"""; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
        }
        catch {
            $Msg = "$(" " * 8)Something failed when creating the ""$(Split-Path $OutDir -Leaf)/raw/csv/queries.csv"" files"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
        }
        
        try {
            $DataQueriesToColumns | Export-Csv -Path "$($OutDir)/raw/csv/queries-to-columns.csv" -NoTypeInformation -Force
            $Msg = "$(" " * 8)File created ""$(Split-Path $OutDir -Leaf)/raw/csv/queries-to-columns.csv"""; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
        }
        catch {
            $Msg = "$(" " * 8)Something failed when creating the ""$(Split-Path $OutDir -Leaf)/raw/csv/queries-to-columns.csv"" files"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
        }
        
        if ($MappingsFlag) {
            try {
                $DataMappings | Export-Csv -Path "$($OutDir)/raw/csv/mappings.csv" -NoTypeInformation -Force
                $Msg = "$(" " * 8)File created ""$(Split-Path $OutDir -Leaf)/raw/csv/mappings.csv"""; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
            }
            catch {
                $Msg = "$(" " * 8)Something failed when creating the ""$(Split-Path $OutDir -Leaf)/raw/csv/mappings.csv"" files"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
            }
            
            try {
                $MappingsFlag | Export-Csv -Path $OutDir/raw/csv/unmapped.csv -NoTypeInformation
                $Msg = "$(" " * 8)File created ""$(Split-Path $OutDir -Leaf)/raw/csv/unmapped.csv"""; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
            }
            catch {
                $Msg = "$(" " * 8)Something failed when creating the ""$(Split-Path $OutDir -Leaf)/raw/csv/unmapped.csv"" files"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
            }
        }
        #endregion
        #region JSON files
        $Msg = "$(" " * 4)Creating output json files..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
        try {
            $DataColumns | ConvertTo-Json -Depth 100 -Compress | Out-File "$($OutDir)/raw/json/columns.json" -Encoding Default -Force
            $Msg = "$(" " * 8)File created ""$(Split-Path $OutDir -Leaf)/raw/json/columns.json"""; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
        }
        catch {
            $Msg = "$(" " * 8)Something failed when creating the ""$(Split-Path $OutDir -Leaf)/raw/json/columns.json"" files"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
        }
        
        try {
            $DataQueries | ConvertTo-Json -Depth 100 -Compress | Out-File "$($OutDir)/raw/json/queries.json" -Encoding Default -Force
            $Msg = "$(" " * 8)File created ""$(Split-Path $OutDir -Leaf)/raw/json/queries.json"""; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
        }
        catch {
            $Msg = "$(" " * 8)Something failed when creating the ""$(Split-Path $OutDir -Leaf)/raw/json/queries.json"" files"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
        }
        
        if ($MappingsFlag) {
            try {
                $MappingsFlag | ConvertTo-Json -Depth 100 -Compress | Out-File $OutDir/raw/json/unmapped.json -Encoding Default -Force
                $Msg = "$(" " * 8)File created ""$(Split-Path $OutDir -Leaf)/raw/json/unmapped.json"""; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
            }
            catch {
                $Msg = "$(" " * 8)Something failed when creating the ""$(Split-Path $OutDir -Leaf)/raw/json/unmapped.json"" files"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
            }
        }
        #endregion
    }
    end {
        $Msg = "Success!`r`n"; Write-Host $Msg -ForegroundColor Green; Write-Verbose $Msg; Write-Log $Msg;
    }
}
