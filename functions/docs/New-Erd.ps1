function New-Erd {
    param
    (
        [Parameter(Mandatory = $True, Position = 0)]
        [psobject]$DocsData
    )
    
    #Gcreate a new ERD object using the datamart name as the ERD name
    $Erd = New-EmptyDiagramGraph -Name Erd -Types @('Full', 'Minimal')
    $Erd.Erd.Data.GraphId = """" + $DocsData.DatamartNM + """"
    $Erd.Erd.Data.GraphName = $DocsData.DatamartNM
    
    #Get all the entities that we want to be nodes in the ERD diagram
    $Entities = $DocsData.Entities | Where-Object $validPublicEntities
    
    
    #Interate through these entities and create a new node
    forEach ($Entity in $Entities) {
        $ErdNode = New-EmptyDiagramNode
        $ErdNode.NodeId = """" + $Entity.FullyQualifiedNames.View + """"
        $ErdNode.NodeName = $Entity.FullyQualifiedNames.View
        $ErdNode.Props = $Entity.Columns
        
        #For those entities with primary keys...create a default PK port
        $PkColumns = $ErdNode.Props | Where-Object IsPrimaryKeyValue
        if ($PkColumns) {
            $PkPort = New-EmptyDiagramPort
            $PkPort.PortId = 0
            foreach ($PkColumn in $PkColumns) {
                $PkItem = New-EmptyDiagramItem
                $PkItem.ItemId = $PkColumn.ContentId
                $PkItem.ItemName = $PkColumn.ColumnNM
                $PkItem.Props += @{ DataTypeDSC = $PkColumn.DataTypeDSC; Ordinal = $PkColumn.Ordinal }
                $PkPort.Items += $PkItem
            }
            $PkPort.Props += @{ PortType = 'PK'; PortLinkId = ($PkPort.Items.ItemName | Sort-Object ItemName) -join "_" }
            $ErdNode.Ports += $PkPort
        }
        
        $Erd.Erd.Data.Nodes += $ErdNode
    }
    
    #loop back through the nodes and add any foreign key nodes
    forEach ($Node in $Erd.Erd.Data.Nodes) {
        #foreign keys nodes have to be primary keys from other nodes
        forEach ($OtherNode in $Erd.Erd.Data.Nodes | Where-Object { $_.NodeId -ne $Node.NodeId }) {
            $OtherPort = $OtherNode.Ports | Where-Object { $_.Props.PortType -eq 'PK' }
            $Count = 0;
            $TotalCount = ($OtherPort.Items | Measure-Object).Count
            $MaxPortId = ($Node.Ports.PortId | Measure-Object -Maximum).Maximum
            if (!$MaxPortId) { $MaxPortId = 0 }
            $FkPort = New-EmptyDiagramPort
            
            forEach ($OtherItem in $OtherPort.Items) {
                if ($Node.Props.ColumnNM.ToLower() -contains $OtherItem.ItemName.ToLower()) {
                    $TempColumn = $Node.Props[$Node.Props.ColumnNM.ToLower().IndexOf($OtherItem.ItemName.ToLower())]
                    $FkPort.PortId = $MaxPortId + 1
                    $FkItem = New-EmptyDiagramItem
                    $FkItem.ItemId = $TempColumn.ContentId
                    $FkItem.ItemName = $TempColumn.ColumnNM
                    $FkItem.Props += @{ DataTypeDSC = $TempColumn.DataTypeDSC; Ordinal = $TempColumn.Ordinal }
                    $FkPort.Items += $FkItem
                    $Count++
                }
                if ($Count -eq $TotalCount) {
                    $FkPort.Props += @{ PortType = 'FK'; PortLinkId	= ($FkPort.Items.ItemName | Sort-Object ItemName) -join "_" }
                    
                    $FkEdge = New-EmptyDiagramEdge
                    $FkEdge.From.NodeId = $Node.NodeId
                    $FkEdge.To.NodeId = $OtherNode.NodeId
                    $FkEdge.To.PortId = 0
                    
                    if ($Node.Ports.Props.PortLinkId) {
                        $Index = $Node.Ports.Props.PortLinkId.indexOf($FkPort.Props.PortLinkId)
                        if ($Index -ne -1) {
                            $FkEdge.From.PortId = $Node.Ports[$Index].PortId
                            $Node.Ports[$Index].Edges += $FkEdge
                        }
                        else {
                            $FkEdge.From.PortId = $FkPort.PortId
                            $FkPort.Edges += $FkEdge
                            $Node.Ports += $FkPort
                        }
                    }
                    else {
                        $FkEdge.From.PortId = $FkPort.PortId
                        $FkPort.Edges += $FkEdge
                        $Node.Ports += $FkPort
                    }
                }
            }
        }
        
        $MaxPortId = ($Node.Ports.PortId | Measure-Object -Maximum).Maximum
        if (!$MaxPortId) { $MaxPortId = 0 }
        $LastPort = New-EmptyDiagramPort
        $LastPort.PortId = $MaxPortId + 1
        $LastPort.Props += @{ PortType = ' ' }
        forEach ($Col in $Node.Props | Sort-Object Ordinal) {
            if ($Node.Ports.Items.ItemName -notcontains $Col.ColumnNM) {
                $LastItem = New-EmptyDiagramItem
                $LastItem.ItemId = $Col.ContentId
                $LastItem.ItemName = "$(if ($Col.IsExtended) {'*'})$($Col.ColumnNM)"
                $LastItem.Props += @{ DataTypeDSC = $Col.DataTypeDSC; Ordinal = $Col.Ordinal }
                $LastPort.Items += $LastItem
            }
        }
        if (($LastPort.Items | Measure-Object).Count -gt 0) {
            $Node.Ports += $LastPort
        }
        $Node.PSObject.Properties.Remove('Props')
    }
    $Erd.Erd.Data.PSObject.Properties.Remove('Subgraphs')
    
    if ($Erd.Erd.Data.Nodes.Ports.Edges) {
        $Erd.Erd.Graphviz.Full = New-ErdGraphviz -ErdData $Erd.Erd.Data
        $Erd.Erd.Graphviz.Minimal = New-ErdGraphviz -ErdData $Erd.Erd.Data -Minimal
    }
    else {
        $Msg = "$(" " * 8)Requirements not met for erd diagram:`n$(" " * 10)At least 2 public entities with primary keys and one foreign key relationship"; Write-Host $Msg -ForegroundColor Yellow; Write-Verbose $Msg; Write-Log $Msg 'warning';
    }
    return $Erd
}
