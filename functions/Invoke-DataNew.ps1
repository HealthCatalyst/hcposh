function Invoke-DataNew {
    [CmdletBinding()]
    [OutputType([PSObject])]
    param
    (
        [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName)]
        [psobject]$MetadataRaw,
        [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName)]
        [string]$OutDir
    )
    process {
        #$OutDirFilePath = "$($OutDir)\metadata_new.json"
        $SplitDirectory = "$($OutDir)\Datamart"
        
        $Msg = "$(" " * 4)Creating new $(($MetadataRaw.DatamartNM).ToLower()) object..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
        $MetadataNew = New-HCEmptyDatamartObject
        
        #region DATAMART
        $MetadataNew.ContentId = $MetadataRaw.ContentId
        $MetadataNew.DatamartNM = $MetadataRaw.DatamartNM
        $MetadataNew.DatamartNoSpacesNM = (Get-CleanFileName -Name $MetadataRaw.DatamartNM -RemoveSpace)
        $MetadataNew.DataMartTypeDSC = $MetadataRaw.DataMartTypeDSC
        $MetadataNew.DescriptionTXT = $MetadataRaw.DescriptionTXT
        $MetadataNew.DestinationDatabaseName = $MetadataRaw.DestinationDatabaseName
        $MetadataNew.DestinationObjectPrefix = $MetadataRaw.DestinationObjectPrefix
        $MetadataNew.DestinationSchemaName = $MetadataRaw.DestinationSchemaName
        $MetadataNew.SamTypeCode = $MetadataRaw.SamTypeCode
        $MetadataNew.Status = $MetadataRaw.Status
        $MetadataNew.VersionText = $MetadataRaw.VersionText
        $MetadataNew.SAMDVersionText<#extension#> = $MetadataRaw.SAMDVersionText
        $MetadataNew._hcposh<#extension#> = $MetadataRaw._hcposh
        #endregion
        
        #region ENTITIES        
        foreach ($Entity in $MetadataRaw.Tables.GetEnumerator()) {
            $HCEntity = New-HCEmptyEntityObject
            #region GENERAL PROPS
            $HCEntity.ContentId = $Entity.ContentId
            $HCEntity.DescriptionTXT = $Entity.DescriptionTXT
            $HCEntity.DatabaseNM = $Entity.DatabaseNM
            $HCEntity.SchemaNM = $Entity.SchemaNM
            $HCEntity.TableNM = $Entity.TableNM
            $HCEntity.TableTypeNM = $Entity.TableTypeNM
            $HCEntity.ViewName = $Entity.ViewName
            $HCEntity.LoadType = $Entity.LoadType
            $HCEntity.LastModifiedTimestamp = $Entity.LastModifiedTimestamp
            $HCEntity.IsPersisted = $Entity.IsPersisted
            $HCEntity.IsPublic = $Entity.IsPublic
            $IsUniversal = $Entity.AttributeValues | Where-Object AttributeName -eq 'IsUniversal'
            if ($IsUniversal) {
                $HCEntity | Add-Member -Type NoteProperty -Name IsUniversal -Value $([System.Convert]::ToBoolean($IsUniversal.TextValue))
            }
            #endregion
            #region PROTECTION PROPS
            $IsProtected = $Entity.AttributeValues | Where-Object AttributeName -eq 'IsProtected'
            if ($IsProtected) {
                #New attributes introduced with CAP 4.0
                $HCEntity | Add-Member -Type NoteProperty -Name IsProtected -Value $([System.Convert]::ToBoolean($IsProtected.TextValue))
            }
            #endregion
            #region FULLYQUALIFIEDNAME PROPS
            $HCFullyQualifiedName = New-HCEmptyFullyQualifiedNameObject
            $HCFullyQualifiedName.Table = "$($Entity.DatabaseNM).$($Entity.SchemaNM).$($Entity.TableNM)"
            $HCFullyQualifiedName.View = "$($Entity.DatabaseNM).$($Entity.SchemaNM).$($Entity.ViewName)"
            $HCEntity.FullyQualifiedNames = $HCFullyQualifiedName
            #endregion
            #region COLUMN PROPS
            foreach ($Column in $Entity.Columns.GetEnumerator()) {
                $HCColumn = New-HCEmptyColumnObject
                $HCColumn.ContentId = $Column.ContentId
                $HCColumn.ColumnNM = $Column.ColumnNM
                $HCColumn.DataSensitivityCD = $Column.DataSensitivityCD
                $HCColumn.DataTypeDSC = $Column.DataTypeDSC
                $HCColumn.DescriptionTXT = $Column.DescriptionTXT
                $HCColumn.IsIncrementalColumnValue = $Column.IsIncrementalColumnValue
                $HCColumn.IsSystemColumnValue = $Column.IsSystemColumnValue
                $HCColumn.IsNullableValue = $Column.IsNullableValue
                $HCColumn.IsPrimaryKeyValue = $Column.IsPrimaryKeyValue
                $HCColumn.Ordinal = $Column.Ordinal
                $HCColumn.Status = $Column.Status
                $HCEntity.Columns += $HCColumn
            }
            #endregion
            #region INDEX PROPS
            foreach ($Index in $Entity.Indexes.GetEnumerator()) {
                $HCIndex = New-HCEmptyIndexObject
                $HCIndex.IndexName = $Index.IndexName
                $HCIndex.IndexTypeCode = $Index.IndexTypeCode
                $HCIndex.IsActive = $Index.IsActive
                    
                foreach ($IndexColumn in $Index.IndexColumns.GetEnumerator()) {
                    $HCIndexColumn = New-HCEmptyIndexColumnObject
                    $HCIndexColumn.Ordinal = $IndexColumn.Ordinal
                    $HCIndexColumn.ColumnNM = $IndexColumn.Column.ColumnNM
                    $HCIndexColumn.IsCovering = $IndexColumn.IsCovering
                    $HCIndexColumn.IsDescending = $IndexColumn.IsDescending                        
                    $HCIndex.IndexColumns += $HCIndexColumn
                }
                    
                $HCEntity.Indexes += $HCIndex
            }
            #endregion
            #region BINDING PROPS
            foreach ($Binding in $Entity.FedByBindings.GetEnumerator()) {
                $HCBinding = New-HCEmptyBindingObject
                $HCBinding.ContentId = $Binding.ContentId
                $HCBinding.BindingName = $Binding.BindingName
                $HCBinding.BindingNameNoSpaces = (Get-CleanFileName -Name $Binding.BindingName -RemoveSpace)
                $HCBinding.BindingStatus = $Binding.BindingStatus
                $HCBinding.BindingDescription = $Binding.BindingDescription
                $HCBinding.ClassificationCode = $Binding.ClassificationCode
                $HCBinding.GrainName = $Binding.GrainName
                $HCBinding.UserDefinedSQL = $Binding.UserDefinedSQL
                #New attributes introduced with CAP 4.0
                $IsProtected = $Binding.AttributeValues | Where-Object AttributeName -eq 'IsProtected'
                if ($IsProtected) {
                    $HCBinding | Add-Member -Type NoteProperty -Name IsProtected -Value $([System.Convert]::ToBoolean($IsProtected.TextValue))
                }
                $LoadType = if ($Binding.LoadType) { $Binding.LoadType } else { $HCEntity.LoadType }
                if ($LoadType) {
                    $HCBinding | Add-Member -Type NoteProperty -Name LoadType -Value $LoadType
                        
                    if ($Binding.IncrementalConfigurations) {
                        $HCBinding | Add-Member -Type NoteProperty -Name IncrementalConfigurations -Value @()
                            
                        foreach ($IncrementalConfiguration in $Binding.IncrementalConfigurations.GetEnumerator()) {
                            $HCIncrementalConfiguration = New-HCEmptyIncrementalConfigurationObject
                            $HCIncrementalConfiguration.IncrementalColumnName = $IncrementalConfiguration.IncrementalColumnName
                            $HCIncrementalConfiguration.OverlapNumber = $IncrementalConfiguration.OverlapNumber
                            $HCIncrementalConfiguration.OverlapType = $IncrementalConfiguration.OverlapType
                            $HCIncrementalConfiguration.SourceDatabaseName = $IncrementalConfiguration.SourceDatabaseName
                            $HCIncrementalConfiguration.SourceSchemaName = $IncrementalConfiguration.SourceSchemaName
                            $HCIncrementalConfiguration.SourceTableAlias = $IncrementalConfiguration.SourceTableAlias
                            $HCIncrementalConfiguration.SourceTableName = $IncrementalConfiguration.SourceTableName
                                
                            $HCBinding.IncrementalConfigurations += $HCIncrementalConfiguration
                        }
                    }
                }
                $HCEntity.Bindings += $HCBinding
            }
            #endregion
            #region EXTENSION PROPS
            $ExtensionContentIds = New-HCEmptyExtensionContentIdsObject
            if ($Entity.ParentEntityRelationships.Count -or $Entity.ChildEntityRelationships.Count) {
                $HCEntity | Add-Member -Type NoteProperty -Name IsExtended -Value $true -Force
                $HCEntity | Add-Member -Type NoteProperty -Name ExtensionContentIds -Value $ExtensionContentIds -Force
            }
            if ($Entity.ParentEntityRelationships.Count) {
                $HCEntity.ExtensionContentIds.CoreEntity = $Entity.ContentId
                foreach ($Relationship in $Entity.ParentEntityRelationships.GetEnumerator()) {
                    $HCEntity.ExtensionContentIds."$($Relationship.ChildRoleName)" = $Relationship.ChildEntity.ContentId
                }
            }
            if ($Entity.ChildEntityRelationships.Count) {
                $HCEntity.ExtensionContentIds."$($Entity.ChildEntityRelationships.ChildRoleName)" = $Entity.ChildEntityRelationships.ChildEntity.ContentId
                foreach ($Relationship in $Entity.ChildEntityRelationships.ParentEntity.ParentEntityRelationships.GetEnumerator()) {
                    $HCEntity.ExtensionContentIds."$($Relationship.ChildRoleName)" = $Relationship.ChildEntity.ContentId
                    $HCEntity.ExtensionContentIds."$($Relationship.ParentRoleName)" = $Relationship.ParentEntity.ContentId
                }
            }
            #endregion
            #region CUSTOM GROUP PROPS
            $HCEntity.EntityGroupNM = $HCEntity.Bindings[0].GrainName #Set the EntityGroupNM to the first Grain name for now // not a perfect solution
            if ($HCEntity.Bindings) {
                $HCEntity.ClassificationCode = $HCEntity.Bindings[0].ClassificationCode #Set the ClassificationCode to the first ClassificationCode for now // not a perfect solution
            }
            if ($Entity.AllowsDataEntry -eq $true) {
                $HCEntity.ClassificationCode = 'DataEntry'
            }
            #endregion

            $MetadataNew.Entities += $HCEntity
        }        
        #endregion

        #region Update extension entity classification
        foreach ($Extension in $MetadataNew.Entities | Where-Object { ($_.ExtensionContentIds.PsObject.Properties.Value | Measure-Object).Count -eq 3 }) {
            foreach ($property in $Extension.ExtensionContentIds.PsObject.Properties) {
                $Entity = $MetadataNew.Entities[$MetadataNew.Entities.ContentId.IndexOf($property.Value)];
                $Entity | Add-Member -Type NoteProperty -Name ExtensionTypeNM -Value $property.Name -Force;
                $Entity.ExtensionContentIds = $Extension.ExtensionContentIds;
                if ($property.Name -eq "OverridingExtensionView") {
                    $Entity.ClassificationCode = "OverridingExtensionView";
                }
                elseif ($property.Name -ne "CoreEntity" -and $Entity.ClassificationCode -notmatch "-") {
                    $Entity.ClassificationCode = "$($Entity.ClassificationCode)-Extension"
                }
                foreach ($Binding in $Entity.Bindings) {
                    $Binding.ClassificationCode = $Entity.ClassificationCode;
                }
            }
        }
        #endregion
        
        $MetadataNew.MaxLastModifiedTimestamp<#extension#> = ($MetadataNew.Entities.LastModifiedTimestamp | Measure-Object -Maximum).Maximum
        $Msg = "$(" " * 8)$(($MetadataNew.Entities | Measure-Object).Count) - Entities"; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
        $Msg = "$(" " * 8)$(($MetadataNew.Entities.Bindings | Measure-Object).Count) - Bindings"; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
        
        #region ADD DATA ENTRY DATA
        if ($MetadataRaw.DataEntryData) {
            foreach ($HCEntity in $MetadataNew.Entities | Where-Object { $_.ClassificationCode -eq 'DataEntry' }) {
                $DataEntryDataIndex = $MetadataRaw.DataEntryData.FullyQualifiedNM.IndexOf($HCEntity.FullyQualifiedNames.View)
                if ($DataEntryDataIndex -ne -1) {
                    #New property added to store a maximum of 300 records for that Data entry entity
                    #@{ FullyQualifiedNM = $Csv.BaseName; Data = Import-Csv -Path $Csv.FullName; Msg = $null }
                    $DataEntryRecordCNT = ($MetadataRaw.DataEntryData[$DataEntryDataIndex].Data | Measure-Object).Count
                    if ($DataEntryRecordCNT -gt 300) {
                        $Msg = "Displaying only 300 out of $($DataEntryRecordCNT) records"
                    }
                    else {
                        $Msg = "Displaying $($DataEntryRecordCNT) records"
                    }
                    
                    $DataEntryData = New-Object PSObject
                    $DataEntryData | Add-Member -Type NoteProperty -Name FullyQualifiedNM -Value $MetadataRaw.DataEntryData[$DataEntryDataIndex].FullyQualifiedNM
                    $DataEntryData | Add-Member -Type NoteProperty -Name Data -Value ($MetadataRaw.DataEntryData[$DataEntryDataIndex].Data | Select-Object -First 300)
                    $DataEntryData | Add-Member -Type NoteProperty -Name Data_All -Value ($MetadataRaw.DataEntryData[$DataEntryDataIndex].Data)
                    $DataEntryData | Add-Member -Type NoteProperty -Name Msg -Value $Msg
                    
                    $HCEntity | Add-Member -Type NoteProperty -Name DataEntryData -Value $DataEntryData
                }
            }
        }
        #endregion
        #region PARSE BINDINGS
        $Msg = "$(" " * 4)Parsing tables and columns from sql..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
        foreach ($HCEntity in $MetadataNew.Entities) {
            foreach ($HCBinding in $HCEntity.Bindings) {
                $SourcedByEntities = $(Invoke-SqlParser -Query $HCBinding.UserDefinedSQL -Log $False -SelectStar $False -Brackets $False)
                
                foreach ($SourcedByEntity in $SourcedByEntities | Where-Object { $_.DatabaseNM -and $_.SchemaNM -and $_.TableNM }) {
                    $HCSourcedByEntity = New-HCEmptySourcedByEntityObject
                    #$HCSourcedByEntity.ServerNM = $SourcedByEntity.ServerNM
                    $HCSourcedByEntity.DatabaseNM = $SourcedByEntity.DatabaseNM
                    $HCSourcedByEntity.SchemaNM = $SourcedByEntity.SchemaNM
                    $HCSourcedByEntity.TableNM = $SourcedByEntity.TableNM
                    $HCSourcedByEntity.FullyQualifiedNM = $SourcedByEntity.FullyQualifiedNM
                    $HCSourcedByEntity.AliasNM = $SourcedByEntity.AliasNM
                    $HCSourcedByEntity.BindingCount = 1
                    
                    #if table originated from a system table
                    if ($HCSourcedByEntity.SchemaNM -eq 'CatalystAdmin') {
                        $HCSourcedByEntity.TableOrigin = 'System'
                    }
                    #or if table originated from a local table
                    elseif (($MetadataNew.Entities.FullyQualifiedNames.Table -contains $HCSourcedByEntity.FullyQualifiedNM) -or `
                        ($MetadataNew.Entities.FullyQualifiedNames.View -contains $HCSourcedByEntity.FullyQualifiedNM)) {
                        $HCSourcedByEntity.TableOrigin = 'Local'
                        $HCSourcedByEntity.SourceContentId = ($MetadataNew.Entities | Where-Object { (($_.FullyQualifiedNames.Table -eq $HCSourcedByEntity.FullyQualifiedNM) -or ($_.FullyQualifiedNames.View -eq $HCSourcedByEntity.FullyQualifiedNM)) -and $_.ClassificationCode -ne 'OverridingExtensionView' }).ContentId
                        
                        #if it's a universal entity then it originates outside of this datamart
                        if ($MetadataNew.Entities[$MetadataNew.Entities.ContentId.IndexOf($HCSourcedByEntity.SourceContentId)].IsUniversal) {
                            $HCSourcedByEntity.TableOrigin = 'External'
                        }
                    }
                    #else table must have originated externally
                    else {
                        $HCSourcedByEntity.TableOrigin = 'External'
                    }
                    
                    foreach ($SourcedByColumn in $SourcedByEntity.Columns) {
                        $HCSourcedByColumn = New-HCEmptySourcedByColumnObject
                        $HCSourcedByColumn.ColumnNM = $SourcedByColumn.ColumnNM
                        $HCSourcedByColumn.FullyQualifiedNM = $SourcedByColumn.FullyQualifiedNM
                        $HCSourcedByColumn.AliasNM = $SourcedByColumn.AliasNM
                        $HCSourcedByColumn.BindingCount = 1
                        
                        $HCSourcedByEntity.SourcedByColumns += $HCSourcedByColumn
                    }
                    
                    #check for missing alias ie PossibleColumns
                    if ($SourcedByEntity.PossibleColumns) {
                        $HCSourcedByEntity | Add-Member -Type NoteProperty -Name SourcedByPossibleColumns -Value @()
                        foreach ($SourcedByPossibleColumn in $SourcedByEntity.PossibleColumns) {
                            $HCSourcedByPossibleColumn = New-HCEmptySourcedByPossibleColumnObject
                            $HCSourcedByPossibleColumn.ColumnNM = $SourcedByPossibleColumn.ColumnNM
                            $HCSourcedByPossibleColumn.FullyQualifiedNM = "$($HCSourcedByEntity.FullyQualifiedNM).$($HCSourcedByPossibleColumn.ColumnNM)"
                            
                            $HCSourcedByEntity.SourcedByPossibleColumns += $HCSourcedByPossibleColumn
                        }
                    }
                    
                    $HCBinding.SourcedByEntities += $HCSourcedByEntity
                }
            }
            
            #region LEVEL-UP SOURCES (BINDING TO ENTITY)
            $HCEntityGroups = $HCEntity.Bindings.SourcedByEntities | Group-Object -Property FullyQualifiedNM
            foreach ($HCEntityGroup in $HCEntityGroups) {
                $HCSourcedByEntity = New-HCEmptySourcedByEntityObject
                #$HCSourcedByEntity.ServerNM = $HCEntityGroup.Group[0].ServerNM
                $HCSourcedByEntity.DatabaseNM = $HCEntityGroup.Group[0].DatabaseNM
                $HCSourcedByEntity.SchemaNM = $HCEntityGroup.Group[0].SchemaNM
                $HCSourcedByEntity.TableNM = $HCEntityGroup.Group[0].TableNM
                $HCSourcedByEntity.FullyQualifiedNM = $HCEntityGroup.Group[0].FullyQualifiedNM
                $HCSourcedByEntity.TableOrigin = $HCEntityGroup.Group[0].TableOrigin
                $HCSourcedByEntity.SourceContentId = $HCEntityGroup.Group[0].SourceContentId
                $HCSourcedByEntity.BindingCount = ($HCEntityGroup.Group.BindingCount | Measure-Object -Sum).Sum
                $HCSourcedByEntity.PSObject.Properties.Remove('AliasNM')
                
                
                $ColumnGroups = $HCEntityGroup.Group.SourcedByColumns | Group-Object ColumnNM
                foreach ($ColumnGroup in $ColumnGroups) {
                    $HCSourcedByColumn = New-HCEmptySourcedByColumnObject
                    $HCSourcedByColumn.ColumnNM = $ColumnGroup.Group[0].ColumnNM
                    $HCSourcedByColumn.FullyQualifiedNM = $ColumnGroup.Group[0].FullyQualifiedNM
                    $HCSourcedByColumn.BindingCount = ($ColumnGroup.Group.BindingCount | Measure-Object -Sum).Sum
                    $HCSourcedByColumn.PSObject.Properties.Remove('AliasNM')
                    
                    $HCSourcedByEntity.SourcedByColumns += $HCSourcedByColumn
                }
                $HCEntity.SourcedByEntities += $HCSourcedByEntity
            }
            #endregion
        }
        #endregion
        #region UPDATE EXTENSION ENTITIES
        function Get-Entity ($ContentId) {
            return $MetadataNew.Entities[$MetadataNew.Entities.ContentId.IndexOf($ContentId)]
        }
        foreach ($HCEntity in $MetadataNew.Entities | Where-Object { $_.ExtensionTypeNM -eq 'CoreEntity' }) {
            $ExtensionEntityId = $HCEntity.ExtensionContentIds.ExtensionEntity;
            $ExtensionEntity = Get-Entity($ExtensionEntityId);
            
            $OverridingExtensionViewId = $HCEntity.ExtensionContentIds.OverridingExtensionView;
            $OverridingExtensionView = Get-Entity($OverridingExtensionViewId);
            
            #Add the SourcedByEntities from the OverridingExtensionView to the CoreEntity
            $HCEntity.SourcedByEntities += $OverridingExtensionView.SourcedByEntities | Where-Object { $_.SourceContentId -ne $HCEntity.ContentId };
            
            #Add the Columns from the ExtensionEntity to the CoreEntity
            $ColumnsExt = $ExtensionEntity.Columns | Where-Object { $_.IsSystemColumnValue -eq $false -and $_.IsPrimaryKeyValue -eq $false };
            $MaxOrdinal = ($HCEntity.Columns.Ordinal | Measure-Object -Maximum).Maximum + 1;
            foreach ($ColumnExt in $ColumnsExt | Sort-Object Ordinal) {
                $ColumnExt | Add-Member -Type NoteProperty -Name IsExtended -Value $True;
                $ColumnExt.Ordinal = $MaxOrdinal;
                $MaxOrdinal++;
            }
            $HCEntity.Columns += $ColumnsExt;
            
            #Add the OverridingExtensionView as a property of the CoreEntity
            $HCEntity | Add-Member -Type NoteProperty -Name OverridingExtensionView -Value $OverridingExtensionView;
            
            #Remove the OverridingExtensionView as a true entity
            $MetadataNew.Entities = $MetadataNew.Entities | Where-Object { $_.ContentId -ne $OverridingExtensionViewId };
            
            #if the CoreEntity is not a public entity, then turn off the extension and overridingextension as being public
            #if (!($HCEntity.IsPublic))
            #{
            #	$ExtensionEntity.IsPublic = $false;
            #	$OverridingExtensionView.IsPublic = $false;
            #}
        }
        #endregion
        #region UPDATE OVERRIDING VIEW ENTITIES (SEPARATE FROM EXTENSIONS)
        $OverrideList = $MetadataNew.Entities | Group-Object -Property { $_.FullyQualifiedNames.View } | Where-Object Count -gt 1
        
        $OverrideObjects = @();
        foreach ($Override in $OverrideList) {
            $OverrideObject = New-Object PSObject
            $OverrideObject | Add-Member -Type NoteProperty -Name OverriddenContentId -Value $Null
            $OverrideObject | Add-Member -Type NoteProperty -Name OverridingContentId -Value $Null
            
            foreach ($Entity in $Override.Group) {
                if ($Entity.IsPersisted) {
                    $OverrideObject.OverriddenContentId = $Entity.ContentId
                }
                else {
                    $OverrideObject.OverridingContentId = $Entity.ContentId
                }
            }
            $OverrideObjects += $OverrideObject;
        }
        foreach ($OverrideObject in $OverrideObjects) {
            $OverriddenEntity = $MetadataNew.Entities[$MetadataNew.Entities.ContentId.IndexOf($OverrideObject.OverriddenContentId)];
            $OverriddenEntity | Add-Member -Type NoteProperty -Name IsOverridden -Value $True
            $OverriddenEntity.ViewName = $OverriddenEntity.ViewName + 'BASE'
            $OverriddenEntity.FullyQualifiedNames.View = $OverriddenEntity.FullyQualifiedNames.View + 'BASE'
            
            $OverridingEntity = $MetadataNew.Entities[$MetadataNew.Entities.ContentId.IndexOf($OverrideObject.OverridingContentId)];
            $OverridingEntity | Add-Member -Type NoteProperty -Name DoesOverride -Value $True
        }
        #endregion							
        #region LEVEL-UP SOURCES (ENTITY TO DATAMART)
        $MetadataNewGroups = $MetadataNew.Entities.SourcedByEntities | Group-Object -Property FullyQualifiedNM
        foreach ($MetadataNewGroup in $MetadataNewGroups) {
            $HCSourcedByEntity = New-HCEmptySourcedByEntityObject
            #$HCSourcedByEntity.ServerNM = $MetadataNewGroup.Group[0].ServerNM
            $HCSourcedByEntity.DatabaseNM = $MetadataNewGroup.Group[0].DatabaseNM
            $HCSourcedByEntity.SchemaNM = $MetadataNewGroup.Group[0].SchemaNM
            $HCSourcedByEntity.TableNM = $MetadataNewGroup.Group[0].TableNM
            $HCSourcedByEntity.FullyQualifiedNM = $MetadataNewGroup.Group[0].FullyQualifiedNM
            $HCSourcedByEntity.TableOrigin = $MetadataNewGroup.Group[0].TableOrigin
            $HCSourcedByEntity.SourceContentId = $MetadataNewGroup.Group[0].SourceContentId
            $HCSourcedByEntity.BindingCount = ($MetadataNewGroup.Group.BindingCount | Measure-Object -Sum).Sum
            $HCSourcedByEntity.PSObject.Properties.Remove('AliasNM')
            
            
            $ColumnGroups = $MetadataNewGroup.Group.SourcedByColumns | Group-Object ColumnNM
            foreach ($ColumnGroup in $ColumnGroups) {
                $HCSourcedByColumn = New-HCEmptySourcedByColumnObject
                $HCSourcedByColumn.ColumnNM = $ColumnGroup.Group[0].ColumnNM
                $HCSourcedByColumn.FullyQualifiedNM = $ColumnGroup.Group[0].FullyQualifiedNM
                $HCSourcedByColumn.BindingCount = ($ColumnGroup.Group.BindingCount | Measure-Object -Sum).Sum
                $HCSourcedByColumn.PSObject.Properties.Remove('AliasNM')
                
                $HCSourcedByEntity.SourcedByColumns += $HCSourcedByColumn
            }
            $MetadataNew.SourcedByEntities += $HCSourcedByEntity
        }
        #endregion
        #region ADD GIT REPO PROPERTIES
        try {
            $Msg = "$(" " * 4)Adding git properties..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
            function checkGit {
                [CmdletBinding()]
                param ()
                begin {
                    if (!(Test-Path $((Get-Location).Path + '\.git'))) { throw; }
                }
                process {
                    git --version
                    $GitUrl = (git config --local remote.origin.url).Replace(".git", "")
                    $MetadataNew | Add-Member -Type NoteProperty -Name Team -Value $(($GitUrl -split "/")[3])
                    $MetadataNew | Add-Member -Type NoteProperty -Name Repository -Value $(($GitUrl -split "/")[4])
                    $MetadataNew | Add-Member -Type NoteProperty -Name Branch -Value $(git rev-parse --abbrev-ref HEAD)
                }
            }
            checkGit -ErrorAction Stop
        }
        catch {
            $Msg = "$(" " * 8)Git not installed or not inside a git directory -- unable to add git properties"; Write-Host $Msg -ForegroundColor Yellow; Write-Verbose $Msg; Write-Log $Msg 'warning';
        }
        #endregion
        #region SPLIT OBJECT INTO SMALLER FILES
        if (!$NoSplit) {
            $Msg = "$(" " * 4)Splitting data object into smaller files..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
            Split-ObjectToFiles -metadataNew $MetadataNew -splitDirectory $SplitDirectory
        }
        #endregion
        
       
        $Msg = "Success!`r`n"; Write-Host $Msg -ForegroundColor Green; Write-Verbose $Msg; Write-Log $Msg;
        $Output = New-Object PSObject
        $Output | Add-Member -Type NoteProperty -Name MetadataNew -Value $MetadataNew
        $Output | Add-Member -Type NoteProperty -Name Outdir -Value $OutDir
        return $Output
    }
}