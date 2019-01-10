function New-HCEmptyDatamartObject {
    $Datamart = New-Object PSObject
    $Datamart | Add-Member -Type NoteProperty -Name ContentId -Value $Null
    $Datamart | Add-Member -Type NoteProperty -Name DatamartNM -Value $Null
    $Datamart | Add-Member -Type NoteProperty -Name DataMartTypeDSC -Value $Null
    $Datamart | Add-Member -Type NoteProperty -Name DescriptionTXT -Value $Null
    $Datamart | Add-Member -Type NoteProperty -Name DestinationDatabaseName -Value $Null
    $Datamart | Add-Member -Type NoteProperty -Name DestinationObjectPrefix -Value $Null
    $Datamart | Add-Member -Type NoteProperty -Name DestinationSchemaName -Value $Null
    $Datamart | Add-Member -Type NoteProperty -Name SamTypeCode -Value $Null
    $Datamart | Add-Member -Type NoteProperty -Name Status -Value $Null
    $Datamart | Add-Member -Type NoteProperty -Name VersionText -Value $Null
    $Datamart | Add-Member -Type NoteProperty -Name Entities -Value @()
    $Datamart<#extension#> | Add-Member -Type NoteProperty -Name DatamartNoSpacesNM -Value $Null
    $Datamart<#extension#> | Add-Member -Type NoteProperty -Name SAMDVersionText -Value $Null
    $Datamart<#extension#> | Add-Member -Type NoteProperty -Name MaxLastModifiedTimestamp -Value $Null
    $Datamart<#extension#> | Add-Member -Type NoteProperty -Name SourcedByEntities -Value @()
    $Datamart | Add-Member -Type NoteProperty -Name _hcposh -Value $Null
    
    return $Datamart
}
function New-HCEmptyEntityObject {
    $Entity = New-Object PSObject
    $Entity | Add-Member -Type NoteProperty -Name ContentId -Value $Null
    $Entity | Add-Member -Type NoteProperty -Name DescriptionTXT -Value $Null
    $Entity | Add-Member -Type NoteProperty -Name DatabaseNM -Value $Null
    $Entity | Add-Member -Type NoteProperty -Name SchemaNM -Value $Null
    $Entity | Add-Member -Type NoteProperty -Name TableNM -Value $Null
    $Entity | Add-Member -Type NoteProperty -Name TableTypeNM -Value $Null
    $Entity | Add-Member -Type NoteProperty -Name ViewName -Value $Null
    $Entity | Add-Member -Type NoteProperty -Name LoadType -Value $Null
    $Entity | Add-Member -Type NoteProperty -Name LastModifiedTimestamp -Value $Null
    $Entity | Add-Member -Type NoteProperty -Name IsPersisted -Value $Null
    $Entity | Add-Member -Type NoteProperty -Name IsPublic -Value $Null
    $Entity<#extension#> | Add-Member -Type NoteProperty -Name EntityGroupNM -Value $Null
    $Entity<#extension#> | Add-Member -Type NoteProperty -Name ClassificationCode -Value $Null
    $Entity<#extension#> | Add-Member -Type NoteProperty -Name FullyQualifiedNames -Value $Null
    $Entity<#extension#> | Add-Member -Type NoteProperty -Name Indexes -Value @()
    $Entity<#extension#> | Add-Member -Type NoteProperty -Name Columns -Value @()
    $Entity<#extension#> | Add-Member -Type NoteProperty -Name Bindings -Value @()
    $Entity<#extension#> | Add-Member -Type NoteProperty -Name SourcedByEntities -Value @()
    
    return $Entity
}
function New-HCEmptyIndexObject {
    $Index = New-Object PSObject
    $Index | Add-Member -Type NoteProperty -Name IndexName -Value $Null
    $Index | Add-Member -Type NoteProperty -Name IndexTypeCode -Value $Null
    $Index | Add-Member -Type NoteProperty -Name IsActive -Value $Null
    $Index | Add-Member -Type NoteProperty -Name IndexColumns -Value @()
    
    return $Index
}
function New-HCEmptyIndexColumnObject {
    $IndexColumn = New-Object PSObject
    $IndexColumn | Add-Member -Type NoteProperty -Name Ordinal -Value $Null
    $IndexColumn | Add-Member -Type NoteProperty -Name ColumnNM -Value $Null
    $IndexColumn | Add-Member -Type NoteProperty -Name IsCovering -Value $Null
    $IndexColumn | Add-Member -Type NoteProperty -Name IsDescending -Value $Null
    
    return $IndexColumn
}
function New-HCEmptyColumnObject {
    $Column = New-Object PSObject
    $Column | Add-Member -Type NoteProperty -Name ContentId -Value $Null
    $Column | Add-Member -Type NoteProperty -Name ColumnNM -Value $Null
    $Column | Add-Member -Type NoteProperty -Name DataSensitivityCD -Value $Null
    $Column | Add-Member -Type NoteProperty -Name DataTypeDSC -Value $Null
    $Column | Add-Member -Type NoteProperty -Name DescriptionTXT -Value $Null
    $Column | Add-Member -Type NoteProperty -Name IsIncrementalColumnValue -Value $Null
    $Column | Add-Member -Type NoteProperty -Name IsSystemColumnValue -Value $Null
    $Column | Add-Member -Type NoteProperty -Name IsNullableValue -Value $Null
    $Column | Add-Member -Type NoteProperty -Name IsPrimaryKeyValue -Value $Null
    $Column | Add-Member -Type NoteProperty -Name Ordinal -Value $Null
    $Column | Add-Member -Type NoteProperty -Name Status -Value $Null
    $Column | Add-Member -Type NoteProperty -Name ColumnGroupNM -Value $Null
    
    return $Column
}
function New-HCEmptyBindingObject {
    $Binding = New-Object PSObject
    $Binding | Add-Member -Type NoteProperty -Name ContentId -Value $Null
    $Binding | Add-Member -Type NoteProperty -Name BindingName -Value $Null
    $Binding | Add-Member -Type NoteProperty -Name BindingNameNoSpaces -Value $Null
    $Binding | Add-Member -Type NoteProperty -Name BindingStatus -Value $Null
    $Binding | Add-Member -Type NoteProperty -Name BindingDescription -Value $Null
    $Binding | Add-Member -Type NoteProperty -Name ClassificationCode -Value $Null
    $Binding | Add-Member -Type NoteProperty -Name GrainName -Value $Null
    $Binding | Add-Member -Type NoteProperty -Name UserDefinedSQL -Value $Null
    $Binding<#extension#> | Add-Member -Type NoteProperty -Name SourcedByEntities -Value @()
    
    return $Binding
}
function New-HCEmptyFullyQualifiedNameObject {
    $FullyQualifiedName = New-Object PSObject
    $FullyQualifiedName<#extension#> | Add-Member -Type NoteProperty -Name Table -Value $Null
    $FullyQualifiedName<#extension#> | Add-Member -Type NoteProperty -Name View -Value $Null
    
    return $FullyQualifiedName
}
function New-HCEmptyIncrementalConfigurationObject {
    $IncrementalConfiguration = New-Object PSObject
    $IncrementalConfiguration | Add-Member -Type NoteProperty -Name IncrementalColumnName -Value $Null
    $IncrementalConfiguration | Add-Member -Type NoteProperty -Name OverlapNumber -Value $Null
    $IncrementalConfiguration | Add-Member -Type NoteProperty -Name OverlapType -Value $Null
    $IncrementalConfiguration | Add-Member -Type NoteProperty -Name SourceDatabaseName -Value $Null
    $IncrementalConfiguration | Add-Member -Type NoteProperty -Name SourceSchemaName -Value $Null
    $IncrementalConfiguration | Add-Member -Type NoteProperty -Name SourceTableAlias -Value $Null
    $IncrementalConfiguration | Add-Member -Type NoteProperty -Name SourceTableName -Value $Null
    
    return $IncrementalConfiguration
}
function New-HCEmptySourcedByEntityObject {
    $SourcedByEntity = New-Object PSObject
    #$SourcedByEntity<#extension#> | Add-Member -Type NoteProperty -Name ServerNM -Value $Null
    $SourcedByEntity<#extension#> | Add-Member -Type NoteProperty -Name DatabaseNM -Value $Null
    $SourcedByEntity<#extension#> | Add-Member -Type NoteProperty -Name SchemaNM -Value $Null
    $SourcedByEntity<#extension#> | Add-Member -Type NoteProperty -Name TableNM -Value $Null
    $SourcedByEntity<#extension#> | Add-Member -Type NoteProperty -Name FullyQualifiedNM -Value $Null
    $SourcedByEntity<#extension#> | Add-Member -Type NoteProperty -Name AliasNM -Value $Null
    $SourcedByEntity<#extension#> | Add-Member -Type NoteProperty -Name TableOrigin -Value $Null
    $SourcedByEntity<#extension#> | Add-Member -Type NoteProperty -Name BindingCount -Value $Null
    $SourcedByEntity<#extension#> | Add-Member -Type NoteProperty -Name SourceContentId -Value $Null
    $SourcedByEntity<#extension#> | Add-Member -Type NoteProperty -Name SourcedByColumns -Value @()
    
    return $SourcedByEntity
}
function New-HCEmptySourcedByColumnObject {
    $SourcedByColumn = New-Object PSObject
    $SourcedByColumn<#extension#> | Add-Member -Type NoteProperty -Name ColumnNM -Value $Null
    $SourcedByColumn<#extension#> | Add-Member -Type NoteProperty -Name FullyQualifiedNM -Value $Null
    $SourcedByColumn<#extension#> | Add-Member -Type NoteProperty -Name AliasNM -Value $Null
    $SourcedByColumn<#extension#> | Add-Member -Type NoteProperty -Name BindingCount -Value $Null
    
    return $SourcedByColumn
}
function New-HCEmptySourcedByPossibleColumnObject {
    $SourcedByPossibleColumn = New-Object PSObject
    $SourcedByPossibleColumn<#extension#> | Add-Member -Type NoteProperty -Name ColumnNM -Value $Null
    $SourcedByPossibleColumn<#extension#> | Add-Member -Type NoteProperty -Name FullyQualifiedNM -Value $Null
    
    return $SourcedByPossibleColumn
}
function New-HCEmptyExtensionContentIdsObject {
    $ExtensionContentIds = New-Object PSObject
    $ExtensionContentIds | Add-Member -Type NoteProperty -Name CoreEntity -Value $Null
    $ExtensionContentIds | Add-Member -Type NoteProperty -Name ExtensionEntity -Value $Null
    $ExtensionContentIds | Add-Member -Type NoteProperty -Name OverridingExtensionView -Value $Null
    
    return $ExtensionContentIds
}
