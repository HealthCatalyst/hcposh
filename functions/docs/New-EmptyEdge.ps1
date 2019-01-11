function New-EmptyEdge {
    $Edge = New-Object PSObject
    $Edge | Add-Member -Type NoteProperty -Name ContentId -Value $Null
    $Edge | Add-Member -Type NoteProperty -Name Attributes -Value ([ordered]@{ DatabaseNM = $Null; SchemaNM = $Null; TableNM = $Null; FullyQualifiedNM = $Null; BindingCNT = $Null })
    $Edge | Add-Member -Type NoteProperty -Name Groups -Value $Null;
    return $Edge
}
