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
