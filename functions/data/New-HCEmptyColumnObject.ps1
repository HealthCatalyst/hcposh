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
    
    return $Column
}
