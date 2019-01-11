function New-HCEmptySourcedByPossibleColumnObject {
    $SourcedByPossibleColumn = New-Object PSObject
    $SourcedByPossibleColumn<#extension#> | Add-Member -Type NoteProperty -Name ColumnNM -Value $Null
    $SourcedByPossibleColumn<#extension#> | Add-Member -Type NoteProperty -Name FullyQualifiedNM -Value $Null
    
    return $SourcedByPossibleColumn
}
