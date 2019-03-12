function Invoke-Installer {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName)]
        [string]$File,
        [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName)]
        [string]$OutDir
    )
    begin {
        $versionMinimum = [Version]'5.0'
        if ($versionMinimum -gt $PSVersionTable.PSVersion)
        { throw "This script requires PowerShell $versionMinimum" }

        # Get function definition files.
        $Functions = @( Get-ChildItem -Path "$PSScriptRoot\installer" -Filter *.ps1 -ErrorAction SilentlyContinue )

        # Dot source the files
        foreach ($Import in @($Functions)) {
            try {
                . $Import.fullname
            }
            catch {
                Write-Error -Message "Failed to import function $($Import.fullname): $_"
            }
        }

        function True {return "1"}
        function False {return "0"}
        function NullableString {
            param([string] $Text)
            if ([string]::IsNullOrEmpty($Text)) {
                return [nullstring]::value
            }
            else {
                return $Text -replace "‘‘", """" -replace "’’", """" -replace "’", "'"
            }
        }        
    }
    process {
        try {
            Test-Path $File | Out-Null;
            $InputFile = Get-Item $File
            $FileDirectory = Split-Path $File -Parent
            $Msg = "INSTALLER - $(Split-Path $File -Leaf)"; Write-Host $Msg -ForegroundColor Magenta; Write-Verbose $Msg; Write-Log $Msg;
        }
        catch {
            $Msg = "$(" " * 8)Unable to find any hcx files."; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
        }

        if ($InputFile.Extension -eq '.hcx') {
            try {
                $Msg = "$(" " * 4)Unzipping hcx file..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
                
                Copy-Item -Path $File -Destination $File.Replace('.hcx', '.zip') -Force | Out-Null
                $ZipFile = $File.Replace('.hcx', '.zip')
                
                $OutBin = "$($FileDirectory)\$((Split-Path $File -Leaf).Replace('.hcx', '_bin'))"
                $Zipoutdir = "$($OutBin)\$((Split-Path $File -Leaf).Replace('.hcx', '_zip'))"
                if (Test-Path $OutBin) {
                    Remove-Item $OutBin -Force -Recurse | Out-Null
                }
                If (!(Test-Path $Zipoutdir)) {
                    New-Item -ItemType Directory -Force -Path $Zipoutdir -ErrorAction Stop | Out-Null
                }
                Unzip -file $ZipFile -destination $Zipoutdir
                Remove-Item $ZipFile -Force | Out-Null
            }
            catch {
                $Msg = "$(" " * 8)Unable to unzip file."; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
            }
            $Msg = "$(" " * 4)Getting sam json object..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
            $DataFile = Get-ChildItem $Zipoutdir -Recurse | Where-Object { $_.Extension -eq ".sam" }
        }
        elseif ($InputFile.Extension -eq '.sm') {
            $Msg = "$(" " * 4)Getting sm json object..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
            $DataFile = $InputFile
        }

        $RawContent = (Get-Content $DataFile.FullName | Select-Object -Skip 1);
        try {
            $jsonSettings = New-Object Newtonsoft.Json.JsonSerializerSettings
            $jsonSettings.TypeNameHandling = 'Objects'
            $jsonSettings.PreserveReferencesHandling = 'Objects'
            $RawData = [Newtonsoft.Json.JsonConvert]::DeserializeObject($RawContent, $jsonSettings)
            if (Test-Path $OutBin) {
                Remove-Item $OutBin -Recurse -Force
            }
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            $Msg = "$(" " * 8)Unable to deserialize json object :( --> $ErrorMessage"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
            Exit
        }

        $Msg = "$(" " * 4)Formatting raw data to MDS format..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;

        $id = [Id]::new()
        $ids = @{}
        function GetId($contentId) {
            if (!$ids.ContainsKey($contentId)) {
                $ids.Add($contentId, $id.GetNewId())
            }
            return $ids.Item($contentId)
        }            

        $DataMart = [DataMart]::new()
        $DataMart.Id = GetId($RawData.ContentId)
        $DataMart.ContentId = $RawData.ContentId
        $DataMart.Name = NullableString($RawData.DataMartNM)
        $DataMart.DataMartType = ($RawData.DataMartTypeDSC)
        $DataMart.Description = NullableString($RawData.DescriptionTXT)
        $DataMart.SqlAgentProxyName = NullableString($RawData.SqlAgentProxyName)
        $DataMart.SqlCredentialName = NullableString($RawData.SqlCredentialName)
        $DataMart.DefaultEngineVersion = $RawData.DefaultEngineVersionNumber
        $DataMart.SystemName = NullableString($RawData.SystemNM)
        $DataMart.DataStewardFullName = NullableString($RawData.DataStewardFullNM)
        $DataMart.DataStewardEmail = NullableString($RawData.DataStewardEmailTXT)
        $DataMart.Version = NullableString($RawData.VersionText)
        $DataMart.IsHidden = NullableString($RawData.IsHidden)

        foreach ($RawConnection in $RawData.Connections) {
            $Connection = [Connection]::new()
            $Connection.Id = GetId($RawConnection.ContentId)
            $Connection.ContentId = $RawConnection.ContentId
            $Connection.SystemName = NullableString($RawConnection.SystemName)
            $Connection.Description = NullableString($RawConnection.Description)
            $Connection.DataSystemTypeCode = NullableString($RawConnection.DataSystemTypeCode)
            $Connection.DataSystemVersion = NullableString($RawConnection.DataSystemTypeVersion)
            $Connection.SystemVendorName = NullableString($RawConnection.SystemVendorName)
            $Connection.SystemVersion = NullableString($RawConnection.SystemVersion)

            foreach ($RawAttributeValue in $RawConnection.AttributeValues) {
                $AttributeValue = [ObjectAttributeValue]::new()
                $AttributeValue.AttributeName = $RawAttributeValue.AttributeName
                $AttributeValue.AttributeValue = $RawAttributeValue.LongTextValue + $RawAttributeValue.TextValue + $RawAttributeValue.NumberValue
                $Connection.AttributeValues += $AttributeValue
            }
            if (!$Connection.AttributeValues) {$Connection.AttributeValues = @()}
            $DataMart.Connections += $Connection
        }
        if (!$DataMart.Connections) {$DataMart.Connections = @()}

        foreach ($RawAttributeValue in $RawData.AttributeValues) {
            $AttributeValue = [ObjectAttributeValue]::new()
            $AttributeValue.AttributeName = $RawAttributeValue.AttributeName
            $AttributeValue.AttributeValue = $RawAttributeValue.LongTextValue + $RawAttributeValue.TextValue + $RawAttributeValue.NumberValue
            $DataMart.AttributeValues += $AttributeValue
        }
        if (!$DataMart.AttributeValues) {$DataMart.AttributeValues = @()}

        foreach ($RawEntity in $RawData.Tables) {
            $Entity = [Entity]::new()
            $Entity.Id = GetId($RawEntity.ContentId)
            $Entity.ContentId = $RawEntity.ContentId
            $Entity.ConnectionId = GetId($RawEntity.DestinationConnection.ContentId)
            $Entity.BusinessDescription = NullableString($RawEntity.DescriptionTXT)
            $Entity.EntityName = NullableString($RawEntity.ViewName)
            $Entity.PersistenceType = "Database"
            $Entity.IsPublic = $RawEntity.IsPublic
            $Entity.AllowsDataEntry = $RawEntity.AllowsDataEntry
            $Entity.RecordCountMismatchThreshold = $RawEntity.RowCountMismatchThreshold
            $Entity.LastSuccessfulLoadTimestamp = $RawEntity.SuccessfulLastRunDate
            $Entity.LastModifiedTimestamp = $null
            $Entity.LastDeployedTimestamp = $null

            if ($RawEntity.DatabaseNM) {
                $AttributeValue = [ObjectAttributeValue]::new()
                $AttributeValue.AttributeName = "DatabaseName"
                $AttributeValue.AttributeValue = $RawEntity.DatabaseNM
                $Entity.AttributeValues += $AttributeValue
            }
            if ($RawEntity.SchemaNM) {
                $AttributeValue = [ObjectAttributeValue]::new()
                $AttributeValue.AttributeName = "SchemaName"
                $AttributeValue.AttributeValue = $RawEntity.SchemaNM
                $Entity.AttributeValues += $AttributeValue
            }
            if ($RawEntity.TableNM) {
                $AttributeValue = [ObjectAttributeValue]::new()
                $AttributeValue.AttributeName = "TableName"
                $AttributeValue.AttributeValue = $RawEntity.TableNM
                $Entity.AttributeValues += $AttributeValue
            }
            if ($RawEntity.ViewName) {
                $AttributeValue = [ObjectAttributeValue]::new()
                $AttributeValue.AttributeName = "ViewName"
                $AttributeValue.AttributeValue = $RawEntity.ViewName
                $Entity.AttributeValues += $AttributeValue
            }
            if ($RawEntity.FileGroup) {
                $AttributeValue = [ObjectAttributeValue]::new()
                $AttributeValue.AttributeName = "FileGroupNumber"
                $AttributeValue.AttributeValue = $RawEntity.FileGroup
                $Entity.AttributeValues += $AttributeValue
            }
            if (($RawEntity.IsPersisted | Measure-Object).Count) {
                $AttributeValue = [ObjectAttributeValue]::new()
                $AttributeValue.AttributeName = "PersistedFlag"
                $AttributeValue.AttributeValue = (. $RawEntity.IsPersisted) <# takes value True/False and runs the True/False function; which converts to 1/0 #>
                $Entity.AttributeValues += $AttributeValue
            }

            foreach ($RawAttributeValue in $RawEntity.AttributeValues) {
                $AttributeValue = [ObjectAttributeValue]::new()
                $AttributeValue.AttributeName = $RawAttributeValue.AttributeName
                $AttributeValue.AttributeValue = $RawAttributeValue.LongTextValue + $RawAttributeValue.TextValue + $RawAttributeValue.NumberValue
                $Entity.AttributeValues += $AttributeValue
            }
            if (!$Entity.AttributeValues) {$Entity.AttributeValues = @()}

            foreach ($RawBinding in $RawEntity.FedByBindings) {
                $Binding = [Binding]::new()
                $Binding.Id = GetId($RawBinding.ContentId)
                $Binding.ContentId = $RawBinding.ContentId
                $Binding.Name = NullableString($RawBinding.BindingName)
                $Binding.DestinationEntityId = $Entity.Id
                $Binding.SourceConnectionId = GetId($RawBinding.SourceConnection.ContentId)
                $Binding.BindingType = ($RawBinding.GetType().Name -replace "Binding", "")
                $Binding.Classification = NullableString($RawBinding.ClassificationCode)
                $Binding.Description = NullableString($RawBinding.BindingDescription)
                $Binding.LoadTypeCode = NullableString($RawBinding.LoadType)
                $Binding.Status = NullableString($RawBinding.BindingStatus)
                $Binding.GroupingColumn = NullableString($RawBinding.GroupingColumn)
                $Binding.GroupingFormat = NullableString($RawBinding.GroupingFormat)
                $Binding.GrainName = NullableString($RawBinding.GrainName)

                foreach ($RawAttributeValue in $RawBinding.AttributeValues) {
                    $AttributeValue = [ObjectAttributeValue]::new()
                    $AttributeValue.AttributeName = $RawAttributeValue.AttributeName
                    $AttributeValue.AttributeValue = $RawAttributeValue.LongTextValue + $RawAttributeValue.TextValue + $RawAttributeValue.NumberValue
                    $Binding.AttributeValues += $AttributeValue
                }
                if (!$Binding.AttributeValues) {$Binding.AttributeValues = @()}

                $DataMart.Bindings += $Binding
            }
            if (!$DataMart.Bindings) {$DataMart.Bindings = @()}
    
            foreach ($RawField in $RawEntity.Columns) {
                $Field = [Field]::new()
                $Field.Id = GetId($RawField.ContentId)
                $Field.ContentId = $RawField.ContentId
                $Field.FieldName = NullableString($RawField.ColumnNM)
                $Field.BusinessDescription = NullableString($RawField.DescriptionTXT)
                $Field.DataType = NullableString($RawField.DataTypeDSC)
                $Field.DefaultValue = NullableString($RawField.DefaultValueTXT)
                $Field.DataSensitivity = NullableString($RawField.DataSensitivityCD)
                $Field.Ordinal = $RawField.Ordinal
                $Field.Status = NullableString($RawField.Status)
                $Field.ExampleData = NullableString($RawField.ExampleDataTXT)
                # $Field.ExampleDataUpdatetimestamp = $RawField.ExampleDataUpdateDate
                $Field.IsPrimaryKey = $RawField.IsPrimaryKeyValue
                $Field.IsNullable = $RawField.IsNullableValue
                $Field.IsAutoIncrement = $RawField.AutoIncrement
                $Field.ExcludeFromBaseView = $RawField.ExcludeFromBaseViewValue
                $Field.IsSystemField = $RawField.IsSystemColumnValue

                foreach ($RawAttributeValue in $RawField.AttributeValues) {
                    $AttributeValue = [ObjectAttributeValue]::new()
                    $AttributeValue.AttributeName = $RawAttributeValue.AttributeName
                    $AttributeValue.AttributeValue = $RawAttributeValue.LongTextValue + $RawAttributeValue.TextValue + $RawAttributeValue.NumberValue
                    $Field.AttributeValues += $AttributeValue
                }
                if (!$Field.AttributeValues) {$Field.AttributeValues = @()}

                $Entity.Fields += $Field
            }
            if (!$Entity.Fields) {$Entity.Fields = @()}

            foreach ($RawIndex in $RawEntity.Indexes) {
                $Index = [Index]::new()
                $Index.Id = GetId($RawIndex.ContentId)
                $Index.ContentId = $RawIndex.ContentId
                $Index.IndexName = NullableString($RawIndex.IndexName)
                $Index.IsUnique = $RawIndex.IsUnique
                $Index.IsActive = $RawIndex.IsActive
                $Index.IndexTypeCode = NullableString($RawIndex.IndexTypeCode)
                $Index.IsColumnStore = $RawIndex.IsColumnStore
                $Index.IsCapSystem = $RawIndex.IsCapSystem
                $Index.LastModifiedTimestamp = $RawIndex.LastModifiedTimestamp
                $Index.LastDeployedTimestamp = $RawIndex.LastDeployedTimestamp

                foreach ($RawIndexField in $RawIndex.IndexColumns) {
                    $IndexField = [IndexField]::new()
                    $IndexField.Id = GetId("$($RawIndexField.Index.ContentId)_$($RawIndexField.Column.ContentId)")
                    $IndexField.IndexId = GetId($RawIndexField.Index.ContentId)
                    $IndexField.FieldId = GetId($RawIndexField.Column.ContentId)
                    $IndexField.Ordinal = $RawIndexField.Ordinal
                    $IndexField.IsDescending = $RawIndexField.IsDescending
                    $IndexField.IsCovering = $RawIndexField.IsCovering
                    $Index.IndexFields += $IndexField
                }
                if (!$Index.IndexFields) {$Index.IndexFields = @()}
                $Entity.Indexes += $Index
            }
            if (!$Entity.Indexes) {$Entity.Indexes = @()}
            $DataMart.Entities += $Entity
        }
        if (!$DataMart.Entities) {$DataMart.Entities = @()}

        if (!$OutVar) {
            New-Directory -Dir (Split-Path $OutDir -Parent);
            [Newtonsoft.Json.JsonConvert]::SerializeObject($DataMart, [Newtonsoft.Json.Formatting]::Indented) | Out-File "$($OutDir).json" -Force -Encoding default
            $Msg = "$(" " * 4)Output to file $("$($OutDir).json")"; Write-Host $Msg -ForegroundColor Cyan; Write-Verbose $Msg; Write-Log $Msg;
        }
        else {
            $Msg = "$(" " * 4)Output to variable"; Write-Host $Msg -ForegroundColor Cyan; Write-Verbose $Msg; Write-Log $Msg;
        }

        $Msg = "Success!`r`n"; Write-Host $Msg -ForegroundColor Green; Write-Verbose $Msg; Write-Log $Msg;
        $Output = New-Object PSObject
        $Output | Add-Member -Type NoteProperty -Name RawData -Value $DataMart
        $Output | Add-Member -Type NoteProperty -Name Outdir -Value $OutDir
        return $Output
    }
}
