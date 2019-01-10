function New-DfdGraphviz {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $True, Position = 0)]
        [psobject]$DfdData,
        [ValidateSet('LR', 'TB')]
        [string]$Direction
        
    )
    begin {
        $Tab = " " * 4;
        $Justify = 'c'
        if ($Direction -eq 'TB') { $Justify = 'l' }
        $GraphTmp = "digraph {{ GraphId }}{`n$($Tab)graph [layout=dot, rankdir=$($Direction), fontname=Arial, pencolor=transparent, style=""rounded, filled"", labeljust=""$($Justify)""];`n$($Tab)node [shape=box, fixedsize=false, fontname=Arial, style=""rounded, filled"", fillcolor=white];`n$($Tab)edge [style=dashed];`n{{ Subgraphs }}`n{{ Edges }}`n}";
        function Get-SubgraphTmp ($i) { return "`n$($Tab * (1 + $i))subgraph {{ SubgraphId }} {`n$($Tab * (2 + $i))label=<<B>{{ SubgraphName }}</B>>;`n$($Tab * (2 + $i))bgcolor=""{{ Color }}"";`n{{ Subgraphs }}{{ Ports }}`n$($Tab * (1 + $i))};"; }
        function Get-PortTmp ($i) { return "$($Tab * (1 + $i)){{ PortId }} [label=<`n$($Tab * (2 + $i))<table border=""0"">{{ Items }}`n$($Tab * (2 + $i))</table>>];"; }
        function Get-ItemTmp ($i) { return "`n$($Tab * (1 + $i))<tr><td align=""left"">{{ ItemName }}</td></tr>"; }
        $EdgeTmp = "`n$($Tab)""{{ From.PortId }}"" -> ""{{ To.PortId }}"";";
    }
    process {
        #BASE
        $GvGraph = $GraphTmp -replace '{{ GraphId }}', $DfdData.GraphId
        
        #SUBGRAPHS
        $GvSubgraph = @()
        $GvPort = $Null
        forEach ($Sub1 in $DfdData.Subgraphs) {
            if ($Sub1.Subgraphs) {
                
                $GvSubgraph2 = @()
                forEach ($Sub2 in $Sub1.Subgraphs) {
                    if ($Sub2.Subgraphs) {
                        
                        $GvSubgraph3 = @()
                        forEach ($Sub3 in $Sub2.Subgraphs) {
                            $GvItems = @()
                            forEach ($Item in $Sub3.Ports.Items | Sort-Object ItemName) {
                                $GvItems += (Get-ItemTmp -i 5) -replace '{{ ItemName }}', $Item.ItemName
                            }
                            $GvPort = (Get-PortTmp -i 3) -replace '{{ PortId }}', $Sub3.Ports.PortId -replace '{{ Items }}', $GvItems
                            $GvSubgraph3 += (Get-SubgraphTmp -i 2) -replace '{{ SubgraphId }}', $Sub3.SubgraphId -replace '{{ SubgraphName }}', $Sub3.SubgraphName -replace '{{ Color }}', $Sub3.Props -replace '{{ Subgraphs }}', '' -replace '{{ Ports }}', $GvPort
                        }
                        
                        $GvSubgraph2 += (Get-SubgraphTmp -i 1) -replace '{{ SubgraphId }}', $Sub2.SubgraphId -replace '{{ SubgraphName }}', $Sub2.SubgraphName -replace '{{ Color }}', $Sub2.Props -replace '{{ Ports }}', '' -replace '{{ Subgraphs }}', $GvSubgraph3
                    }
                    else {
                        $GvItems = @()
                        forEach ($Item in $Sub2.Ports.Items | Sort-Object ItemName) {
                            $GvItems += (Get-ItemTmp -i 4) -replace '{{ ItemName }}', $Item.ItemName
                        }
                        $GvPort = (Get-PortTmp -i 2) -replace '{{ PortId }}', $Sub2.Ports.PortId -replace '{{ Items }}', $GvItems
                        $GvSubgraph2 += (Get-SubgraphTmp -i 1) -replace '{{ SubgraphId }}', $Sub2.SubgraphId -replace '{{ SubgraphName }}', $Sub2.SubgraphName -replace '{{ Color }}', $Sub2.Props -replace '{{ Subgraphs }}', '' -replace '{{ Ports }}', $GvPort
                    }
                }
                
                $GvSubgraph += (Get-SubgraphTmp -i 0) -replace '{{ SubgraphId }}', $Sub1.SubgraphId -replace '{{ SubgraphName }}', $Sub1.SubgraphName -replace '{{ Color }}', $Sub1.Props -replace '{{ Ports }}', '' -replace '{{ Subgraphs }}', $GvSubgraph2
            }
            else {
                $GvItems = @()
                forEach ($Item in $Sub1.Ports.Items | Sort-Object ItemName) {
                    $GvItems += (Get-ItemTmp -i 3) -replace '{{ ItemName }}', $Item.ItemName
                }
                $GvPort = (Get-PortTmp -i 1) -replace '{{ PortId }}', $Sub1.Ports.PortId -replace '{{ Items }}', $GvItems
                $GvSubgraph += (Get-SubgraphTmp -i 0) -replace '{{ SubgraphId }}', $Sub1.SubgraphId -replace '{{ SubgraphName }}', $Sub1.SubgraphName -replace '{{ Color }}', $Sub1.Props -replace '{{ Subgraphs }}', '' -replace '{{ Ports }}', $GvPort
            }
        }
        
        #EDGES
        $Edges = $DfdData.Subgraphs.Ports.Edges + $DfdData.Subgraphs.Subgraphs.Ports.Edges + $DfdData.Subgraphs.Subgraphs.Subgraphs.Ports.Edges
        $GvEdges = @()
        forEach ($Edge in $Edges) {
            if ($Edge) {
                $GvEdge = $EdgeTmp -replace '{{ From.PortId }}', $Edge.From.PortId -replace '{{ To.PortId }}', $Edge.To.PortId
                if ($GvEdges -notcontains $GvEdge) {
                    $GvEdges += $GvEdge
                }
            }
        }
    }
    end {
        return $GvGraph -replace '{{ Subgraphs }}', $GvSubgraph -replace '{{ Edges }}', $GvEdges
    }
}
