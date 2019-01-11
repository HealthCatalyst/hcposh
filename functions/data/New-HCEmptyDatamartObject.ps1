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