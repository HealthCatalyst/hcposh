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
