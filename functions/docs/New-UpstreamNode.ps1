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
