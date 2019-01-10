function New-Dfd {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $True)]
        [string]$Name,
        [Parameter(Mandatory = $True)]
        [array]$Lineage,
        [Parameter()]
        [ValidateSet('Upstream', 'Downstream', 'Both')]
        [string]$Type
    )
    begin {
        function Get-Color ($code) {
            switch ($code) {
                "Datamart" { @{ ColorLight = "#F0F3F6" } 
                }
                "Source" { @{ ColorLight = "#FCFAD0" } 
                }
                "System" { @{ ColorLight = "#FDE2C1" } 
                }
                "Shared" { @{ ColorLight = "#FDE2C1" } 
                }
                "SubjectArea" { @{ ColorLight = "#FDE2C1" } 
                }
                "Overriding" { @{ ColorLight = "#C7C7C7"; ColorDark = "#A2A2A2" } 
                }
                "Extensions" { @{ ColorLight = "#C7C7C7"; ColorDark = "#A2A2A2" } 
                }
                "Configurations" { @{ ColorLight = "#FBC9CC"; ColorDark = "#F8A6AA" } 
                }
                "Staging" { @{ ColorLight = "#B9E8FF"; ColorDark = "#73D2FF" } 
                }
                "Public" { @{ ColorLight = "#B9E7D1"; ColorDark = "#8BD7B3" } 
                }
                "Reports" { @{ ColorLight = "#D7D0E5"; ColorDark = "#BDB0D5" } 
                }
                default { "Color could not be determined." }
            }
        }
        function Spacer ($string) {
            return ($string -creplace '([A-Z\W_]|\d+)(?<![a-z])', ' $&').trim()
        }
        $Dfd = New-EmptyDiagramGraph -Name Dfd -Types @('LR', 'TB')
        $Dfd.Dfd.Data.GraphId = """$($Name)"""
        $Dfd.Dfd.Data.GraphName = $Name
    }
    process {
        #region EXTERNAL
        if ($Type -eq 'Upstream' -or $Type -eq 'Both') {
            $Externals = $Lineage.Upstream | Where-Object { $_.Groups.Group1 -eq 'External' } | Group-Object { "$($_.Groups.GroupId)" }
            forEach ($External in $Externals) {
                $Subgraph = New-EmptyDiagramSubgraph
                $Subgraph.SubgraphId = """cluster_$($External.Name)"""
                $Subgraph.SubgraphName = $External.Group[0].Groups.Group3.ToUpper()
                $Subgraph.Props = (Get-Color -code $External.Group[0].Groups.Group2).ColorLight
                $Port = New-EmptyDiagramPort
                $Port.PortId = """$($External.Name)"""
                forEach ($Item in $External.Group) {
                    $NewItem = New-EmptyDiagramItem
                    $NewItem.ItemId = """$($Item.Attributes.FullyQualifiedNM)"""
                    $NewItem.ItemName = "$($Item.Attributes.SchemaNM).$($Item.Attributes.TableNM)"
                    if ($Port.Items.ItemId -notcontains $NewItem.ItemId) {
                        $Port.Items += $NewItem
                    }
                }
                if ($Subgraph.Ports.PortId -notcontains $Port.PortId) {
                    $Subgraph.Ports += $Port
                }
                if ($Dfd.Dfd.Data.Subgraphs.SubgraphId -notcontains $Subgraph.SubgraphId) {
                    $Dfd.Dfd.Data.Subgraphs += $Subgraph
                }
            }
        }
        #endregion
        #region LOCAL
        $Subgraph = New-EmptyDiagramSubgraph
        $Subgraph.SubgraphId = """cluster_$($Name)"""
        $Subgraph.SubgraphName = $Name
        $Subgraph.Props = (Get-Color -code "Datamart").ColorLight
        
        if ($Type -eq 'Both') {
            $Locals = $Lineage.Upstream + $Lineage.Downstream | Where-Object { $_.Groups.Group1 -eq 'Local' } | Group-Object { "$($_.Groups.Group2)" }
        }
        else {
            $Locals = $Lineage.$Type | Where-Object { $_.Groups.Group1 -eq 'Local' } | Group-Object { "$($_.Groups.Group2)" }
        }
        forEach ($Local in $Locals) {
            $Subgraph2 = New-EmptyDiagramSubgraph
            $Subgraph2.SubgraphId = """cluster_$($Local.Name)"""
            $Subgraph2.SubgraphName = $Local.Group[0].Groups.Group2.ToUpper()
            $Subgraph2.Props = (Get-Color -code $Local.Group[0].Groups.Group2).ColorLight
            
            $Locals2 = $Local.Group | Group-Object { "$($_.Groups.Group3)" }
            forEach ($Local2 in $Locals2) {
                $Subgraph3 = New-EmptyDiagramSubgraph
                $Subgraph3.SubgraphId = """cluster_$($Local2.Name)"""
                $Subgraph3.SubgraphName = $Local2.Group[0].Groups.Group3.ToUpper()
                $Subgraph3.Props = (Get-Color -code $Local.Group[0].Groups.Group2).ColorDark
                
                $Port = New-EmptyDiagramPort
                $Port.PortId = """$($Local2.Group[0].Groups.GroupId)"""
                forEach ($Item in $Local2.Group) {
                    $NewItem = New-EmptyDiagramItem
                    $NewItem.ItemId = """$($Item.Attributes.FullyQualifiedNM)"""
                    $NewItem.ItemName = "$($Item.Attributes.BindingCNT)$($Item.Attributes.SchemaNM).$($Item.Attributes.TableNM)"
                    if ($Port.Items.ItemId -notcontains $NewItem.ItemId) {
                        $Port.Items += $NewItem
                    }
                    $Downstream = $Item | Where-Object { $_.Direction -eq 'Downstream' }
                    $Upstream = $Item | Where-Object { $_.Direction -eq 'Upstream' }
                    
                    ForEach ($Edge in $Downstream.Edges.Groups.GroupId) {
                        $NewEdge = New-EmptyDiagramEdge
                        $NewEdge.From.PortId = $Item.Groups.GroupId
                        $NewEdge.To.PortId = $Edge
                        $Port.Edges += $NewEdge
                    }
                    ForEach ($Edge in $Upstream.Edges.Groups.GroupId) {
                        $NewEdge = New-EmptyDiagramEdge
                        $NewEdge.From.PortId = $Edge
                        $NewEdge.To.PortId = $Item.Groups.GroupId
                        $Port.Edges += $NewEdge
                    }
                }
                if ($Subgraph3.Ports.PortId -notcontains $Port.PortId) {
                    $Subgraph3.Ports += $Port
                }
                if ($Subgraph2.Subgraphs.SubgraphId -notcontains $Subgraph3.SubgraphId) {
                    $Subgraph2.Subgraphs += $Subgraph3
                }
            }
            
            if ($Subgraph.Subgraphs.SubgraphId -notcontains $Subgraph2.SubgraphId) {
                $Subgraph.Subgraphs += $Subgraph2
            }
        }
        $Dfd.Dfd.Data.Subgraphs += $Subgraph
        #endregion
    }
    end {
        $Dfd.Dfd.Data.PSObject.Properties.Remove('Nodes')
        $Dfd.Dfd.Graphviz.LR = New-DfdGraphviz -DfdData $Dfd.Dfd.Data -Direction LR
        $Dfd.Dfd.Graphviz.TB = New-DfdGraphviz -DfdData $Dfd.Dfd.Data -Direction TB
        return $Dfd
    }
}
