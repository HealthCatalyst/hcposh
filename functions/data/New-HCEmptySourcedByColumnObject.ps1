function New-HCEmptySourcedByColumnObject {
    $SourcedByColumn = New-Object PSObject
    $SourcedByColumn<#extension#> | Add-Member -Type NoteProperty -Name ColumnNM -Value $Null
    $SourcedByColumn<#extension#> | Add-Member -Type NoteProperty -Name FullyQualifiedNM -Value $Null
    $SourcedByColumn<#extension#> | Add-Member -Type NoteProperty -Name AliasNM -Value $Null
    $SourcedByColumn<#extension#> | Add-Member -Type NoteProperty -Name BindingCount -Value $Null
    
    return $SourcedByColumn
}
