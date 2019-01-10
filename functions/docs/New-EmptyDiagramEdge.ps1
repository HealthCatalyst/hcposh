function New-EmptyDiagramEdge {
    $DiagramEdge = New-Object PSObject
    $DiagramEdge | Add-Member -Type NoteProperty -Name From -Value (New-Object PSObject -Property @{ NodeId = $Null; PortId = $Null; })
    $DiagramEdge | Add-Member -Type NoteProperty -Name To -Value (New-Object PSObject -Property @{ NodeId = $Null; PortId = $Null; })
    return $DiagramEdge
}
