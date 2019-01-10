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
