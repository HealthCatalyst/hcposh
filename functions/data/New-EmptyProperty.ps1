function New-EmptyProperty {
    $Property = New-Object PSObject
    $Property | Add-Member -Type NoteProperty -Name Name -Value $Null
    $Property | Add-Member -Type NoteProperty -Name Property -Value $Null
    $Property | Add-Member -Type NoteProperty -Name Value -Value $Null
    return $Property
}
