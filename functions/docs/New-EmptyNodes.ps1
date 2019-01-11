function New-EmptyNodes {
    $Nodes = New-Object PSObject
    $Nodes | Add-Member -Type NoteProperty -Name Upstream -Value @()
    $Nodes | Add-Member -Type NoteProperty -Name Downstream -Value @()
    return $Nodes
}
