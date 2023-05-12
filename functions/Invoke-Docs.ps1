function Invoke-Docs {
    param
    (
        [Parameter(Mandatory = $True)]
        [psobject]$Data,
        [Parameter(Mandatory = $True)]
        [string]$OutDir,
        [switch]$OutZip
    )
    begin {
        # Get function definition files.
        $Functions = @( Get-ChildItem -Path "$PSScriptRoot\docs" -Filter *.ps1 -ErrorAction SilentlyContinue )

        # Dot source the files
        foreach ($Import in @($Functions)) {
            try {
                . $Import.fullname
            }
            catch {
                Write-Error -Message "Failed to import function $($Import.fullname): $_"
            }
        }

        #remove inactive bindings and non-dataentry entities without bindings
        foreach ($Entity in $Data.Entities) {
            $Bindings = @();
            foreach ($Binding in $Entity.Bindings) {
                if ($Binding.BindingStatus -eq 'Active') {
                    $Bindings += $Binding
                }
            }
            $Entity.Bindings = $Bindings;
							
            if ($Entity.ClassificationCode -ne 'DataEntry' -and ($Entity.Bindings | Measure-Object).Count -eq 0) {
                #if the entity doesn't have any bindings, exclude it.

                #we create a new array and use a foreach loop because if there is only one entity remaining and we use powershell piping
                #  the $Data.Entities array will transform to a PSCustomObject, which breaks the javascript code because the javascript
                #  is expecting an array, not a single PSCustomObject.
                $newEntitiesArray = @()
                $entitiesToKeep = $Data.Entities | Where-Object { $_ -ne $Data.Entities[$Data.Entities.ContentId.IndexOf($Entity.ContentId)] }
                foreach($tempEntity in $entitiesToKeep){
                    $newEntitiesArray += $tempEntity
                }
                #$Data.Entities = $Data.Entities | Where-Object { $_ -ne $Data.Entities[$Data.Entities.ContentId.IndexOf($Entity.ContentId)] }
                $Data.Entities = $newEntitiesArray
            }
        }
        
        $Filters = Get-EntityFilterCriteria;
        $FilteredEntities = (Invoke-Expression $Filters.PowerShell);
                                       
        function Get-Entity ($ContentId) {
            return $Data.Entities[$Data.Entities.ContentId.IndexOf($ContentId)]
        }
    }
    process {
        $Msg = "DOCS - $($Data._hcposh.FileBaseName)"; Write-Host $Msg -ForegroundColor Magenta; Write-Verbose $Msg; Write-Log $Msg;
        #region ADD LINEAGE
        try {
            $Msg = "$(" " * 4)Adding entity data lineage..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
            foreach ($Entity in $Data.Entities) {
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
        $Data | Add-Member -Type NoteProperty -Name Diagrams -Value (New-Object PSObject -Property @{ Erd = $Null; Dfd = $Null; DfdUpstream = $Null; DfdDownstream = $Null })
        #region ERD
        try {
            $Msg = "$(" " * 4)Adding erd diagram..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
            $Data.Diagrams.Erd = (New-Erd -Data $Data).Erd
							
            if (!$KeepFullLineage) {
                #Remove un-needed properties
                if (($Data.Diagrams.Erd.PSobject.Properties.Name -match 'Data')) {
                    $Data.Diagrams.Erd.PSObject.Properties.Remove('Data')
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
            $Data.Diagrams.Dfd = (New-Dfd -Name $Data.DatamartNM -Lineage ($Data.Entities | Where-Object $FilteredEntities).Lineage -Type Both).Dfd
            $Data.Diagrams.DfdUpstream = (New-Dfd -Name $Data.DatamartNM -Lineage ($Data.Entities | Where-Object $FilteredEntities).Lineage -Type Upstream).Dfd
            $Data.Diagrams.DfdDownstream = (New-Dfd -Name $Data.DatamartNM -Lineage ($Data.Entities | Where-Object $FilteredEntities).Lineage -Type Downstream).Dfd
							
            if (!$KeepFullLineage) {
                #Remove un-needed properties
                if (($Data.Diagrams.Dfd.PSobject.Properties.Name -match 'Data')) {
                    $Data.Diagrams.Dfd.PSObject.Properties.Remove('Data')
                }
                if (($Data.Diagrams.DfdUpstream.PSobject.Properties.Name -match 'Data')) {
                    $Data.Diagrams.DfdUpstream.PSObject.Properties.Remove('Data')
                }
                if (($Data.Diagrams.DfdDownstream.PSobject.Properties.Name -match 'Data')) {
                    $Data.Diagrams.DfdDownstream.PSObject.Properties.Remove('Data')
                }
            }							
							
            #ADD DFD DIAGRAM TO EVERY PUBLIC ENTITY
            forEach ($Entity in $Data.Entities | Where-Object $FilteredEntities) {
                if ($Entity.SourcedByEntities) {
                    $Entity | Add-Member -Type NoteProperty -Name Diagrams -Value (New-Object PSObject -Property @{ Dfd = $Null; DfdUpstream = $Null; DfdDownstream = $Null })
                    $Msg = "$(" " * 4)Adding dfd diagrams...$($Entity.FullyQualifiedNames.Table)..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
                    $Entity.Diagrams.Dfd = (New-Dfd -Name $Entity.FullyQualifiedNames.Table -Lineage $Entity.Lineage -Type Both).Dfd
                    $Entity.Diagrams.DfdDownstream = (New-Dfd -Name $Entity.FullyQualifiedNames.Table -Lineage $Entity.Lineage -Type Downstream).Dfd
                    $Entity.Diagrams.DfdUpstream = (New-Dfd -Name $Entity.FullyQualifiedNames.Table -Lineage $Entity.Lineage -Type Upstream).Dfd
                }
            }
        }
        catch {
            $Msg = "$(" " * 8)Requirements not met for dfd diagrams:`n$(" " * 10)At least 1 public ""summary"" entity for Framework SAM or 1 public entity in Generic SAM"; Write-Host $Msg -ForegroundColor Yellow; Write-Verbose $Msg; Write-Log $Msg 'warning';
        }
						
        #Replace Lineage property with a cleaner version for display purposes
        forEach ($Entity in $Data.Entities | Where-Object $FilteredEntities) {
            $Upstream = Get-LineageCollection -Lineage $Entity.Lineage.Upstream -Data $Data;
            $Downstream = New-Object PSObject;
            if ($($Entity.Lineage.Downstream | Where-Object Level -NE 0)) {
                $Downstream = Get-LineageCollection -Lineage $($Entity.Lineage.Downstream | Where-Object Level -NE 0) -Data $Data;
            }
            $Entity | Add-Member -Type NoteProperty -Name LineageMinimal -Value (
                New-Object PSObject -Property @{
                    Upstream   = $Upstream;
                    Downstream = $Downstream;
                }
            )
        }
        if (!$KeepFullLineage) {
            forEach ($Entity in $Data.Entities) {
                if (($Entity.PSobject.Properties.Name -match 'Lineage')) {
                    $Entity.PSObject.Properties.Remove('Lineage')
                }
            }
        }
						
        #endregion						
        #endregion
        #region ADD DYNAMIC ENTITY FILTER LOGIC
         $Data | Add-Member -Type NoteProperty -Name EntityFilterCriteria -Value $Filters.JavaScript;
        #endregion
        #region ADD COUNT DETAILS
        $Sources = New-Object PSObject
        $Sources | Add-Member -Type NoteProperty -Name DelimitedList -Value (($Data.SourcedByEntities | Where-Object { $_.TableOrigin -eq 'External' -and $_.DatabaseNM -notin @('Shared', 'IDEA') } | Group-Object DatabaseNM).Name -join ', ');
        $Sources | Add-Member -Type NoteProperty -Name List -Value ($Data.SourcedByEntities | Where-Object { $_.TableOrigin -eq 'External' -and $_.DatabaseNM -notin @('Shared', 'IDEA') } | Group-Object DatabaseNM | Select-Object Name).Name;
        $Sources | Add-Member -Type NoteProperty -Name Count -Value (($Data.SourcedByEntities | Where-Object { $_.TableOrigin -eq 'External' -and $_.DatabaseNM -notin @('Shared', 'IDEA') } | Group-Object DatabaseNM | Measure-Object).Count);
        $Sources | Add-Member -Type NoteProperty -Name EntitiesCount -Value (($Data.SourcedByEntities | Where-Object { $_.TableOrigin -eq 'External' -and $_.DatabaseNM -notin @('Shared', 'IDEA') } | Measure-Object).Count);
						
        $Entities = New-Object PSObject
        $Entities | Add-Member -Type NoteProperty -Name Count -Value ($Data.Entities | Measure-Object).Count;
        $Entities | Add-Member -Type NoteProperty -Name PersistedCount -Value ($Data.Entities | Where-Object { $_.IsPersisted } | Measure-Object).Count;
        $Entities | Add-Member -Type NoteProperty -Name NonPersistedCount -Value ($Data.Entities | Where-Object { !($_.IsPersisted) } | Measure-Object).Count;
        $Entities | Add-Member -Type NoteProperty -Name ProtectedCount -Value ($Data.Entities | Where-Object { $_.IsProtected } | Measure-Object).Count;
        $Entities | Add-Member -Type NoteProperty -Name PublicCount -Value ($Data.Entities | Where-Object { $_.IsPublic } | Measure-Object).Count;
						
        $Columns = New-Object PSObject
        $Columns | Add-Member -Type NoteProperty -Name PublicCount -Value (($Data.Entities | Where-Object { $_.IsPublic }).Columns | Measure-Object).Count;
        $Columns | Add-Member -Type NoteProperty -Name ExtendedCount -Value (($Data.Entities | Where-Object { $_.IsPublic }).Columns | Where-Object { $_.IsExtended } | Measure-Object).Count;
						
        $Bindings = New-Object PSObject
        $Bindings | Add-Member -Type NoteProperty -Name Count -Value ($Data.Entities.Bindings | Where-Object { $_.BindingStatus -eq 'Active' } | Measure-Object).Count;
        $Bindings | Add-Member -Type NoteProperty -Name ProtectedCount -Value ($Data.Entities.Bindings | Where-Object { $_.BindingStatus -eq 'Active' -and $_.IsProtected } | Measure-Object).Count;
        $Bindings | Add-Member -Type NoteProperty -Name FullCount -Value ($Data.Entities.Bindings | Where-Object { $_.LoadType -eq 'Full' -and $_.BindingStatus -eq 'Active' } | Measure-Object).Count;
        $Bindings | Add-Member -Type NoteProperty -Name IncrementalCount -Value ($Data.Entities.Bindings | Where-Object { $_.LoadType -eq 'Incremental' -and $_.BindingStatus -eq 'Active' } | Measure-Object).Count;
						
        $Indexes = New-Object PSObject
        $Indexes | Add-Member -Type NoteProperty -Name ClusteredCount -Value ($Data.Entities.Indexes | Where-Object { $_.IndexTypeCode -eq 'Clustered' -and $_.IsActive } | Measure-Object).Count;
        $Indexes | Add-Member -Type NoteProperty -Name NonClusteredCount -Value ($Data.Entities.Indexes | Where-Object { $_.IndexTypeCode -eq 'Non-Clustered' -and $_.IsActive } | Measure-Object).Count;
						
        $Counts = New-Object PSObject
        $Counts | Add-Member -Type NoteProperty -Name Sources -Value $Sources;
        $Counts | Add-Member -Type NoteProperty -Name Entities -Value $Entities;
        $Counts | Add-Member -Type NoteProperty -Name Columns -Value $Columns;
        $Counts | Add-Member -Type NoteProperty -Name Bindings -Value $Bindings;
        $Counts | Add-Member -Type NoteProperty -Name Indexes -Value $Indexes;
						
        $Data | Add-Member -Type NoteProperty -Name Counts -Value $Counts;
        #endregion
        #region REMOVE DATA_ALL PROPERTY (UNECESSARY FOR DOCS)
        foreach ($Entity in $Data.Entities) {
            if ($Entity.DataEntryData) {
                if ($Entity.DataEntryData.Data_All) {
                    $Entity.DataEntryData.PSObject.Properties.Remove('Data_All')
                }
            }
        }
        #endregion
						
        $Data._hcposh.LastWriteTime = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.ffffff")
						
        #Directories
        $DataDir = "$($OutDir)\static\data"; New-Directory -Dir $DataDir;
						
        #Files
        $DocsSourcePath = "$((Get-Item $PSScriptRoot).Parent.FullName)\templates\docs\*";
        $DocsDestinationPath = $OutDir;
        $DataFilePath = "$($DataDir)\dataMart.js";
        try {
            $Msg = "$(" " * 4)Entity Count: $(($Data.Entities | Where-Object $FilteredEntities | Measure-Object).Count)"; Write-Host $Msg -ForegroundColor Cyan; Write-Verbose $Msg; Write-Log $Msg;
            if (($Data.Entities | Where-Object $FilteredEntities | Measure-Object).Count -eq 0) { throw; }
            Copy-Item -Path $DocsSourcePath -Recurse -Destination $DocsDestinationPath -Force
            'dataMart = ' + ($Data | ConvertTo-Json -Depth 100 -Compress) | Out-File $DataFilePath -Encoding Default -Force | Out-Null
            $Msg = "$(" " * 4)Created new file --> $($Data._hcposh.FileBaseName)\$(Split-Path $DataDir -Leaf)\$(Split-Path $DataFilePath -Leaf)."; Write-Host $Msg -ForegroundColor Cyan; Write-Verbose $Msg; Write-Log $Msg;
        }
        catch {
            $Msg = "$(" " * 4)Unable to find valid public entities or An error occurred when trying to create the docs folder structure"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
            throw "$(" " * 4)Unable to find valid public entities or An error occurred when trying to create the docs folder structure"
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
        $Output | Add-Member -Type NoteProperty -Name DocsData -Value $Data
        return $Output
    }
}