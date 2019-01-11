function New-Nodes {
    [CmdletBinding()]
    param ($Entity)
    begin {
        $Nodes = New-EmptyNodes;
    }
    process {
        #UPSTREAM LINEAGE
        $Level = 0;
        $Nodes.Upstream += New-UpstreamNode -entity $Entity -level $Level;
        $Index = 0;
        $Batches = 1;
        do {
            $Edges = $Nodes.Upstream[$Index].Edges
            $EdgeCount = ($Edges | Measure-Object).Count;
            $Level = $Nodes.Upstream[$Index].Level - 1;
            $Batches = $Batches + $EdgeCount;
            foreach ($Edge in $Edges) {
                if ($Edge.ContentId) {
                    $Node = New-UpstreamNode -entity (Get-Entity -contentId $Edge.ContentId) -level $Level;
                    if ($Nodes.Upstream.ContentId.indexOf($Node.ContentId) -eq -1) {
                        $Nodes.Upstream += $Node;
                    }
                }
                else {
                    $ExtEntity = New-Object PSObject
                    $ExtEntity | Add-Member -Type NoteProperty -Name DatabaseNM -Value $Edge.Attributes.DatabaseNM
                    $ExtEntity | Add-Member -Type NoteProperty -Name SchemaNM -Value $Edge.Attributes.SchemaNM
                    $ExtEntity | Add-Member -Type NoteProperty -Name ViewName -Value $Edge.Attributes.TableNM
                    $ExtEntity | Add-Member -Type NoteProperty -Name FullyQualifiedNames -Value @{ View = $Edge.Attributes.FullyQualifiedNM; }
                    $Node = New-UpstreamNode -entity $ExtEntity -level $Level;
                    if ($Nodes.Upstream.Attributes.FullyQualifiedNM.indexOf($Node.Attributes.FullyQualifiedNM) -eq -1) {
                        $Nodes.Upstream += $Node;
                    }
                }
            }
            $Batches--
            $Index++
        }
        while ($Batches -gt 0)
                        
        #DOWNSTREAM LINEAGE
        $Level = 0;
        $Nodes.Downstream += New-DownstreamNode -entity $Entity -level $Level;
        $Index = 0;
        $Batches = 1;
        do {
            $Edges = $Nodes.Downstream[$Index].Edges | Where-Object { $_.ContentId }
            $EdgeCount = ($Edges | Measure-Object).Count;
            $Level = $Nodes.Downstream[$Index].Level + 1;
            $Batches = $Batches + $EdgeCount;
            foreach ($Edge in $Edges) {
                $Node = New-DownstreamNode -entity (Get-Entity -contentId $Edge.ContentId) -level $Level;
                if ($Nodes.Downstream.ContentId.indexOf($Node.ContentId) -eq -1) {
                    $Nodes.Downstream += $Node;
                }
            }
            $Batches--
            $Index++
        }
        while ($Batches -gt 0)
                        
    }
    end {
        return $Nodes
    }
}
