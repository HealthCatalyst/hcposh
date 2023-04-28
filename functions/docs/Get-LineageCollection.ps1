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
                            
            if (!($Collection.PSobject.Properties.Name -match "^$Group1`$")) {
                $Collection | Add-Member -Type NoteProperty -Name $Group1 -Value (New-Object PSObject)
            }
            if (!($Collection.$Group1.PSobject.Properties.Name -match "^$Group2`$")) {
                $Collection.$Group1 | Add-Member -Type NoteProperty -Name $Group2 -Value (New-Object PSObject)
            }
            if (!($Collection.$Group1.$Group2.PSobject.Properties.Name -match "^$Group3`$")) {
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