function Split-ObjectToFiles {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName)]
        [psobject]$Data,
        [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName)]
        [string]$SplitDirectory
    )
    process {
        try {
            #create base directory
            New-Directory -Dir $SplitDirectory -Force
            
            #region CREATE DATAMART FILES
            $Exclusions = @('DatamartNoSpacesNM', 'Entities', 'SourcedByEntities', '_hcposh', 'MaxLastModifiedTimestamp')
            $Out = @()
            $Props = $Data.psobject.properties.name | Where-Object { $Data.$_ }
            forEach ($Prop in $Props | Where-Object { $_ -NotIn $Exclusions }) {
                $OutObj = New-EmptyProperty
                $OutObj.Name = $Data.DatamartNM
                $OutObj.Property = $Prop
                $OutObj.Value = $Data."$($OutObj.Property)"
                if ($OutObj) { $Out += $OutObj }
            }
            $OutFile = "$($SplitDirectory)\_Datamart.csv"
            if ($Out) {
                $Out | Sort-Object Name, @{
                    e = {
                        if ($_.Property -eq 'ContentId') { 0 }
                        else { 1 }
                    }
                }, Property | Export-Csv $OutFile -Force -NoTypeInformation
            }
            #endregion
            #region CREATE SOURCE FILES
            $SourcedByColumns = @()
            forEach ($Entity in $Data.SourcedByEntities | Where-Object TableOrigin -eq 'External' | Sort-Object FullyQualifiedNM) {
                forEach ($Column in $Entity.SourcedByColumns | Sort-Object FullyQualifiedNM) {
                    $SourcedByColumn = New-Object PSObject
                    $SourcedByColumn | Add-Member -Type NoteProperty -Name DatabaseNM -Value $Entity.DatabaseNM
                    $SourcedByColumn | Add-Member -Type NoteProperty -Name SchemaNM -Value $Entity.SchemaNM
                    $SourcedByColumn | Add-Member -Type NoteProperty -Name TableNM -Value $Entity.TableNM
                    $SourcedByColumn | Add-Member -Type NoteProperty -Name ColumnNM -Value $Column.ColumnNM
                    $SourcedByColumns += $SourcedByColumn
                }
            }
            $ByDatabase = $SourcedByColumns | Group-Object DatabaseNM
            forEach ($db in $ByDatabase) {
                $db.Group | Sort-Object SchemaNM, TableNM, ColumnNM | Export-Csv -NoTypeInformation "$SplitDirectory\Sources-$($db.Name).csv" -Force | Out-Null
            }
            #endregion
            #region CREATE ENTITY FILES
            $Exclusions = @('Bindings', 'Columns', 'Indexes', 'SourcedByEntities', 'FullyQualifiedNames', 'LastModifiedTimestamp', 'DataEntryData', 'OverridingExtensionView')
            forEach ($Group in $Data.Entities | Group-Object ClassificationCode) {
                $Out = @()
                forEach ($Entity in $Group.Group) {
                    $Props = $Entity.psobject.properties.name | Where-Object { $_ }
                    forEach ($Prop in $Props | Where-Object { $_ -NotIn $Exclusions }) {
                        $OutObj = New-EmptyProperty
                        $OutObj.Name = $Entity.FullyQualifiedNames.Table
                        $OutObj.Property = $Prop
                        $OutObj.Value = $($Entity."$($OutObj.Property)" -replace "`r`n", "")
                        if ($OutObj) { $Out += $OutObj }
                    }
                }
                $OutFile = "$($SplitDirectory)\Entities-$($Group.Name).csv"
                if ($Out) {
                    $Out | Sort-Object Name, @{
                        e = {
                            if ($_.Property -eq 'ContentId') { 0 }
                            else { 1 }
                        }
                    }, Property | Export-Csv $OutFile -Force -NoTypeInformation
                }
            }
            #endregion
            #region CREATE BINDING FILES
            $Exclusions = @('BindingNameNoSpaces', 'UserDefinedSQL', 'SourcedByEntities', 'IncrementalConfigurations')
            forEach ($Group in $Data.Entities.Bindings | Group-Object ClassificationCode) {
                $Out = @()
                forEach ($Binding in $Group.Group) {
                    $Props = $Binding.psobject.properties.name | Where-Object { $_ }
                    forEach ($Prop in $Props | Where-Object { $_ -NotIn $Exclusions }) {
                        $OutObj = New-EmptyProperty
                        $OutObj.Name = $Binding.BindingName
                        $OutObj.Property = $Prop
                        $OutObj.Value = $($Binding."$($OutObj.Property)" -replace "`r`n", "")
                        if ($OutObj) { $Out += $OutObj }
                    }
                }
                $OutFile = "$($SplitDirectory)\Bindings-$($Group.Name).csv"
                if ($Out) {
                    $Out | Sort-Object Name, @{
                        e = {
                            if ($_.Property -eq 'ContentId') { 0 }
                            else { 1 }
                        }
                    }, Property | Export-Csv $OutFile -Force -NoTypeInformation
                }
            }
            #endregion
            #region CREATE SQL FILES
            forEach ($Binding in $Data.Entities.Bindings) {
                $OutFile = "$($SplitDirectory)\SQL-$($Binding.ClassificationCode)-$(Get-CleanFileName $Binding.BindingName -RemoveSpace).sql"
                $Binding.UserDefinedSQL | Out-File $OutFile -Encoding Default -Force
            }
            #endregion
            #region CREATE COLUMN FILES
            $Exclusions = @('Ordinal')
            forEach ($Group in $Data.Entities | Group-Object ClassificationCode) {
                $Out = @()
                forEach ($Entity in $Group.Group) {
                    forEach ($Column in $Entity.Columns) {
                        $Props = $Column.psobject.properties.name | Where-Object { $_ }
                        forEach ($Prop in $Props | Where-Object { $_ -NotIn $Exclusions }) {
                            $OutObj = New-EmptyProperty
                            $OutObj.Name = "$($Entity.FullyQualifiedNames.Table).$($Column.ColumnNM)"
                            $OutObj.Property = $Prop
                            $OutObj.Value = $($Column."$($OutObj.Property)" -replace "`r`n", "")
                            if ($OutObj) { $Out += $OutObj }
                        }
                    }
                }
                $OutFile = "$($SplitDirectory)\Columns-$($Group.Name).csv"
                if ($Out) {
                    $Out | Sort-Object Name, @{
                        e = {
                            if ($_.Property -eq 'ContentId') { 0 }
                            else { 1 }
                        }
                    }, Property | Export-Csv $OutFile -Force -NoTypeInformation
                }
            }
            #endregion
            #region CREATE INDEX FILES
            $Exclusions = @('IndexName')
            forEach ($Group in $Data.Entities | Group-Object ClassificationCode) {
                $Out = @()
                forEach ($Entity in $Group.Group) {
                    forEach ($Index in $Entity.Indexes) {
                        $Props = $Index.psobject.properties.name | Where-Object { $_ }
                        forEach ($Prop in $Props | Where-Object { $_ -NotIn $Exclusions }) {
                            $OutObj = New-EmptyProperty
                            $OutObj.Name = "$($Entity.FullyQualifiedNames.Table).$($Index.IndexName)"
                            $OutObj.Property = $Prop
                            if ($Prop -eq 'IndexColumns') {
                                $OutObj.Value = $(($Index."$($OutObj.Property)" | Sort-Object ColumnNM).ColumnNM -join " | ")
                            }
                            else {
                                $OutObj.Value = $($Index."$($OutObj.Property)" -replace "`r`n", "")
                            }
                            if ($OutObj) { $Out += $OutObj }
                        }
                    }
                }
                $OutFile = "$($SplitDirectory)\Indexes-$($Group.Name).csv"
                if ($Out) {
                    $Out | Sort-Object Name, @{
                        e = {
                            if ($_.Property -eq 'ContentId') { 0 }
                            else { 1 }
                        }
                    }, Property | Export-Csv $OutFile -Force -NoTypeInformation
                }
            }
            #endregion
            #region CREATE INCREMENTAL CONFIG FILES
            $Exclusions = @()
            forEach ($Group in $Data.Entities.Bindings | Group-Object ClassificationCode) {
                $Out = @()
                forEach ($Binding in $Group.Group) {
                    forEach ($Increment in $Binding.IncrementalConfigurations) {
                        $Props = $Increment.psobject.properties.name | Where-Object { $_ }
                        forEach ($Prop in $Props | Where-Object { $_ -NotIn $Exclusions }) {
                            $OutObj = New-EmptyProperty
                            $OutObj.Name = $Binding.BindingName
                            $OutObj.Property = $Prop
                            $OutObj.Value = $($Increment."$($OutObj.Property)" -replace "`r`n", "")
                            if ($null -ne $OutObj.Value -and $OutObj.Value -ne "") { $Out += $OutObj | Sort-Object { $_.Property, $_.Value } }
                        }
                    }
                }
                $OutFile = "$($SplitDirectory)\IncrementalConfigurations-$($Group.Name).csv"
                if ($Out) {
                    $Out | Sort-Object Name, @{
                        e = {
                            if ($_.Property -eq 'ContentId') { 0 }
                            else { 1 }
                        }
                    }, Property | Export-Csv $OutFile -Force -NoTypeInformation
                }
            }
            #endregion
            #region CREATE DATA ENTRY ENTITY FILES
            ForEach ($Entity in $Data.Entities | Where-Object { $_.ClassificationCode -eq 'DataEntry' }) {
                If ($Entity.DataEntryData) {
                    $OutFile = "$($SplitDirectory)\DataEntryData-$(Get-CleanFileName $Entity.DataEntryData.FullyQualifiedNM -RemoveSpace).csv"
                    if ($Entity.DataEntryData.Data_All) {
                        $Entity.DataEntryData.Data_All | Export-Csv $OutFile -NoTypeInformation -Force
                    }
                }
            }
            #endregion
            #region CREATE ISSUE FILES
            if (($Data.Entities.Bindings.SourcedByEntities.SourcedByPossibleColumns | Measure-Object).Count -gt 0) {
                $Out = @()
                forEach ($Binding in $Data.Entities.Bindings) {
                    forEach ($Issue in $Binding.SourcedByEntities.SourcedByPossibleColumns) {
                        $OutObj = New-EmptyProperty
                        $OutObj.Name = $Binding.BindingName
                        $OutObj.Property = "Missing Alias - Unable To Parse"
                        $OutObj.Value = $Issue.FullyQualifiedNM
                        if ($OutObj.Value) { $Out += $OutObj }
                    }
                }
                $OutFile = "$($SplitDirectory)\_ISSUES-Bindings-MissingAlias.csv"
                if ($Out) {
                    $Out | Sort-Object Name, @{
                        e = {
                            if ($_.Property -eq 'ContentId') { 0 }
                            else { 1 }
                        }
                    }, Property | Export-Csv $OutFile -Force -NoTypeInformation
                }
            }
            #endregion
            #Get-Date | Out-File $SplitDirectory\_lastmodified.txt -Encoding Default -Force | Out-Null
        }
        catch {            
            $ErrorMessage = $_.Exception.Message
            $Msg = "$(" " * 8)An error occurred while trying to split data object into smaller files :( --> $ErrorMessage"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
            Exit
        }
    }
}