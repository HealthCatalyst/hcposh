function New-EmptyDiagramGraph {
    param
    (
        [Parameter(Mandatory = $True)]
        [string]$Name,
        [Parameter(Mandatory = $False)]
        [array]$Types
    )
    $Diagram = New-Object PSObject
    $Diagram | Add-Member -Type NoteProperty -Name $($Name) -Value (New-Object PSObject -Property @{ Data = $Null; Graphviz = $Null })
    
    $DiagramData = New-Object PSObject
    $DiagramData | Add-Member -Type NoteProperty -Name GraphId -Value $Null
    $DiagramData | Add-Member -Type NoteProperty -Name GraphName -Value $Null
    $DiagramData | Add-Member -Type NoteProperty -Name Subgraphs -Value @()
    $DiagramData | Add-Member -Type NoteProperty -Name Nodes -Value @()
    #$DiagramData | Add-Member -Type NoteProperty -Name Edges -Value @()
    
    $DiagramGraphviz = New-Object PSObject
    forEach ($Type in $Types) {
        $DiagramGraphviz | Add-Member -Type NoteProperty -Name $Type -Value $Null
    }
    
    $Diagram.$($Name).Data = $DiagramData
    $Diagram.$($Name).Graphviz = $DiagramGraphviz
    
    return $Diagram
}
