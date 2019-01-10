function New-HCEntityObject {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True, Position = 0)]
        [psobject]$Entity,
        [Parameter(Mandatory = $False, Position = 1)]
        [array]$Bindings,
        [Parameter(Mandatory = $False, Position = 2)]
        [string]$ClassificationCode
    )
    begin {
        $HCEntities = @()
        function New-HCInnerEntityObject {
            [CmdletBinding()]
            Param (
                [Parameter(Mandatory = $True, Position = 0)]
                [psobject]$Entity,
                [Parameter(Mandatory = $False, Position = 1)]
                [array]$Bindings,
                [Parameter(Mandatory = $False, Position = 2)]
                [string]$ClassificationCode
                
            )
            begin {
                $HCEntity = New-HCEmptyEntityObject
            }
            Process {
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
                foreach ($Column in $Entity.Columns) {
                    $HCColumn = New-HCEmptyColumnObject
                    $HCColumn.ContentId = $Column.ContentId
                    $HCColumn.ColumnNM = $Column.ColumnNM
                    $HCColumn.DataSensitivityCD = $Column.DataSensitivityCD
                    $HCColumn.DataTypeDSC = $Column.DataTypeDSC
                    $HCColumn.DescriptionTXT = if (($Column.DescriptionTXT -split " ")[0] -like "<*") { ($Column.DescriptionTXT -replace ($Column.DescriptionTXT -split " ")[0], "").TrimStart() }
                    else { $Column.DescriptionTXT }
                    $HCColumn.IsIncrementalColumnValue = $Column.IsIncrementalColumnValue
                    $HCColumn.IsSystemColumnValue = $Column.IsSystemColumnValue
                    $HCColumn.IsNullableValue = $Column.IsNullableValue
                    $HCColumn.IsPrimaryKeyValue = $Column.IsPrimaryKeyValue
                    $HCColumn.Ordinal = $Column.Ordinal
                    $HCColumn.Status = $Column.Status
                    $HCColumn.ColumnGroupNM = if (($Column.DescriptionTXT -split " ")[0] -like "<*") { (Get-Culture).textinfo.totitlecase((($Column.DescriptionTXT -split " ")[0] -replace "<", "" -replace ">", "" -replace "-", " ").tolower()) }
                    
                    $HCEntity.Columns += $HCColumn
                }
                #endregion
                #region INDEX PROPS
                foreach ($Index in $Entity.Indexes) {
                    $HCIndex = New-HCEmptyIndexObject
                    $HCIndex.IndexName = $Index.IndexName
                    $HCIndex.IndexTypeCode = $Index.IndexTypeCode
                    $HCIndex.IsActive = $Index.IsActive
                    
                    foreach ($IndexColumn in $Index.IndexColumns) {
                        $HCIndexColumn = New-HCEmptyIndexColumnObject
                        $HCIndexColumn.Ordinal = $IndexColumn.Ordinal
                        $HCIndexColumn.ColumnNM = ($Entity.Columns | Where-Object { $_.'$Id' -eq $IndexColumn.Column.'$Ref' }).ColumnNM
                        $HCIndexColumn.IsCovering = $IndexColumn.IsCovering
                        $HCIndexColumn.IsDescending = $IndexColumn.IsDescending
                        
                        $HCIndex.IndexColumns += $HCIndexColumn
                    }
                    
                    $HCEntity.Indexes += $HCIndex
                }
                #endregion
                #region BINDING PROPS
                foreach ($Binding in $Bindings) {
                    $HCBinding = New-HCEmptyBindingObject
                    $HCBinding.ContentId = $Binding.ContentId
                    $HCBinding.BindingName = $Binding.BindingName
                    $HCBinding.BindingNameNoSpaces = (Get-CleanFileName -Name $Binding.BindingName -RemoveSpace)
                    $HCBinding.BindingStatus = $Binding.BindingStatus
                    $HCBinding.BindingDescription = $Binding.BindingDescription
                    if ($ClassificationCode) {
                        $HCBinding.ClassificationCode = "$($Binding.ClassificationCode)-$($ClassificationCode)"
                    }
                    else {
                        $HCBinding.ClassificationCode = $Binding.ClassificationCode
                    }
                    $HCBinding.GrainName = $Binding.GrainName
                    $HCBinding.UserDefinedSQL = ($Binding.AttributeValues | Where-Object AttributeName -eq "UserDefinedSQL").LongTextValue
                    
                    #New attributes introduced with CAP 4.0
                    $IsProtected = $Binding.AttributeValues | Where-Object AttributeName -eq 'IsProtected'
                    if ($IsProtected) {
                        $HCBinding | Add-Member -Type NoteProperty -Name IsProtected -Value $([System.Convert]::ToBoolean($IsProtected.TextValue))
                    }
                    $LoadType = if ($Binding.LoadType) { $Binding.LoadType }
                    else { $HCEntity.LoadType }
                    if ($LoadType) {
                        $HCBinding | Add-Member -Type NoteProperty -Name LoadType -Value $LoadType
                        
                        if ($Binding.IncrementalConfigurations) {
                            $HCBinding | Add-Member -Type NoteProperty -Name IncrementalConfigurations -Value @()
                            
                            foreach ($IncrementalConfiguration in $Binding.IncrementalConfigurations) {
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
                if ($Entity.ChildEntityRelationships -or $Entity.ParentEntityRelationships) {
                    $HCEntity | Add-Member -Type NoteProperty -Name IsExtended -Value $true -Force
                    $HCEntity | Add-Member -Type NoteProperty -Name ExtensionContentIds -Value $ExtensionContentIds -Force
                }
                
                foreach ($Ext in $Entity.ParentEntityRelationships | Where-Object { $_.ParentRoleName }) {
                    $ExtensionContentIds."$($Ext.ParentRoleName)" = $HCEntity.ContentId
                    
                    foreach ($Ext2 in $Ext.ChildEntity) {
                        $ExtensionContentIds."$($Ext.ChildRoleName)" = $Ext2.ContentId
                        
                        foreach ($Ext3 in $Ext2.ChildEntityRelationships | Where-Object { $_.ParentRoleName }) {
                            $ExtensionContentIds."$($Ext3.ParentRoleName)" = $Ext3.ParentEntity.ContentId
                        }
                        New-HCInnerEntityObject -Entity $Ext2 -Bindings $Ext2.FedByBindings
                    }
                    $HCEntity | Add-Member -Type NoteProperty -Name ExtensionContentIds -Value $ExtensionContentIds -Force
                }
                
                foreach ($Ext in $Entity.ChildEntityRelationships | Where-Object { $_.ChildRoleName }) {
                    $ExtensionContentIds."$($Ext.ChildRoleName)" = $HCEntity.ContentId
                    
                    foreach ($Ext2 in $Ext.ParentEntity) {
                        $ExtensionContentIds."$($Ext.ParentRoleName)" = $Ext2.ContentId
                        
                        foreach ($Ext3 in $Ext2.ParentEntityRelationships | Where-Object { $_.ChildRoleName }) {
                            $ExtensionContentIds."$($Ext3.ChildRoleName)" = $Ext3.ChildEntity.ContentId
                        }
                        New-HCInnerEntityObject -Entity $Ext2 -Bindings $Ext2.FedByBindings
                    }
                    $HCEntity | Add-Member -Type NoteProperty -Name ExtensionContentIds -Value $ExtensionContentIds -Force
                }
                #endregion
                #region CUSTOM GROUP PROPS
                $HCEntity.EntityGroupNM = $HCEntity.Bindings[0].GrainName #Set the EntityGroupNM to the first Grain name for now // not a perfect solution
                if ($HCEntity.Bindings) {
                    $HCEntity.ClassificationCode = $HCEntity.Bindings[0].ClassificationCode #Set the ClassificationCode to the first ClassificationCode for now // not a perfect solution
                }
                else {
                    $HCEntity.ClassificationCode = $ClassificationCode
                }
                #endregion
            }
            End {
                return $HCEntity
            }
            
        }
    }
    process {
        $HCEntities += New-HCInnerEntityObject -Entity $Entity -Bindings $Bindings -ClassificationCode $ClassificationCode
    }
    end {
        return $HCEntities;
    }
}