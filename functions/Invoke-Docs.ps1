function Invoke-Docs {
    param
    (
        [Parameter(Mandatory = $True)]
        [psobject]$DocsData,
        [Parameter(Mandatory = $True)]
        [string]$OutDir,
        [switch]$OutZip
    )
    begin {
        #remove inactive bindings and non-dataentry entities without bindings
        foreach ($Entity in $DocsData.Entities) {
            $Bindings = @();
            foreach ($Binding in $Entity.Bindings) {
                if ($Binding.BindingStatus -eq 'Active') {
                    $Bindings += $Binding
                }
            }
            $Entity.Bindings = $Bindings;
            
            if ($Entity.ClassificationCode -ne 'DataEntry' -and ($Entity.Bindings | Measure-Object).Count -eq 0) {
                $DocsData.Entities = $DocsData.Entities | Where-Object { $_ -ne $DocsData.Entities[$DocsData.Entities.ContentId.IndexOf($Entity.ContentId)] }
            }
        }
        $validPublicEntities = { !($_.IsOverridden) -and $_.IsPublic -and (@('Summary', 'Generic') -contains $_.ClassificationCode) }
    }
    process {
        $Msg = "DOCS - $($DocsData._hcposh.FileBaseName)"; Write-Host $Msg -ForegroundColor Magenta; Write-Verbose $Msg; Write-Log $Msg;
        #region ADD LINEAGE
        try {
            $Msg = "$(" " * 4)Adding entity data lineage..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
            foreach ($Entity in $DocsData.Entities) {
                $Entity | Add-Member -Type NoteProperty -Name Lineage -Value @()
                $Entity.Lineage = New-Nodes -entity $Entity
            }
        }
        catch {
            $Msg = "$(" " * 8)Unable to add data lineage properties"; Write-Host $Msg -ForegroundColor Yellow; Write-Verbose $Msg; Write-Log $Msg 'warning';
            $Msg = "$(" " * 8)$($Error[0])"; Write-Host $Msg -ForegroundColor Yellow; Write-Verbose $Msg; Write-Log $Msg 'warning';
        }
        #endregion
        #region ADD DIAGRAMS
        $DocsData | Add-Member -Type NoteProperty -Name Diagrams -Value (New-Object PSObject -Property @{ Erd = $Null; Dfd = $Null; DfdUpstream = $Null; DfdDownstream = $Null })
        #region ERD
        try {
            $Msg = "$(" " * 4)Adding erd diagram..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
            $DocsData.Diagrams.Erd = (New-Erd -DocsData $DocsData).Erd
            
            if (!$KeepFullLineage) {
                #Remove un-needed properties
                if (($DocsData.Diagrams.Erd.PSobject.Properties.Name -match 'Data')) {
                    $DocsData.Diagrams.Erd.PSObject.Properties.Remove('Data')
                }
            }							
        }
        catch {
            $Msg = "$(" " * 8)Unable to add erd diagram"; Write-Host $Msg -ForegroundColor Yellow; Write-Verbose $Msg; Write-Log $Msg 'warning';
        }
        #endregion
        #region DFD
        $Msg = "$(" " * 4)Adding dfd diagrams..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
        try {
            $DocsData.Diagrams.Dfd = (New-Dfd -Name $DocsData.DatamartNM -Lineage ($DocsData.Entities | Where-Object $validPublicEntities).Lineage -Type Both).Dfd
            $DocsData.Diagrams.DfdUpstream = (New-Dfd -Name $DocsData.DatamartNM -Lineage ($DocsData.Entities | Where-Object $validPublicEntities).Lineage -Type Upstream).Dfd
            $DocsData.Diagrams.DfdDownstream = (New-Dfd -Name $DocsData.DatamartNM -Lineage ($DocsData.Entities | Where-Object $validPublicEntities).Lineage -Type Downstream).Dfd
            
            if (!$KeepFullLineage) {
                #Remove un-needed properties
                if (($DocsData.Diagrams.Dfd.PSobject.Properties.Name -match 'Data')) {
                    $DocsData.Diagrams.Dfd.PSObject.Properties.Remove('Data')
                }
                if (($DocsData.Diagrams.DfdUpstream.PSobject.Properties.Name -match 'Data')) {
                    $DocsData.Diagrams.DfdUpstream.PSObject.Properties.Remove('Data')
                }
                if (($DocsData.Diagrams.DfdDownstream.PSobject.Properties.Name -match 'Data')) {
                    $DocsData.Diagrams.DfdDownstream.PSObject.Properties.Remove('Data')
                }
            }							
            
            #ADD DFD DIAGRAM TO EVERY PUBLIC ENTITY
            forEach ($PublicEntity in $DocsData.Entities | Where-Object $validPublicEntities) {
                if ($PublicEntity.SourcedByEntities) {
                    $PublicEntity | Add-Member -Type NoteProperty -Name Diagrams -Value (New-Object PSObject -Property @{ Dfd = $Null; DfdUpstream = $Null; DfdDownstream = $Null })
                    $Msg = "$(" " * 4)Adding dfd diagrams...$($PublicEntity.FullyQualifiedNames.Table)..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
                    $PublicEntity.Diagrams.Dfd = (New-Dfd -Name $PublicEntity.FullyQualifiedNames.Table -Lineage $PublicEntity.Lineage -Type Both).Dfd
                    $PublicEntity.Diagrams.DfdDownstream = (New-Dfd -Name $PublicEntity.FullyQualifiedNames.Table -Lineage $PublicEntity.Lineage -Type Downstream).Dfd
                    $PublicEntity.Diagrams.DfdUpstream = (New-Dfd -Name $PublicEntity.FullyQualifiedNames.Table -Lineage $PublicEntity.Lineage -Type Upstream).Dfd
                }
            }
        }
        catch {
            $Msg = "$(" " * 8)Requirements not met for dfd diagrams:`n$(" " * 10)At least 1 public ""summary"" entity for Framework SAM or 1 public entity in Generic SAM"; Write-Host $Msg -ForegroundColor Yellow; Write-Verbose $Msg; Write-Log $Msg 'warning';
        }
        
        #Replace Lineage property with a cleaner version for display purposes
        forEach ($Entity in $DocsData.Entities | Where-Object $validPublicEntities) {
            $Upstream = Get-LineageCollection -Lineage $Entity.Lineage.Upstream -DocsData $DocsData;
            $Downstream = New-Object PSObject;
            if ($($Entity.Lineage.Downstream | Where-Object Level -NE 0)) {
                $Downstream = Get-LineageCollection -Lineage $($Entity.Lineage.Downstream | Where-Object Level -NE 0) -DocsData $DocsData;
            }
            $Entity | Add-Member -Type NoteProperty -Name LineageMinimal -Value (
                New-Object PSObject -Property @{
                    Upstream   = $Upstream;
                    Downstream = $Downstream;
                }
            )
        }
        if (!$KeepFullLineage) {
            forEach ($Entity in $DocsData.Entities) {
                if (($Entity.PSobject.Properties.Name -match 'Lineage')) {
                    $Entity.PSObject.Properties.Remove('Lineage')
                }
            }
        }
        
        #endregion						
        #endregion
        #region ADD COUNT DETAILS
        $Sources = New-Object PSObject
        $Sources | Add-Member -Type NoteProperty -Name DelimitedList -Value (($DocsData.SourcedByEntities | Where-Object { $_.TableOrigin -eq 'External' -and $_.DatabaseNM -notin @('Shared', 'IDEA') } | Group-Object DatabaseNM).Name -join ', ');
        $Sources | Add-Member -Type NoteProperty -Name List -Value ($DocsData.SourcedByEntities | Where-Object { $_.TableOrigin -eq 'External' -and $_.DatabaseNM -notin @('Shared', 'IDEA') } | Group-Object DatabaseNM | Select-Object Name).Name;
        $Sources | Add-Member -Type NoteProperty -Name Count -Value (($DocsData.SourcedByEntities | Where-Object { $_.TableOrigin -eq 'External' -and $_.DatabaseNM -notin @('Shared', 'IDEA') } | Group-Object DatabaseNM | Measure-Object).Count);
        $Sources | Add-Member -Type NoteProperty -Name EntitiesCount -Value (($DocsData.SourcedByEntities | Where-Object { $_.TableOrigin -eq 'External' -and $_.DatabaseNM -notin @('Shared', 'IDEA') } | Measure-Object).Count);
        
        $Entities = New-Object PSObject
        $Entities | Add-Member -Type NoteProperty -Name Count -Value ($DocsData.Entities | Measure-Object).Count;
        $Entities | Add-Member -Type NoteProperty -Name PersistedCount -Value ($DocsData.Entities | Where-Object { $_.IsPersisted } | Measure-Object).Count;
        $Entities | Add-Member -Type NoteProperty -Name NonPersistedCount -Value ($DocsData.Entities | Where-Object { !($_.IsPersisted) } | Measure-Object).Count;
        $Entities | Add-Member -Type NoteProperty -Name ProtectedCount -Value ($DocsData.Entities | Where-Object { $_.IsProtected } | Measure-Object).Count;
        $Entities | Add-Member -Type NoteProperty -Name PublicCount -Value ($DocsData.Entities | Where-Object { $_.IsPublic } | Measure-Object).Count;
        
        $Columns = New-Object PSObject
        $Columns | Add-Member -Type NoteProperty -Name PublicCount -Value (($DocsData.Entities | Where-Object { $_.IsPublic }).Columns | Measure-Object).Count;
        $Columns | Add-Member -Type NoteProperty -Name ExtendedCount -Value (($DocsData.Entities | Where-Object { $_.IsPublic }).Columns | Where-Object { $_.IsExtended } | Measure-Object).Count;
        
        $Bindings = New-Object PSObject
        $Bindings | Add-Member -Type NoteProperty -Name Count -Value ($DocsData.Entities.Bindings | Where-Object { $_.BindingStatus -eq 'Active' } | Measure-Object).Count;
        $Bindings | Add-Member -Type NoteProperty -Name ProtectedCount -Value ($DocsData.Entities.Bindings | Where-Object { $_.BindingStatus -eq 'Active' -and $_.IsProtected } | Measure-Object).Count;
        $Bindings | Add-Member -Type NoteProperty -Name FullCount -Value ($DocsData.Entities.Bindings | Where-Object { $_.LoadType -eq 'Full' -and $_.BindingStatus -eq 'Active' } | Measure-Object).Count;
        $Bindings | Add-Member -Type NoteProperty -Name IncrementalCount -Value ($DocsData.Entities.Bindings | Where-Object { $_.LoadType -eq 'Incremental' -and $_.BindingStatus -eq 'Active' } | Measure-Object).Count;
        
        $Indexes = New-Object PSObject
        $Indexes | Add-Member -Type NoteProperty -Name ClusteredCount -Value ($DocsData.Entities.Indexes | Where-Object { $_.IndexTypeCode -eq 'Clustered' -and $_.IsActive } | Measure-Object).Count;
        $Indexes | Add-Member -Type NoteProperty -Name NonClusteredCount -Value ($DocsData.Entities.Indexes | Where-Object { $_.IndexTypeCode -eq 'Non-Clustered' -and $_.IsActive } | Measure-Object).Count;
        
        $Counts = New-Object PSObject
        $Counts | Add-Member -Type NoteProperty -Name Sources -Value $Sources;
        $Counts | Add-Member -Type NoteProperty -Name Entities -Value $Entities;
        $Counts | Add-Member -Type NoteProperty -Name Columns -Value $Columns;
        $Counts | Add-Member -Type NoteProperty -Name Bindings -Value $Bindings;
        $Counts | Add-Member -Type NoteProperty -Name Indexes -Value $Indexes;
        
        $DocsData | Add-Member -Type NoteProperty -Name Counts -Value $Counts;
        #endregion
        #region REMOVE DATA_ALL PROPERTY (UNECESSARY FOR DOCS)
        foreach ($Entity in $DocsData.Entities) {
            if ($Entity.DataEntryData) {
                if ($Entity.DataEntryData.Data_All) {
                    $Entity.DataEntryData.PSObject.Properties.Remove('Data_All')
                }
            }
        }
        #endregion
        
        $DocsData._hcposh.LastWriteTime = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.ffffff")
        
        #Directories
        $DataDir = "$($OutDir)\static\data"; New-Directory -Dir $DataDir;
        
        #Files
        $DocsSourcePath = "$((Get-Item $PSScriptRoot).Parent.FullName)\templates\docs\*";
        $DocsDestinationPath = $OutDir;
        $DataFilePath = "$($DataDir)\dataMart.js";
        try {
            if (($DocsData.Entities | Where-Object $validPublicEntities | Measure-Object).Count -eq 0) { throw; }
            Copy-Item -Path $DocsSourcePath -Recurse -Destination $DocsDestinationPath -Force
            'dataMart = ' + ($DocsData | ConvertTo-Json -Depth 100 -Compress) | Out-File $DataFilePath -Encoding Default -Force | Out-Null
            $Msg = "$(" " * 4)Created new file --> $($DocsData._hcposh.FileBaseName)\$(Split-Path $DataDir -Leaf)\$(Split-Path $DataFilePath -Leaf)."; Write-Host $Msg -ForegroundColor Cyan; Write-Verbose $Msg; Write-Log $Msg;
        }
        catch {
            $Msg = "$(" " * 4)Unable to find valid public entities or An error occurred when trying to create the docs folder structure"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
        }
        if ($OutZip) {
            try {
                Zip -Directory $DocsDestinationPath -Destination ($DocsDestinationPath + '_docs.zip')
                if (Test-Path $DocsDestinationPath) {
                    Remove-Item $DocsDestinationPath -Recurse -Force | Out-Null
                }
                $Msg = "$(" " * 4)Zipped file of directory --> $($DocsDestinationPath + '_docs.zip')"; Write-Host $Msg -ForegroundColor Cyan; Write-Verbose $Msg; Write-Log $Msg;
            }
            catch {
                $Msg = "$(" " * 4)Unable to zip the docs directory"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
            }
        }
        $Msg = "Success!`r`n"; Write-Host $Msg -ForegroundColor Green; Write-Verbose $Msg; Write-Log $Msg;
        $Output = New-Object PSObject
        $Output | Add-Member -Type NoteProperty -Name DocsData -Value $DocsData
        return $Output
    }
}