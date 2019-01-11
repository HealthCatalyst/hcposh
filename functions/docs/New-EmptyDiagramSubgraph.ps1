function New-EmptyDiagramSubgraph {
    $Subgraph = New-Object PSObject
    $Subgraph | Add-Member -Type NoteProperty -Name SubgraphId -Value $Null
    $Subgraph | Add-Member -Type NoteProperty -Name SubgraphName -Value $Null
    $Subgraph | Add-Member -Type NoteProperty -Name Props -Value @()
    $Subgraph | Add-Member -Type NoteProperty -Name Subgraphs -Value @()
    $Subgraph | Add-Member -Type NoteProperty -Name Ports -Value @()
    return $Subgraph
}
