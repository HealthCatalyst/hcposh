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
