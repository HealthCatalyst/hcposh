function New-EmptyDiagramNode {
    $DiagramNode = New-Object PSObject
    $DiagramNode | Add-Member -Type NoteProperty -Name NodeId -Value $Null
    $DiagramNode | Add-Member -Type NoteProperty -Name NodeName -Value $Null
    $DiagramNode | Add-Member -Type NoteProperty -Name Ports -Value @()
    $DiagramNode | Add-Member -Type NoteProperty -Name Props -Value @()
    return $DiagramNode
}
