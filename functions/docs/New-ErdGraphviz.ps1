function New-ErdGraphviz {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $True, Position = 0)]
        [psobject]$ErdData,
        [Parameter(Mandatory = $False)]
        [switch]$Minimal
    )
    begin {
        $Tab = " " * 4;
        $GraphTmp = "digraph {{ GraphId }}{`n$($Tab)graph[rankdir=RL];`n$($Tab)node [shape=plaintext, fontname=""Arial""];`n{{ Nodes }}{{ Edges }}`n}";
        $NodeTmp = "`n$($Tab){{ NodeId }} [label=<`n$($Tab * 2)<table>`n$($Tab * 3)<tr><td border=""0"" bgcolor=""#D7DDE4""><b>{{ NodeName }}</b></td></tr>`n{{ Ports }}$($Tab * 2)</table>>];`n";
        $PortTmp = "$($Tab * 3)<tr><td sides=""t"" port=""{{ PortId }}"" align=""left"">`n$($Tab * 4)<table border=""0"" cellspacing=""0"" fixedsize=""true"" align=""left"">{{ Items }}`n$($Tab * 4)</table>`n$($Tab * 3)</td></tr>`n";
        $ItemTmp = "`n$($Tab * 5)<tr>`n$($Tab * 6)<td align=""left"" fixedsize=""true"" width=""20""><font point-size=""10"">{{ PortType }}</font></td>`n$($Tab * 6)<td align=""left"">{{ ItemName }}</td>`n$($Tab * 6)<td align=""left""><font point-size=""10"" color=""#767676"">{{ DataTypeDSC }}</font></td>`n$($Tab * 5)</tr>";
        $EdgeTmp = "`n$($Tab){{ From.NodeId }}:{{ From.PortId }} -> {{ To.NodeId }}:{{ To.PortId }} [arrowtail=crow, arrowhead=odot, dir=both];";
    }
    process {
        #BASE
        $GvErd = $GraphTmp -replace '{{ GraphId }}', $ErdData.GraphId
                        
        #NODES
        $GvNodes = @()
        forEach ($Node in $ErdData.Nodes) {
            $GvNode = $NodeTmp -replace '{{ NodeId }}', $Node.NodeId -replace '{{ NodeName }}', $Node.NodeName
            $GvPorts = @()
            if ($Minimal) {
                $Ports = $Node.Ports | Where-Object { $_.Props.PortType -ne ' ' }
            }
            else {
                $Ports = $Node.Ports
            }
            forEach ($Port in $Ports) {
                $GvPort = $PortTmp -replace '{{ PortId }}', $Port.PortId
                $GvItems = @()
                forEach ($Item in $Port.Items) {
                    $GvItem = $ItemTmp -replace '{{ PortType }}', $Port.Props.PortType -replace '{{ ItemName }}', $Item.ItemName -replace '{{ DataTypeDSC }}', $Item.Props.DataTypeDSC
                    $GvItems += $GvItem
                }
                $GvPort = $GvPort -replace '{{ Items }}', $GvItems
                $GvPorts += $GvPort
            }
            $GvNode = $GvNode -replace '{{ Ports }}', $GvPorts
            $GvNodes += $GvNode
        }
                        
        #EDGES
        $GvEdges = @()
        forEach ($Edge in $ErdData.Nodes.Ports.Edges) {
            $GvEdge = $EdgeTmp -replace '{{ From.NodeId }}', $Edge.From.NodeId -replace '{{ From.PortId }}', $Edge.From.PortId -replace '{{ To.NodeId }}', $Edge.To.NodeId -replace '{{ To.PortId }}', $Edge.To.PortId
            $GvEdges += $GvEdge
        }
    }
    end {
        return $GvErd -replace '{{ Nodes }}', $GvNodes -replace '{{ Edges }}', $GvEdges
    }
}
