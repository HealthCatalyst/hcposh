function New-HCEmptyIndexObject {
    $Index = New-Object PSObject
    $Index | Add-Member -Type NoteProperty -Name IndexName -Value $Null
    $Index | Add-Member -Type NoteProperty -Name IndexTypeCode -Value $Null
    $Index | Add-Member -Type NoteProperty -Name IsActive -Value $Null
    $Index | Add-Member -Type NoteProperty -Name IndexColumns -Value @()
    
    return $Index
}
