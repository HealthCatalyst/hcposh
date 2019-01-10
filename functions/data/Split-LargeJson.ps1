function Split-LargeJsonItem($jsonItem) {
    if ($jsonItem.PSObject.TypeNames -match 'Array') {
        return Split-LargeJsonArray($jsonItem)
    }
    elseif ($jsonItem.PSObject.TypeNames -match 'Dictionary') {
        return Split-LargeJsonObject([HashTable]$jsonItem)
    }
    else {
        return $jsonItem
    }
}
function Split-LargeJsonObject($jsonObj) {
    $result = New-Object -TypeName PSCustomObject
    foreach ($key in $jsonObj.Keys) {
        $item = $jsonObj[$key]
        if ($item) {
            $parsedItem = Split-LargeJsonItem $item
        }
        else {
            $parsedItem = $null
        }
        $result | Add-Member -MemberType NoteProperty -Name $key -Value $parsedItem
    }
    return $result
}
function Split-LargeJsonArray($jsonArray) {
    $result = @()
    $jsonArray | ForEach-Object -Process {
        $result += , (Split-LargeJsonItem $_)
    }
    return $result
}