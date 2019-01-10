function New-HCEmptyFullyQualifiedNameObject {
    $FullyQualifiedName = New-Object PSObject
    $FullyQualifiedName<#extension#> | Add-Member -Type NoteProperty -Name Table -Value $Null
    $FullyQualifiedName<#extension#> | Add-Member -Type NoteProperty -Name View -Value $Null
    
    return $FullyQualifiedName
}
