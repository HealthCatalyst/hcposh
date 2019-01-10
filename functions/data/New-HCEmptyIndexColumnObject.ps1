function New-HCEmptyIndexColumnObject {
    $IndexColumn = New-Object PSObject
    $IndexColumn | Add-Member -Type NoteProperty -Name Ordinal -Value $Null
    $IndexColumn | Add-Member -Type NoteProperty -Name ColumnNM -Value $Null
    $IndexColumn | Add-Member -Type NoteProperty -Name IsCovering -Value $Null
    $IndexColumn | Add-Member -Type NoteProperty -Name IsDescending -Value $Null
    
    return $IndexColumn
}
