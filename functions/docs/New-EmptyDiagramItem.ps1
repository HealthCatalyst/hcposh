function New-EmptyDiagramItem {
    $DiagramItem = New-Object PSObject
    $DiagramItem | Add-Member -Type NoteProperty -Name ItemId -Value $Null
    $DiagramItem | Add-Member -Type NoteProperty -Name ItemName -Value $Null
    $DiagramItem | Add-Member -Type NoteProperty -Name Props -Value @()
    return $DiagramItem
}
