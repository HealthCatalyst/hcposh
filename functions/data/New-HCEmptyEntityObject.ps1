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
