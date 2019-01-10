function New-HCEmptyExtensionContentIdsObject {
    $ExtensionContentIds = New-Object PSObject
    $ExtensionContentIds | Add-Member -Type NoteProperty -Name CoreEntity -Value $Null
    $ExtensionContentIds | Add-Member -Type NoteProperty -Name ExtensionEntity -Value $Null
    $ExtensionContentIds | Add-Member -Type NoteProperty -Name OverridingExtensionView -Value $Null
    
    return $ExtensionContentIds
}
