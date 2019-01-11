function Invoke-Docs {
    param
    (
        [Parameter(Mandatory = $True)]
        [psobject]$Data,
        [Parameter(Mandatory = $True)]
        [string]$OutDir,
        [switch]$OutZip
    )
    begin {
        #remove inactive bindings and non-dataentry entities without bindings
        foreach ($Entity in $Data.Entities) {
            $Bindings = @();
            foreach ($Binding in $Entity.Bindings) {
                if ($Binding.BindingStatus -eq 'Active') {
                    $Bindings += $Binding
                }
            }
            $Entity.Bindings = $Bindings;
							
            if ($Entity.ClassificationCode -ne 'DataEntry' -and ($Entity.Bindings | Measure-Object).Count -eq 0) {
                $Data.Entities = $Data.Entities | Where-Object { $_ -ne $Data.Entities[$Data.Entities.ContentId.IndexOf($Entity.ContentId)] }
            }
        }
        $validPublicEntities = { !($_.IsOverridden) -and $_.IsPublic -and (@('Summary', 'Generic') -contains $_.ClassificationCode) }
						
        #region FUNCTIONS FOR DATA LINEAGE
        function New-EmptyNodes {
            $Nodes = New-Object PSObject
            $Nodes | Add-Member -Type NoteProperty -Name Upstream -Value @()
            $Nodes | Add-Member -Type NoteProperty -Name Downstream -Value @()
            return $Nodes
        }
        function New-EmptyNode {
            $Node = New-Object PSObject
            $Node | Add-Member -Type NoteProperty -Name Level -Value $Null
            $Node | Add-Member -Type NoteProperty -Name Direction -Value $Null
            $Node | Add-Member -Type NoteProperty -Name ContentId -Value $Null
            $Node | Add-Member -Type NoteProperty -Name Attributes -Value ([ordered]@{ DatabaseNM = $Null; SchemaNM = $Null; TableNM = $Null; FullyQualifiedNM = $Null; BindingCNT = $Null })
            $Node | Add-Member -Type NoteProperty -Name Groups -Value $Null;
            $Node | Add-Member -Type NoteProperty -Name Edges -Value @()
            return $Node
        }
        function New-EmptyEdge {
            $Edge = New-Object PSObject
            $Edge | Add-Member -Type NoteProperty -Name ContentId -Value $Null
            $Edge | Add-Member -Type NoteProperty -Name Attributes -Value ([ordered]@{ DatabaseNM = $Null; SchemaNM = $Null; TableNM = $Null; FullyQualifiedNM = $Null; BindingCNT = $Null })
            $Edge | Add-Member -Type NoteProperty -Name Groups -Value $Null;
            return $Edge
        }
        function Get-Entity ($ContentId) {
            return $Data.Entities[$Data.Entities.ContentId.IndexOf($ContentId)]
        }
        function Get-NodeGroups ($Node) {
            $Groups = [ordered]@{ GroupId = $Null; Group1 = $Null; Group2 = $Null; Group3 = $Null }
            $Attributes = $Node.Attributes
            function IsConfig ($Sources) {
                $IsConfig = $False
                forEach ($Source in $Sources) {
                    if ($Source.TableOrigin -eq 'External' -and $Source.DatabaseNM -ne 'Shared' -and $Source.SchemaNM -notmatch 'Shared__') {
                        $IsConfig = $True
                        return $IsConfig
                    }
                }
                return $IsConfig
            }
            if ($Node.ContentId -and !(Get-Entity -ContentId $Node.ContentId).IsUniversal) {
                #Local
                $Entity = Get-Entity -ContentId $Node.ContentId
                $Groups.Group1 = 'Local'
                if ($Entity.ClassificationCode -like '*Extension') {
                    $Groups.Group2 = 'Extensions'
                }
                elseif ($Entity.DoesOverride) {
                    $Groups.Group2 = 'Overriding'
                }
                elseif ($Entity.IsPublic) {
                    $Groups.Group2 = 'Public'
                }
                elseif ((IsConfig -Sources $Entity.SourcedByEntities) -or $Entity.SchemaNM -match 'Config' -or $Entity.ClassificationCode -eq 'DataEntry') {
                    $Groups.Group2 = 'Configurations'
                }
                elseif ($Entity.ClassificationCode -eq 'ReportingView') {
                    $Groups.Group2 = 'Reports'
                }
                else {
                    $Groups.Group2 = 'Staging'
                    forEach ($Source in $Entity.SourcedByEntities | Where-Object SourceContentId) {
                        if ((Get-Entity -ContentId $Source.SourceContentId).IsPublic) {
                            $Groups.Group2 = 'Reports'
                        }
                    }
                }
                $Groups.Group3 = $Entity.ClassificationCode
            }
            else {
                #External
                $Groups.Group1 = 'External'
                if ($Attributes.DatabaseNM -eq 'SAM') {
                    $Groups.Group2 = 'SubjectArea'
                }
                elseif ($Attributes.DatabaseNM -eq 'Shared') {
                    $Groups.Group2 = 'Shared'
                }
                elseif ($Attributes.DatabaseNM -eq 'EDWAdmin' -or $Attributes.SchemaNM -eq 'CatalystAdmin') {
                    $Groups.Group2 = 'System'
                }
                else {
                    $Groups.Group2 = 'Source'
                }
								
                #default Group3 name
                $Groups.Group3 = $Attributes.DatabaseNM
								
                #except for Azure SQLDB where they put the DB name in the schema
                #if ($Attributes.SchemaNM -match 'SAM__')
                #{
                #	$Groups.Group2 = 'SubjectArea'
                #	$Groups.Group3 = $Attributes.SchemaNM.Substring(0, $Attributes.SchemaNM.LastIndexOf('__'))
                #}
                #elseif ($Attributes.SchemaNM -match 'Shared__')
                #{
                #	$Groups.Group2 = 'Shared'
                #	$Groups.Group3 = $Attributes.SchemaNM.Substring(0, $Attributes.SchemaNM.LastIndexOf('__'))
                #}
                #elseif ($Attributes.SchemaNM.LastIndexOf('__') -ne -1)
                #{
                #	$Groups.Group3 = $Attributes.SchemaNM.Substring(0, $Attributes.SchemaNM.LastIndexOf('__'))
                #}
            }
            $Groups.GroupId = "$($Groups.Group1)_$($Groups.Group2)_$($Groups.Group3)"
            return $Groups
        }
        function New-UpstreamNode ($Entity, $Level) {
            $NewNode = New-EmptyNode
            $NewNode.Level = $Level
            $NewNode.Direction = 'Upstream'
            $NewNode.ContentId = $Entity.ContentId
            $NewNode.Attributes.DatabaseNM = $Entity.DatabaseNM
            $NewNode.Attributes.SchemaNM = $Entity.SchemaNM
            $NewNode.Attributes.TableNM = $Entity.ViewName
            $NewNode.Attributes.FullyQualifiedNM = $Entity.FullyQualifiedNames.View
            $NewNode.Attributes.BindingCNT = if ($Entity.Bindings) { "($(($Entity.Bindings | Measure-Object).Count)) " } else { '' };
            foreach ($Upstream in $Entity.SourcedByEntities) {
                $NewEdge = New-EmptyEdge
                $NewEdge.ContentId = $Upstream.SourceContentId
                $NewEdge.Attributes.DatabaseNM = $Upstream.DatabaseNM
                $NewEdge.Attributes.SchemaNM = $Upstream.SchemaNM
                $NewEdge.Attributes.TableNM = $Upstream.TableNM -replace 'base$', ''
                $NewEdge.Attributes.FullyQualifiedNM = $Upstream.FullyQualifiedNM -replace 'base$', ''
                $NewEdge.Groups = Get-NodeGroups -Node $NewEdge
                $NewNode.Edges += $NewEdge
            }
            $NewNode.Groups = Get-NodeGroups -Node $NewNode
            return $NewNode
        }
        function New-DownstreamNode ($Entity, $Level) {
            $NewNode = New-EmptyNode
            $NewNode.Level = $Level
            $NewNode.Direction = 'Downstream'
            $NewNode.ContentId = $Entity.ContentId
            $NewNode.Attributes.DatabaseNM = $Entity.DatabaseNM
            $NewNode.Attributes.SchemaNM = $Entity.SchemaNM
            $NewNode.Attributes.TableNM = $Entity.ViewName
            $NewNode.Attributes.FullyQualifiedNM = $Entity.FullyQualifiedNames.View
            $NewNode.Attributes.BindingCNT = if ($Entity.Bindings) { "($(($Entity.Bindings | Measure-Object).Count)) " } else { '' };
            foreach ($Downstream in $Data.Entities | Where-Object { $_.SourcedByEntities.SourceContentId -eq $NewNode.ContentId }) {
                $NewEdge = New-EmptyEdge
                $NewEdge.ContentId = $Downstream.ContentId
                $NewEdge.Attributes.DatabaseNM = $Downstream.DatabaseNM
                $NewEdge.Attributes.SchemaNM = $Downstream.SchemaNM
                $NewEdge.Attributes.TableNM = $Downstream.ViewName
                $NewEdge.Attributes.FullyQualifiedNM = $Downstream.FullyQualifiedNames.View
                $NewEdge.Attributes.BindingCNT = if ($Entity.Bindings) { "($(($Entity.Bindings | Measure-Object).Count)) " } else { '' };
                $NewEdge.Groups = Get-NodeGroups -Node $NewEdge
                $NewNode.Edges += $NewEdge
            }
            $NewNode.Groups = Get-NodeGroups -Node $NewNode
            return $NewNode
        }
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
        function Get-LineageCollection {
            [CmdletBinding()]
            param (
                [Parameter(Mandatory = $True)]
                [psobject]$Data,
                [Parameter(Mandatory = $True)]
                [psobject]$Lineage,
                [switch]$keepRef
            )
            begin {
                function Get-ParentChildrenObj {
                    $ParentChildren = New-Object PSObject;
                    $ParentChildren | Add-Member -Type NoteProperty -Name Ordinal -Value $Null;
                    $ParentChildren | Add-Member -Type NoteProperty -Name Parent -Value $Null;
                    $ParentChildren | Add-Member -Type NoteProperty -Name Children -Value @();
                    return $ParentChildren;
                }
            }
            process {
                $Collection = New-Object PSObject
                forEach ($Stream in $Lineage) {
                    $Group1 = $Stream.Groups.Group1;
                    $Group2 = $Stream.Groups.Group2;
                    $Group3 = $Stream.Groups.Group3;
									
                    if (!($Collection.PSobject.Properties.Name -match $Group1)) {
                        $Collection | Add-Member -Type NoteProperty -Name $Group1 -Value (New-Object PSObject)
                    }
                    if (!($Collection.$Group1.PSobject.Properties.Name -match $Group2)) {
                        $Collection.$Group1 | Add-Member -Type NoteProperty -Name $Group2 -Value (New-Object PSObject)
                    }
                    if (!($Collection.$Group1.$Group2.PSobject.Properties.Name -match $Group3)) {
                        $Collection.$Group1.$Group2 | Add-Member -Type NoteProperty -Name $Group3 -Value @()
                    }
                    $Table = New-Object PSObject
                    $Table | Add-Member -Type NoteProperty -Name Level -Value $Stream.Level
                    $Table | Add-Member -Type NoteProperty -Name ContentId -Value $Stream.ContentId
                    $Table | Add-Member -Type NoteProperty -Name FullyQualifiedNM -Value $Stream.Attributes.FullyQualifiedNM
									
                    $Collection.$Group1.$Group2.$Group3 += $Table
                }
								
								
                $LineageArray = @();
                $Level1 = $Collection;
                $PropsLevel1 = $Level1.PSobject.Properties.Name;
                forEach ($PropLevel1 in $PropsLevel1) {
                    $Level1Obj = Get-ParentChildrenObj;
                    $Level1Obj.Parent = $PropLevel1;
                    $Level2 = $Level1.$PropLevel1
                    $PropsLevel2 = $Level2.PSobject.Properties.Name
                    forEach ($PropLevel2 in $PropsLevel2) {
                        $Level2Obj = Get-ParentChildrenObj;
                        $Level2Obj.Parent = $PropLevel2;
                        $Level3 = $Level2.$PropLevel2
                        $PropsLevel3 = $Level3.PSobject.Properties.Name
                        forEach ($PropLevel3 in $PropsLevel3) {
                            $Level3Obj = Get-ParentChildrenObj;
                            $Level3Obj.Parent = $PropLevel3;
                            $Level4 = $Level3.$PropLevel3
                            $Level3Obj.Ordinal = ($Level4.Level | Measure-Object -Average).Average
                            $PropsLevel4 = $Level4
                            $b = 1;
                            forEach ($PropLevel4 in $PropsLevel4 | Sort-Object { $_.FullyQualifiedNM }) {
                                $Level4Obj = Get-ParentChildrenObj;
                                $Level4Obj.Ordinal = $b;
                                $Level4Obj.Parent = $PropLevel4.FullyQualifiedNM;
                                forEach ($ContentId in $PropLevel4 | Where-Object ContentId) {
                                    $Index = $Data.Entities.ContentId.indexOf($ContentId.ContentId)
                                    $Bindings = $Data.Entities[$Index].Bindings.BindingNameNoSpaces | Sort-Object
                                    $a = 1;
                                    forEach ($Binding in $Bindings | Sort-Object) {
                                        $Level5Obj = Get-ParentChildrenObj;
                                        $Level5Obj.Ordinal = $a
                                        $Level5Obj.Parent = $Binding;
                                        $Level4Obj.Children += $Level5Obj;
                                        $a++
                                    }
                                }
                                $Level3Obj.Children += $Level4Obj
                                $b++
                            }
                            $Level2Obj.Children += $Level3Obj
                        }
                        $Multiple = 0;
                        if ($PropLevel2 -eq 'Extensions') {
                            $Multiple = 1000;
                        }
                        $Level2Obj.Ordinal = ($Level3Obj.Ordinal | Measure-Object -Average).Average + $Multiple
                        $Level1Obj.Children += $Level2Obj
                    }
                    $Level1Obj.Ordinal = ($Level2Obj.Ordinal | Measure-Object -Average).Average
                    $LineageArray += $Level1Obj
                }
                return $LineageArray
            }
        }
        #endregion
        #region FUNCTIONS FOR EMPTY DIAGRAM OBJECTS
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
        function New-EmptyDiagramSubgraph {
            $Subgraph = New-Object PSObject
            $Subgraph | Add-Member -Type NoteProperty -Name SubgraphId -Value $Null
            $Subgraph | Add-Member -Type NoteProperty -Name SubgraphName -Value $Null
            $Subgraph | Add-Member -Type NoteProperty -Name Props -Value @()
            $Subgraph | Add-Member -Type NoteProperty -Name Subgraphs -Value @()
            $Subgraph | Add-Member -Type NoteProperty -Name Ports -Value @()
            return $Subgraph
        }
        function New-EmptyDiagramNode {
            $DiagramNode = New-Object PSObject
            $DiagramNode | Add-Member -Type NoteProperty -Name NodeId -Value $Null
            $DiagramNode | Add-Member -Type NoteProperty -Name NodeName -Value $Null
            $DiagramNode | Add-Member -Type NoteProperty -Name Ports -Value @()
            $DiagramNode | Add-Member -Type NoteProperty -Name Props -Value @()
            return $DiagramNode
        }
        function New-EmptyDiagramPort {
            $DiagramPort = New-Object PSObject
            $DiagramPort | Add-Member -Type NoteProperty -Name PortId -Value $Null
            $DiagramPort | Add-Member -Type NoteProperty -Name Props -Value @()
            $DiagramPort | Add-Member -Type NoteProperty -Name Items -Value @()
            $DiagramPort | Add-Member -Type NoteProperty -Name Edges -Value @()
            return $DiagramPort
        }
        function New-EmptyDiagramItem {
            $DiagramItem = New-Object PSObject
            $DiagramItem | Add-Member -Type NoteProperty -Name ItemId -Value $Null
            $DiagramItem | Add-Member -Type NoteProperty -Name ItemName -Value $Null
            $DiagramItem | Add-Member -Type NoteProperty -Name Props -Value @()
            return $DiagramItem
        }
        function New-EmptyDiagramEdge {
            $DiagramEdge = New-Object PSObject
            $DiagramEdge | Add-Member -Type NoteProperty -Name From -Value (New-Object PSObject -Property @{ NodeId = $Null; PortId = $Null; })
            $DiagramEdge | Add-Member -Type NoteProperty -Name To -Value (New-Object PSObject -Property @{ NodeId = $Null; PortId = $Null; })
            return $DiagramEdge
        }
        #endregion
        #region FUNCTIONS FOR ERD DIAGRAMS
        function New-Erd {
            param
            (
                [Parameter(Mandatory = $True, Position = 0)]
                [psobject]$Data
            )
							
            #Gcreate a new ERD object using the datamart name as the ERD name
            $Erd = New-EmptyDiagramGraph -Name Erd -Types @('Full', 'Minimal')
            $Erd.Erd.Data.GraphId = """" + $Data.DatamartNM + """"
            $Erd.Erd.Data.GraphName = $Data.DatamartNM
							
            #Get all the entities that we want to be nodes in the ERD diagram
            $Entities = $Data.Entities | Where-Object $validPublicEntities
							
							
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
        #endregion
        #region FUNCTIONS FOR DFD DIAGRAMS
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
        #endregion						
    }
    process {
        $Msg = "DOCS - $($Data._hcposh.FileBaseName)"; Write-Host $Msg -ForegroundColor Magenta; Write-Verbose $Msg; Write-Log $Msg;
        #region ADD LINEAGE
        try {
            $Msg = "$(" " * 4)Adding entity data lineage..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
            foreach ($Entity in $Data.Entities) {
                $Entity | Add-Member -Type NoteProperty -Name Lineage -Value @()
                $Entity.Lineage = New-Nodes -entity $Entity
            }
        }
        catch {
            $Msg = "$(" " * 8)Unable to add data lineage properties"; Write-Host $Msg -ForegroundColor Yellow; Write-Verbose $Msg; Write-Log $Msg 'warning';
            $Msg = "$(" " * 8)$($Error[0])"; Write-Host $Msg -ForegroundColor Yellow; Write-Verbose $Msg; Write-Log $Msg 'warning';
        }
        #endregion
        #region ADD DIAGRAMS
        $Data | Add-Member -Type NoteProperty -Name Diagrams -Value (New-Object PSObject -Property @{ Erd = $Null; Dfd = $Null; DfdUpstream = $Null; DfdDownstream = $Null })
        #region ERD
        try {
            $Msg = "$(" " * 4)Adding erd diagram..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
            $Data.Diagrams.Erd = (New-Erd -Data $Data).Erd
							
            if (!$KeepFullLineage) {
                #Remove un-needed properties
                if (($Data.Diagrams.Erd.PSobject.Properties.Name -match 'Data')) {
                    $Data.Diagrams.Erd.PSObject.Properties.Remove('Data')
                }
            }							
        }
        catch {
            $Msg = "$(" " * 8)Unable to add erd diagram"; Write-Host $Msg -ForegroundColor Yellow; Write-Verbose $Msg; Write-Log $Msg 'warning';
        }
        #endregion
        #region DFD
        $Msg = "$(" " * 4)Adding dfd diagrams..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
        try {
            $Data.Diagrams.Dfd = (New-Dfd -Name $Data.DatamartNM -Lineage ($Data.Entities | Where-Object $validPublicEntities).Lineage -Type Both).Dfd
            $Data.Diagrams.DfdUpstream = (New-Dfd -Name $Data.DatamartNM -Lineage ($Data.Entities | Where-Object $validPublicEntities).Lineage -Type Upstream).Dfd
            $Data.Diagrams.DfdDownstream = (New-Dfd -Name $Data.DatamartNM -Lineage ($Data.Entities | Where-Object $validPublicEntities).Lineage -Type Downstream).Dfd
							
            if (!$KeepFullLineage) {
                #Remove un-needed properties
                if (($Data.Diagrams.Dfd.PSobject.Properties.Name -match 'Data')) {
                    $Data.Diagrams.Dfd.PSObject.Properties.Remove('Data')
                }
                if (($Data.Diagrams.DfdUpstream.PSobject.Properties.Name -match 'Data')) {
                    $Data.Diagrams.DfdUpstream.PSObject.Properties.Remove('Data')
                }
                if (($Data.Diagrams.DfdDownstream.PSobject.Properties.Name -match 'Data')) {
                    $Data.Diagrams.DfdDownstream.PSObject.Properties.Remove('Data')
                }
            }							
							
            #ADD DFD DIAGRAM TO EVERY PUBLIC ENTITY
            forEach ($PublicEntity in $Data.Entities | Where-Object $validPublicEntities) {
                if ($PublicEntity.SourcedByEntities) {
                    $PublicEntity | Add-Member -Type NoteProperty -Name Diagrams -Value (New-Object PSObject -Property @{ Dfd = $Null; DfdUpstream = $Null; DfdDownstream = $Null })
                    $Msg = "$(" " * 4)Adding dfd diagrams...$($PublicEntity.FullyQualifiedNames.Table)..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
                    $PublicEntity.Diagrams.Dfd = (New-Dfd -Name $PublicEntity.FullyQualifiedNames.Table -Lineage $PublicEntity.Lineage -Type Both).Dfd
                    $PublicEntity.Diagrams.DfdDownstream = (New-Dfd -Name $PublicEntity.FullyQualifiedNames.Table -Lineage $PublicEntity.Lineage -Type Downstream).Dfd
                    $PublicEntity.Diagrams.DfdUpstream = (New-Dfd -Name $PublicEntity.FullyQualifiedNames.Table -Lineage $PublicEntity.Lineage -Type Upstream).Dfd
                }
            }
        }
        catch {
            $Msg = "$(" " * 8)Requirements not met for dfd diagrams:`n$(" " * 10)At least 1 public ""summary"" entity for Framework SAM or 1 public entity in Generic SAM"; Write-Host $Msg -ForegroundColor Yellow; Write-Verbose $Msg; Write-Log $Msg 'warning';
        }
						
        #Replace Lineage property with a cleaner version for display purposes
        forEach ($Entity in $Data.Entities | Where-Object $validPublicEntities) {
            $Upstream = Get-LineageCollection -Lineage $Entity.Lineage.Upstream -Data $Data;
            $Downstream = New-Object PSObject;
            if ($($Entity.Lineage.Downstream | Where-Object Level -NE 0)) {
                $Downstream = Get-LineageCollection -Lineage $($Entity.Lineage.Downstream | Where-Object Level -NE 0) -Data $Data;
            }
            $Entity | Add-Member -Type NoteProperty -Name LineageMinimal -Value (
                New-Object PSObject -Property @{
                    Upstream   = $Upstream;
                    Downstream = $Downstream;
                }
            )
        }
        if (!$KeepFullLineage) {
            forEach ($Entity in $Data.Entities) {
                if (($Entity.PSobject.Properties.Name -match 'Lineage')) {
                    $Entity.PSObject.Properties.Remove('Lineage')
                }
            }
        }
						
        #endregion						
        #endregion
        #region ADD COUNT DETAILS
        $Sources = New-Object PSObject
        $Sources | Add-Member -Type NoteProperty -Name DelimitedList -Value (($Data.SourcedByEntities | Where-Object { $_.TableOrigin -eq 'External' -and $_.DatabaseNM -notin @('Shared', 'IDEA') } | Group-Object DatabaseNM).Name -join ', ');
        $Sources | Add-Member -Type NoteProperty -Name List -Value ($Data.SourcedByEntities | Where-Object { $_.TableOrigin -eq 'External' -and $_.DatabaseNM -notin @('Shared', 'IDEA') } | Group-Object DatabaseNM | Select-Object Name).Name;
        $Sources | Add-Member -Type NoteProperty -Name Count -Value (($Data.SourcedByEntities | Where-Object { $_.TableOrigin -eq 'External' -and $_.DatabaseNM -notin @('Shared', 'IDEA') } | Group-Object DatabaseNM | Measure-Object).Count);
        $Sources | Add-Member -Type NoteProperty -Name EntitiesCount -Value (($Data.SourcedByEntities | Where-Object { $_.TableOrigin -eq 'External' -and $_.DatabaseNM -notin @('Shared', 'IDEA') } | Measure-Object).Count);
						
        $Entities = New-Object PSObject
        $Entities | Add-Member -Type NoteProperty -Name Count -Value ($Data.Entities | Measure-Object).Count;
        $Entities | Add-Member -Type NoteProperty -Name PersistedCount -Value ($Data.Entities | Where-Object { $_.IsPersisted } | Measure-Object).Count;
        $Entities | Add-Member -Type NoteProperty -Name NonPersistedCount -Value ($Data.Entities | Where-Object { !($_.IsPersisted) } | Measure-Object).Count;
        $Entities | Add-Member -Type NoteProperty -Name ProtectedCount -Value ($Data.Entities | Where-Object { $_.IsProtected } | Measure-Object).Count;
        $Entities | Add-Member -Type NoteProperty -Name PublicCount -Value ($Data.Entities | Where-Object { $_.IsPublic } | Measure-Object).Count;
						
        $Columns = New-Object PSObject
        $Columns | Add-Member -Type NoteProperty -Name PublicCount -Value (($Data.Entities | Where-Object { $_.IsPublic }).Columns | Measure-Object).Count;
        $Columns | Add-Member -Type NoteProperty -Name ExtendedCount -Value (($Data.Entities | Where-Object { $_.IsPublic }).Columns | Where-Object { $_.IsExtended } | Measure-Object).Count;
						
        $Bindings = New-Object PSObject
        $Bindings | Add-Member -Type NoteProperty -Name Count -Value ($Data.Entities.Bindings | Where-Object { $_.BindingStatus -eq 'Active' } | Measure-Object).Count;
        $Bindings | Add-Member -Type NoteProperty -Name ProtectedCount -Value ($Data.Entities.Bindings | Where-Object { $_.BindingStatus -eq 'Active' -and $_.IsProtected } | Measure-Object).Count;
        $Bindings | Add-Member -Type NoteProperty -Name FullCount -Value ($Data.Entities.Bindings | Where-Object { $_.LoadType -eq 'Full' -and $_.BindingStatus -eq 'Active' } | Measure-Object).Count;
        $Bindings | Add-Member -Type NoteProperty -Name IncrementalCount -Value ($Data.Entities.Bindings | Where-Object { $_.LoadType -eq 'Incremental' -and $_.BindingStatus -eq 'Active' } | Measure-Object).Count;
						
        $Indexes = New-Object PSObject
        $Indexes | Add-Member -Type NoteProperty -Name ClusteredCount -Value ($Data.Entities.Indexes | Where-Object { $_.IndexTypeCode -eq 'Clustered' -and $_.IsActive } | Measure-Object).Count;
        $Indexes | Add-Member -Type NoteProperty -Name NonClusteredCount -Value ($Data.Entities.Indexes | Where-Object { $_.IndexTypeCode -eq 'Non-Clustered' -and $_.IsActive } | Measure-Object).Count;
						
        $Counts = New-Object PSObject
        $Counts | Add-Member -Type NoteProperty -Name Sources -Value $Sources;
        $Counts | Add-Member -Type NoteProperty -Name Entities -Value $Entities;
        $Counts | Add-Member -Type NoteProperty -Name Columns -Value $Columns;
        $Counts | Add-Member -Type NoteProperty -Name Bindings -Value $Bindings;
        $Counts | Add-Member -Type NoteProperty -Name Indexes -Value $Indexes;
						
        $Data | Add-Member -Type NoteProperty -Name Counts -Value $Counts;
        #endregion
        #region REMOVE DATA_ALL PROPERTY (UNECESSARY FOR DOCS)
        foreach ($Entity in $Data.Entities) {
            if ($Entity.DataEntryData) {
                if ($Entity.DataEntryData.Data_All) {
                    $Entity.DataEntryData.PSObject.Properties.Remove('Data_All')
                }
            }
        }
        #endregion
						
        $Data._hcposh.LastWriteTime = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.ffffff")
						
        #Directories
        $DataDir = "$($OutDir)\static\data"; New-Directory -Dir $DataDir;
						
        #Files
        $DocsSourcePath = "$((Get-Item $PSScriptRoot).Parent.FullName)\templates\docs\*";
        $DocsDestinationPath = $OutDir;
        $DataFilePath = "$($DataDir)\dataMart.js";
        try {
            if (($Data.Entities | Where-Object $validPublicEntities | Measure-Object).Count -eq 0) { throw; }
            Copy-Item -Path $DocsSourcePath -Recurse -Destination $DocsDestinationPath -Force
            'dataMart = ' + ($Data | ConvertTo-Json -Depth 100 -Compress) | Out-File $DataFilePath -Encoding Default -Force | Out-Null
            $Msg = "$(" " * 4)Created new file --> $($Data._hcposh.FileBaseName)\$(Split-Path $DataDir -Leaf)\$(Split-Path $DataFilePath -Leaf)."; Write-Host $Msg -ForegroundColor Cyan; Write-Verbose $Msg; Write-Log $Msg;
        }
        catch {
            $Msg = "$(" " * 4)Unable to find valid public entities or An error occurred when trying to create the docs folder structure"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
        }
        if ($OutZip) {
            try {
                Zip -Directory $DocsDestinationPath -Destination ($DocsDestinationPath + '_docs.zip')
                if (Test-Path $DocsDestinationPath) {
                    Remove-Item $DocsDestinationPath -Recurse -Force | Out-Null
                }
                $Msg = "$(" " * 4)Zipped file of directory --> $($DocsDestinationPath + '_docs.zip')"; Write-Host $Msg -ForegroundColor Cyan; Write-Verbose $Msg; Write-Log $Msg;
            }
            catch {
                $Msg = "$(" " * 4)Unable to zip the docs directory"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
            }
        }
        $Msg = "Success!`r`n"; Write-Host $Msg -ForegroundColor Green; Write-Verbose $Msg; Write-Log $Msg;
        $Output = New-Object PSObject
        $Output | Add-Member -Type NoteProperty -Name DocsData -Value $Data
        return $Output
    }
}