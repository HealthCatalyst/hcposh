function New-EmptyDiagramPort {
    $DiagramPort = New-Object PSObject
    $DiagramPort | Add-Member -Type NoteProperty -Name PortId -Value $Null
    $DiagramPort | Add-Member -Type NoteProperty -Name Props -Value @()
    $DiagramPort | Add-Member -Type NoteProperty -Name Items -Value @()
    $DiagramPort | Add-Member -Type NoteProperty -Name Edges -Value @()
    return $DiagramPort
}
