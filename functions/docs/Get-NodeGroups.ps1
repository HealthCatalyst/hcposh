function Get-NodeGroups ($Node) {
    $Groups = [ordered]@{ GroupId = $Null; Group1 = $Null; Group2 = $Null; Group3 = $Null }
    $Attributes = $Node.Attributes
    function IsConfig ($Sources) {
        $IsConfig = $False
        forEach ($Source in $Sources) {
            if ($Source.TableOrigin -eq 'External' -and $Source.DatabaseNM -ne 'Shared' -and $Source.SchemaNM -notmatch 'Shared__') {
                $IsConfig = $True
                return $IsConfig
            }
        }
        return $IsConfig
    }
    if ($Node.ContentId -and !(Get-Entity -ContentId $Node.ContentId).IsUniversal) {
        #Local
        $Entity = Get-Entity -ContentId $Node.ContentId
        $Groups.Group1 = 'Local'
        if ($Entity.ClassificationCode -like '*Extension') {
            $Groups.Group2 = 'Extensions'
        }
        elseif ($Entity.DoesOverride) {
            $Groups.Group2 = 'Overriding'
        }
        elseif ($Entity.IsPublic) {
            $Groups.Group2 = 'Public'
        }
        elseif ((IsConfig -Sources $Entity.SourcedByEntities) -or $Entity.SchemaNM -match 'Config' -or $Entity.ClassificationCode -eq 'DataEntry') {
            $Groups.Group2 = 'Configurations'
        }
        elseif ($Entity.ClassificationCode -eq 'ReportingView') {
            $Groups.Group2 = 'Reports'
        }
        else {
            $Groups.Group2 = 'Staging'
            forEach ($Source in $Entity.SourcedByEntities | Where-Object SourceContentId) {
                if ((Get-Entity -ContentId $Source.SourceContentId).IsPublic) {
                    $Groups.Group2 = 'Reports'
                }
            }
        }
        $Groups.Group3 = $Entity.ClassificationCode
    }
    else {
        #External
        $Groups.Group1 = 'External'
        if ($Attributes.DatabaseNM -eq 'SAM') {
            $Groups.Group2 = 'SubjectArea'
        }
        elseif ($Attributes.DatabaseNM -eq 'Shared') {
            $Groups.Group2 = 'Shared'
        }
        elseif ($Attributes.DatabaseNM -eq 'EDWAdmin' -or $Attributes.SchemaNM -eq 'CatalystAdmin') {
            $Groups.Group2 = 'System'
        }
        else {
            $Groups.Group2 = 'Source'
        }
                        
        #default Group3 name
        $Groups.Group3 = $Attributes.DatabaseNM
                        
        #except for Azure SQLDB where they put the DB name in the schema
        #if ($Attributes.SchemaNM -match 'SAM__')
        #{
        #	$Groups.Group2 = 'SubjectArea'
        #	$Groups.Group3 = $Attributes.SchemaNM.Substring(0, $Attributes.SchemaNM.LastIndexOf('__'))
        #}
        #elseif ($Attributes.SchemaNM -match 'Shared__')
        #{
        #	$Groups.Group2 = 'Shared'
        #	$Groups.Group3 = $Attributes.SchemaNM.Substring(0, $Attributes.SchemaNM.LastIndexOf('__'))
        #}
        #elseif ($Attributes.SchemaNM.LastIndexOf('__') -ne -1)
        #{
        #	$Groups.Group3 = $Attributes.SchemaNM.Substring(0, $Attributes.SchemaNM.LastIndexOf('__'))
        #}
    }
    $Groups.GroupId = "$($Groups.Group1)_$($Groups.Group2)_$($Groups.Group3)"
    return $Groups
}
