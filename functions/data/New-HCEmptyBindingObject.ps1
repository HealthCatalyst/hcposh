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
