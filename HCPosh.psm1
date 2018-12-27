<#	
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2017 v5.4.143
	 Created on:   	8/8/2017 6:49 PM
	 Created by:   	spencer.nicol
	 Organization: 	
	 Filename:     	HCPosh.psm1
	-------------------------------------------------------------------------
	 Module Name: HCPosh
	===========================================================================
#>

<#
	.SYNOPSIS
		HCPosh is a powershell module that provides some useful functions and tools when working with data in the Health Catalyst Analytics Platform.
	
	.DESCRIPTION
		Some key features include:

		* built-in column-level **sql parser**, developed using the Microsoft.SqlServer.TransactSql.ScriptDom library.
		* integration of **Graphviz** software for ERD and Data flow diagram generation (pdf, png, and svg)
		* splits SAM Designer files into smaller files for source control
	
	.PARAMETER version
		Returns the version number of the **HCPosh** module
	
	.PARAMETER sqlparser
		Gets tables and columns from sql queries
	
	.PARAMETER data
		return a metadata_raw.json and metadata_new.json, then splits these objects into a folder structure of content for easier source control management of SAMD data models.

		HCPosh -Data
		   
		output the hcx objects to a variable in-memory

		$Var = HCPosh -Data -OutVar
		   
		other options when using the -Data function

		HCPosh -Data -Force
		HCPosh -Data -NoSplit
		HCPosh -Data -Raw
	
	.PARAMETER graphviz
		A description of the graphviz parameter.
	
	.EXAMPLE
				PS C:\> HCPosh -Graphviz
	
#>
function HCPosh
{
	#region PARAMETERS
	param
	(
		[Parameter(ParameterSetName = 'Version')]
		[switch]$Version,
		[Parameter(ParameterSetName = 'SqlParser', Mandatory = $True)]
		[switch]$SqlParser,
		[Parameter(ParameterSetName = 'SqlParser', Mandatory = $True)]
		[string]$Query,
		[Parameter(ParameterSetName = 'SqlParser')]
		[switch]$Log,
		[Parameter(ParameterSetName = 'SqlParser')]
		[switch]$SelectStar,
		[Parameter(ParameterSetName = 'SqlParser')]
		[switch]$Brackets,
		[Parameter(ParameterSetName = 'Impact', Mandatory = $True)]
		[switch]$Impact,
		[Parameter(ParameterSetName = 'Impact', Mandatory = $True)]
		[string]$Server,
		[Parameter(ParameterSetName = 'Impact')]
		[string]$ConfigPath,
		[Parameter(ParameterSetName = 'Impact')]
		[Parameter(ParameterSetName = 'Docs')]
		[Parameter(ParameterSetName = 'Graphviz')]
		[Parameter(ParameterSetName = 'Diagrams')]
		[string]$OutDir,
		[Parameter(ParameterSetName = 'Data', Mandatory = $True)]
		[switch]$Data,
		<#
		[Parameter(ParameterSetName = 'Data')]
		[Parameter(ParameterSetName = 'Docs')]
		[switch]$Force,
		#>
		[Parameter(ParameterSetName = 'Data')]
		[Parameter(ParameterSetName = 'Docs')]
		[switch]$OutVar,
		[Parameter(ParameterSetName = 'Data')]
		[switch]$Raw,
		[Parameter(ParameterSetName = 'Data')]
		[switch]$NoSplit,
		[Parameter(ParameterSetName = 'Docs', Mandatory = $True)]
		[switch]$Docs,
		[Parameter(ParameterSetName = 'Docs')]
		[switch]$KeepFullLineage,
		[Parameter(ParameterSetName = 'Diagrams', Mandatory = $True)]
		[switch]$Diagrams,
		[Parameter(ParameterSetName = 'Diagrams')]
		[Parameter(ParameterSetName = 'Docs')]
		[switch]$OutZip,
		[Parameter(ParameterSetName = 'Graphviz', Mandatory = $True)]
		[switch]$Graphviz,
		[Parameter(ParameterSetName = 'Graphviz')]
		[string]$InputDir,
		[Parameter(ParameterSetName = 'Graphviz')]
		[ValidateSet('pdf', 'png', 'svg')]
		[string]$OutType
	)
	#endregion
	
	begin
	{
		#region FUNCTION FOR WRITING LOGS
		function Write-Log
		{
			Param (
				[Parameter(Position = 0, Mandatory = $True)]
				[string]$Message,
				[Parameter(Position = 1)]
				[psobject]$Type = "info",
				[Parameter(Position = 2)]
				[psobject]$Identifier
			)
			if ($LogFile)
			{
				$Output = New-Object PSObject
				$Output | Add-Member -Type NoteProperty -Name DateDTS -Value (Get-Date -Format G)
				$Output | Add-Member -Type NoteProperty -Name MessageTXT -Value $Message.Trim()
				$Output | Add-Member -Type NoteProperty -Name Type -Value $Type
				if ($Identifier)
				{
					$Output | Add-Member -Type NoteProperty -Name Identifier -Value $Identifier
				}			
				Add-content $LogFile -Value ($Output | ConvertTo-Json -Depth 100 -Compress);
			}
		}
		#endregion
		#region FUNCTIONS TO ZIP DIRECTORIES AND UNZIP FILES
		function Unzip($File, $Destination)
		{
			[System.IO.Compression.ZipFile]::ExtractToDirectory($File, $Destination);
		}
		function Zip($Directory, $Destination)
		{
			[System.IO.Compression.ZipFile]::CreateFromDirectory($Directory, $Destination, 'Optimal', $true);
		}
		#endregion
		#region CREATE DIRECTORIES
		function New-Directory ($Dir)
		{
			If (!(Test-Path $Dir))
			{
				New-Item -ItemType Directory -Force -Path $Dir -ErrorAction Stop | Out-Null
			}
		}
		#endregion						
		
		switch ($PsCmdlet.ParameterSetName)
		{
			'Version'  {
				"HCPosh v$((Get-Module HCPosh -ListAvailable)[0].Version -join '.')"
				if (!$Version)
				{
					Get-Help HCPosh
				}
			}
			{ 'SqlParser' -or 'Data' -or 'Impact' } {
				function Split-Sql
				{
					[CmdletBinding()]
					param (
						[Parameter(Mandatory = $True)]
						[string]$Query,
						[bool]$Log = $False,
						[bool]$SelectStar = $False,
						[bool]$Brackets = $False
					)
					begin
					{
						$Parsed = New-Object -TypeName ColumnExtractor.Parser($Log, $SelectStar, $Brackets)
					}
					process
					{
						#Using the parsed object
						return $Parsed.GetTables($Query)
					}
				}
			}
			'Graphviz'  {
				if ($InputDir)
				{
					$GvFiles = Get-ChildItem -Path $InputDir | Where-Object Extension -eq '.gv'
				}
				else
				{
					$GvFiles = Get-ChildItem | Where-Object Extension -eq '.gv'
				}
				
				try
				{
					if (($GvFiles | Measure-Object).Count -eq 0) { throw; }
				}
				catch
				{
					$Msg = "Unable to find any gv files in current directory."; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
				}
				
				function Invoke-Graphviz
				{
					[CmdletBinding()]
					param
					(
						[Parameter(Mandatory = $True, ValueFromPipelineByPropertyName)]
						[string]$File,
						[Parameter(Mandatory = $True, ValueFromPipelineByPropertyName)]
						[string]$OutType,
						[Parameter(Mandatory = $True, ValueFromPipelineByPropertyName)]
						[string]$OutFile
					)
					process
					{
						try
						{
							$Graphviz = ".""$(Split-Path (Get-Module -ListAvailable HCPosh)[0].path -Parent)\Graphviz\dot.exe"" -T$($OutType) ""$($File)"" -o ""$($OutFile)"" -q"
						}
						catch
						{
							$Msg = "Unable to find the graphviz dot.exe"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
						}
						Invoke-Expression $Graphviz
					}
				}
				
			}
			'Data'  {
				$Files = Get-ChildItem | Where-Object Extension -eq '.hcx'
				
				try
				{
					if (($Files | Measure-Object).Count -eq 0) { throw; }
				}
				catch
				{
					$Msg = "Unable to find any hcx files in current directory."; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
				}
				
				function Get-Metadata_Raw
				{
<#
	.EXTERNALHELP HCPosh.psm1-Help.xml
#>
					[CmdletBinding()]
					param (
						[Parameter(Mandatory = $True, ValueFromPipelineByPropertyName)]
						[string]$File,
						[Parameter(Mandatory = $True, ValueFromPipelineByPropertyName)]
						[string]$OutDir
					)
					begin
					{
						function ParseItem($jsonItem)
						{
							if ($jsonItem.PSObject.TypeNames -match 'Array')
							{
								return ParseJsonArray($jsonItem)
							}
							elseif ($jsonItem.PSObject.TypeNames -match 'Dictionary')
							{
								return ParseJsonObject([HashTable]$jsonItem)
							}
							else
							{
								return $jsonItem
							}
						}
						
						function ParseJsonObject($jsonObj)
						{
							$result = New-Object -TypeName PSCustomObject
							foreach ($key in $jsonObj.Keys)
							{
								$item = $jsonObj[$key]
								if ($item)
								{
									$parsedItem = ParseItem $item
								}
								else
								{
									$parsedItem = $null
								}
								$result | Add-Member -MemberType NoteProperty -Name $key -Value $parsedItem
							}
							return $result
						}
						
						function ParseJsonArray($jsonArray)
						{
							$result = @()
							$jsonArray | ForEach-Object -Process {
								$result += , (ParseItem $_)
							}
							return $result
						}
						
						function ParseJsonString($json)
						{
							$config = $javaScriptSerializer.DeserializeObject($json)
							return ParseJsonObject($config)
						}
					}
					process
					{
						#$OutDirFilePath = "$($OutDir)\metadata_raw.json"
						try
						{
							Test-Path $File | Out-Null;
							$InputFile = Get-Item $File
							if ($InputFile.Extension -ne '.hcx')
							{
								throw;
							}
							else
							{
								$FileDirectory = Split-Path $File -Parent
								$Msg = "DATA - $(Split-Path $File -Leaf)"; Write-Host $Msg -ForegroundColor Magenta; Write-Verbose $Msg; Write-Log $Msg;
							}
						}
						catch
						{
							$Msg = "$(" " * 8)Unable to find any hcx files."; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
						}
						
						try
						{
							$Msg = "$(" " * 4)Unzipping hcx file..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
							
							Copy-Item -Path $File -Destination $File.Replace('.hcx', '.zip') -Force | Out-Null
							$ZipFile = $File.Replace('.hcx', '.zip')
							
							$OutBin = "$($FileDirectory)\$((Split-Path $File -Leaf).Replace('.hcx', '_bin'))"
							$Zipoutdir = "$($OutBin)\$((Split-Path $File -Leaf).Replace('.hcx', '_zip'))"
							if (Test-Path $OutBin)
							{
								Remove-Item $OutBin -Force -Recurse | Out-Null
							}
							If (!(Test-Path $Zipoutdir))
							{
								New-Item -ItemType Directory -Force -Path $Zipoutdir -ErrorAction Stop | Out-Null
							}
							Unzip -file $ZipFile -destination $Zipoutdir
							Remove-Item $ZipFile -Force | Out-Null
						}
						catch
						{
							$Msg = "$(" " * 8)Unable to unzip file."; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
						}
						
						try
						{
							$Msg = "$(" " * 4)Getting sam json object..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
							$SamFile = Get-ChildItem $Zipoutdir -Recurse | Where-Object { $_.Extension -eq ".sam" }
							
							#DATA ENTRY CSV FILES
							$CsvFiles = Get-ChildItem $Zipoutdir -Recurse | Where-Object { $_.Extension -eq ".csv" }
							if ($CsvFiles)
							{
								$CsvArray = @();
								ForEach ($Csv in $CsvFiles)
								{
									$CsvFile = New-Object PSObject -Property @{ FullyQualifiedNM = $Csv.BaseName; Data = Import-Csv -Path $Csv.FullName; Msg = $null }
									$CsvArray += $CsvFile
								}
							}
							
							$RawContent = ((Get-Content $SamFile.FullName | Select-Object -Skip 1) -join " ")
							try
							{
								$MetadataRaw = $RawContent | ConvertFrom-Json
							}
							catch
							{
								# if the json object is too large; then attempt to parse json using dot net assemblies
								[void][System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")
								$MetadataRaw = ParseItem ((New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer -Property @{ MaxJsonLength = [int]::MaxValue; RecursionLimit = [int]::MaxValue }).DeserializeObject($RawContent))
							}
							$FirstRow = Get-Content $SamFile.FullName | Select-Object -First 1
							$SamdVersionText = $FirstRow | ForEach-Object{ $_.split('"')[3] }
							if ($SamdVersionText)
							{
								$MetadataRaw | Add-Member -Type NoteProperty -Name SAMDVersionText -Value $SamdVersionText
							}
							else
							{
								$Msg = "$(" " * 8)Unable to parse Sam Designer Version."; Write-Host $Msg -ForegroundColor Yellow; Write-Verbose $Msg; Write-Log $Msg 'warning';
							}
							if ($CsvFiles)
							{
								$Msg = "$(" " * 4)Found $($CsvFiles.Count) data entry entity file(s)..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
								$MetadataRaw | Add-Member -Type NoteProperty -Name DataEntryData -Value $CsvArray
							}
							$MetadataRaw | Add-Member -Type NoteProperty -Name _hcposh -Value (New-Object PSObject -Property @{ FileBaseName = $InputFile.BaseName; LastWriteTime = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.ffffff") })
							$Msg = "$(" " * 8)Converted from json to psobject"; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
							Remove-Item $OutBin -Recurse -Force
						}
						catch
						{
							$Msg = "$(" " * 8)Unable to get sam content into object."; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
						}
						$Output = New-Object PSObject
						$Output | Add-Member -Type NoteProperty -Name metadataRaw -Value $MetadataRaw
						$Output | Add-Member -Type NoteProperty -Name outdir -Value $OutDir
						return $Output
					}
				}
				if (!($Raw))
				{
					function Get-Metadata_New
					{
<#
	.EXTERNALHELP HCPosh.psm1-Help.xml
#>
						[CmdletBinding()]
						[OutputType([PSObject])]
						param
						(
							[Parameter(Mandatory = $True, ValueFromPipelineByPropertyName)]
							[psobject]$MetadataRaw,
							[Parameter(Mandatory = $True, ValueFromPipelineByPropertyName)]
							[string]$OutDir
						)
						begin
						{
							#region FUNCTIONS FOR DATAMART OBJECT CREATION
							function New-HCEmptyDatamartObject
							{
								$Datamart = New-Object PSObject
								$Datamart | Add-Member -Type NoteProperty -Name ContentId -Value $Null
								$Datamart | Add-Member -Type NoteProperty -Name DatamartNM -Value $Null
								$Datamart | Add-Member -Type NoteProperty -Name DataMartTypeDSC -Value $Null
								$Datamart | Add-Member -Type NoteProperty -Name DescriptionTXT -Value $Null
								$Datamart | Add-Member -Type NoteProperty -Name DestinationDatabaseName -Value $Null
								$Datamart | Add-Member -Type NoteProperty -Name DestinationObjectPrefix -Value $Null
								$Datamart | Add-Member -Type NoteProperty -Name DestinationSchemaName -Value $Null
								$Datamart | Add-Member -Type NoteProperty -Name SamTypeCode -Value $Null
								$Datamart | Add-Member -Type NoteProperty -Name Status -Value $Null
								$Datamart | Add-Member -Type NoteProperty -Name VersionText -Value $Null
								$Datamart | Add-Member -Type NoteProperty -Name Entities -Value @()
								$Datamart<#extension#> | Add-Member -Type NoteProperty -Name DatamartNoSpacesNM -Value $Null
								$Datamart<#extension#> | Add-Member -Type NoteProperty -Name SAMDVersionText -Value $Null
								$Datamart<#extension#> | Add-Member -Type NoteProperty -Name MaxLastModifiedTimestamp -Value $Null
								$Datamart<#extension#> | Add-Member -Type NoteProperty -Name SourcedByEntities -Value @()
								$Datamart | Add-Member -Type NoteProperty -Name _hcposh -Value $Null
								
								return $Datamart
							}
							function New-HCEmptyEntityObject
							{
								$Entity = New-Object PSObject
								$Entity | Add-Member -Type NoteProperty -Name ContentId -Value $Null
								$Entity | Add-Member -Type NoteProperty -Name DescriptionTXT -Value $Null
								$Entity | Add-Member -Type NoteProperty -Name DatabaseNM -Value $Null
								$Entity | Add-Member -Type NoteProperty -Name SchemaNM -Value $Null
								$Entity | Add-Member -Type NoteProperty -Name TableNM -Value $Null
								$Entity | Add-Member -Type NoteProperty -Name TableTypeNM -Value $Null
								$Entity | Add-Member -Type NoteProperty -Name ViewName -Value $Null
								$Entity | Add-Member -Type NoteProperty -Name LoadType -Value $Null
								$Entity | Add-Member -Type NoteProperty -Name LastModifiedTimestamp -Value $Null
								$Entity | Add-Member -Type NoteProperty -Name IsPersisted -Value $Null
								$Entity | Add-Member -Type NoteProperty -Name IsPublic -Value $Null
								$Entity<#extension#> | Add-Member -Type NoteProperty -Name EntityGroupNM -Value $Null
								$Entity<#extension#> | Add-Member -Type NoteProperty -Name ClassificationCode -Value $Null
								$Entity<#extension#> | Add-Member -Type NoteProperty -Name FullyQualifiedNames -Value $Null
								$Entity<#extension#> | Add-Member -Type NoteProperty -Name Indexes -Value @()
								$Entity<#extension#> | Add-Member -Type NoteProperty -Name Columns -Value @()
								$Entity<#extension#> | Add-Member -Type NoteProperty -Name Bindings -Value @()
								$Entity<#extension#> | Add-Member -Type NoteProperty -Name SourcedByEntities -Value @()
								
								return $Entity
							}
							function New-HCEmptyIndexObject
							{
								$Index = New-Object PSObject
								$Index | Add-Member -Type NoteProperty -Name IndexName -Value $Null
								$Index | Add-Member -Type NoteProperty -Name IndexTypeCode -Value $Null
								$Index | Add-Member -Type NoteProperty -Name IsActive -Value $Null
								$Index | Add-Member -Type NoteProperty -Name IndexColumns -Value @()
								
								return $Index
							}
							function New-HCEmptyIndexColumnObject
							{
								$IndexColumn = New-Object PSObject
								$IndexColumn | Add-Member -Type NoteProperty -Name Ordinal -Value $Null
								$IndexColumn | Add-Member -Type NoteProperty -Name ColumnNM -Value $Null
								$IndexColumn | Add-Member -Type NoteProperty -Name IsCovering -Value $Null
								$IndexColumn | Add-Member -Type NoteProperty -Name IsDescending -Value $Null
								
								return $IndexColumn
							}
							function New-HCEmptyColumnObject
							{
								$Column = New-Object PSObject
								$Column | Add-Member -Type NoteProperty -Name ContentId -Value $Null
								$Column | Add-Member -Type NoteProperty -Name ColumnNM -Value $Null
								$Column | Add-Member -Type NoteProperty -Name DataSensitivityCD -Value $Null
								$Column | Add-Member -Type NoteProperty -Name DataTypeDSC -Value $Null
								$Column | Add-Member -Type NoteProperty -Name DescriptionTXT -Value $Null
								$Column | Add-Member -Type NoteProperty -Name IsIncrementalColumnValue -Value $Null
								$Column | Add-Member -Type NoteProperty -Name IsSystemColumnValue -Value $Null
								$Column | Add-Member -Type NoteProperty -Name IsNullableValue -Value $Null
								$Column | Add-Member -Type NoteProperty -Name IsPrimaryKeyValue -Value $Null
								$Column | Add-Member -Type NoteProperty -Name Ordinal -Value $Null
								$Column | Add-Member -Type NoteProperty -Name Status -Value $Null
								$Column | Add-Member -Type NoteProperty -Name ColumnGroupNM -Value $Null
								
								return $Column
							}
							function New-HCEmptyBindingObject
							{
								$Binding = New-Object PSObject
								$Binding | Add-Member -Type NoteProperty -Name ContentId -Value $Null
								$Binding | Add-Member -Type NoteProperty -Name BindingName -Value $Null
								$Binding | Add-Member -Type NoteProperty -Name BindingNameNoSpaces -Value $Null
								$Binding | Add-Member -Type NoteProperty -Name BindingStatus -Value $Null
								$Binding | Add-Member -Type NoteProperty -Name BindingDescription -Value $Null
								$Binding | Add-Member -Type NoteProperty -Name ClassificationCode -Value $Null
								$Binding | Add-Member -Type NoteProperty -Name GrainName -Value $Null
								$Binding | Add-Member -Type NoteProperty -Name UserDefinedSQL -Value $Null
								$Binding<#extension#> | Add-Member -Type NoteProperty -Name SourcedByEntities -Value @()
								
								return $Binding
							}
							function New-HCEmptyFullyQualifiedNameObject
							{
								$FullyQualifiedName = New-Object PSObject
								$FullyQualifiedName<#extension#> | Add-Member -Type NoteProperty -Name Table -Value $Null
								$FullyQualifiedName<#extension#> | Add-Member -Type NoteProperty -Name View -Value $Null
								
								return $FullyQualifiedName
							}
							function New-HCEmptyIncrementalConfigurationObject
							{
								$IncrementalConfiguration = New-Object PSObject
								$IncrementalConfiguration | Add-Member -Type NoteProperty -Name IncrementalColumnName -Value $Null
								$IncrementalConfiguration | Add-Member -Type NoteProperty -Name OverlapNumber -Value $Null
								$IncrementalConfiguration | Add-Member -Type NoteProperty -Name OverlapType -Value $Null
								$IncrementalConfiguration | Add-Member -Type NoteProperty -Name SourceDatabaseName -Value $Null
								$IncrementalConfiguration | Add-Member -Type NoteProperty -Name SourceSchemaName -Value $Null
								$IncrementalConfiguration | Add-Member -Type NoteProperty -Name SourceTableAlias -Value $Null
								$IncrementalConfiguration | Add-Member -Type NoteProperty -Name SourceTableName -Value $Null
								
								return $IncrementalConfiguration
							}
							function New-HCEmptySourcedByEntityObject
							{
								$SourcedByEntity = New-Object PSObject
								#$SourcedByEntity<#extension#> | Add-Member -Type NoteProperty -Name ServerNM -Value $Null
								$SourcedByEntity<#extension#> | Add-Member -Type NoteProperty -Name DatabaseNM -Value $Null
								$SourcedByEntity<#extension#> | Add-Member -Type NoteProperty -Name SchemaNM -Value $Null
								$SourcedByEntity<#extension#> | Add-Member -Type NoteProperty -Name TableNM -Value $Null
								$SourcedByEntity<#extension#> | Add-Member -Type NoteProperty -Name FullyQualifiedNM -Value $Null
								$SourcedByEntity<#extension#> | Add-Member -Type NoteProperty -Name AliasNM -Value $Null
								$SourcedByEntity<#extension#> | Add-Member -Type NoteProperty -Name TableOrigin -Value $Null
								$SourcedByEntity<#extension#> | Add-Member -Type NoteProperty -Name BindingCount -Value $Null
								$SourcedByEntity<#extension#> | Add-Member -Type NoteProperty -Name SourceContentId -Value $Null
								$SourcedByEntity<#extension#> | Add-Member -Type NoteProperty -Name SourcedByColumns -Value @()
								
								return $SourcedByEntity
							}
							function New-HCEmptySourcedByColumnObject
							{
								$SourcedByColumn = New-Object PSObject
								$SourcedByColumn<#extension#> | Add-Member -Type NoteProperty -Name ColumnNM -Value $Null
								$SourcedByColumn<#extension#> | Add-Member -Type NoteProperty -Name FullyQualifiedNM -Value $Null
								$SourcedByColumn<#extension#> | Add-Member -Type NoteProperty -Name AliasNM -Value $Null
								$SourcedByColumn<#extension#> | Add-Member -Type NoteProperty -Name BindingCount -Value $Null
								
								return $SourcedByColumn
							}
							function New-HCEmptySourcedByPossibleColumnObject
							{
								$SourcedByPossibleColumn = New-Object PSObject
								$SourcedByPossibleColumn<#extension#> | Add-Member -Type NoteProperty -Name ColumnNM -Value $Null
								$SourcedByPossibleColumn<#extension#> | Add-Member -Type NoteProperty -Name FullyQualifiedNM -Value $Null
								
								return $SourcedByPossibleColumn
							}
							function New-HCEmptyExtensionContentIdsObject
							{
								$ExtensionContentIds = New-Object PSObject
								$ExtensionContentIds | Add-Member -Type NoteProperty -Name CoreEntity -Value $Null
								$ExtensionContentIds | Add-Member -Type NoteProperty -Name ExtensionEntity -Value $Null
								$ExtensionContentIds | Add-Member -Type NoteProperty -Name OverridingExtensionView -Value $Null
								
								return $ExtensionContentIds
							}
							function New-HCEntityObject
							{
								[CmdletBinding()]
								Param (
									[Parameter(Mandatory = $True, Position = 0)]
									[psobject]$Entity,
									[Parameter(Mandatory = $False, Position = 1)]
									[array]$Bindings,
									[Parameter(Mandatory = $False, Position = 2)]
									[string]$ClassificationCode
								)
								begin
								{
									$HCEntities = @()
									function New-HCInnerEntityObject
									{
										[CmdletBinding()]
										Param (
											[Parameter(Mandatory = $True, Position = 0)]
											[psobject]$Entity,
											[Parameter(Mandatory = $False, Position = 1)]
											[array]$Bindings,
											[Parameter(Mandatory = $False, Position = 2)]
											[string]$ClassificationCode
											
										)
										begin
										{
											$HCEntity = New-HCEmptyEntityObject
										}
										Process
										{
											#region GENERAL PROPS
											$HCEntity.ContentId = $Entity.ContentId
											$HCEntity.DescriptionTXT = $Entity.DescriptionTXT
											$HCEntity.DatabaseNM = $Entity.DatabaseNM
											$HCEntity.SchemaNM = $Entity.SchemaNM
											$HCEntity.TableNM = $Entity.TableNM
											$HCEntity.TableTypeNM = $Entity.TableTypeNM
											$HCEntity.ViewName = $Entity.ViewName
											$HCEntity.LoadType = $Entity.LoadType
											$HCEntity.LastModifiedTimestamp = $Entity.LastModifiedTimestamp
											$HCEntity.IsPersisted = $Entity.IsPersisted
											$HCEntity.IsPublic = $Entity.IsPublic
											$IsUniversal = $Entity.AttributeValues | Where-Object AttributeName -eq 'IsUniversal'
											if ($IsUniversal)
											{
												$HCEntity | Add-Member -Type NoteProperty -Name IsUniversal -Value $([System.Convert]::ToBoolean($IsUniversal.TextValue))
											}
											#endregion
											#region PROTECTION PROPS
											$IsProtected = $Entity.AttributeValues | Where-Object AttributeName -eq 'IsProtected'
											if ($IsProtected)
											{
												#New attributes introduced with CAP 4.0
												$HCEntity | Add-Member -Type NoteProperty -Name IsProtected -Value $([System.Convert]::ToBoolean($IsProtected.TextValue))
											}
											#endregion
											#region FULLYQUALIFIEDNAME PROPS
											$HCFullyQualifiedName = New-HCEmptyFullyQualifiedNameObject
											$HCFullyQualifiedName.Table = "$($Entity.DatabaseNM).$($Entity.SchemaNM).$($Entity.TableNM)"
											$HCFullyQualifiedName.View = "$($Entity.DatabaseNM).$($Entity.SchemaNM).$($Entity.ViewName)"
											
											$HCEntity.FullyQualifiedNames = $HCFullyQualifiedName
											#endregion
											#region COLUMN PROPS
											foreach ($Column in $Entity.Columns)
											{
												$HCColumn = New-HCEmptyColumnObject
												$HCColumn.ContentId = $Column.ContentId
												$HCColumn.ColumnNM = $Column.ColumnNM
												$HCColumn.DataSensitivityCD = $Column.DataSensitivityCD
												$HCColumn.DataTypeDSC = $Column.DataTypeDSC
												$HCColumn.DescriptionTXT = if (($Column.DescriptionTXT -split " ")[0] -like "<*") { ($Column.DescriptionTXT -replace ($Column.DescriptionTXT -split " ")[0], "").TrimStart() }
												else { $Column.DescriptionTXT }
												$HCColumn.IsIncrementalColumnValue = $Column.IsIncrementalColumnValue
												$HCColumn.IsSystemColumnValue = $Column.IsSystemColumnValue
												$HCColumn.IsNullableValue = $Column.IsNullableValue
												$HCColumn.IsPrimaryKeyValue = $Column.IsPrimaryKeyValue
												$HCColumn.Ordinal = $Column.Ordinal
												$HCColumn.Status = $Column.Status
												$HCColumn.ColumnGroupNM = if (($Column.DescriptionTXT -split " ")[0] -like "<*") { (Get-Culture).textinfo.totitlecase((($Column.DescriptionTXT -split " ")[0] -replace "<", "" -replace ">", "" -replace "-", " ").tolower()) }
												
												$HCEntity.Columns += $HCColumn
											}
											#endregion
											#region INDEX PROPS
											foreach ($Index in $Entity.Indexes)
											{
												$HCIndex = New-HCEmptyIndexObject
												$HCIndex.IndexName = $Index.IndexName
												$HCIndex.IndexTypeCode = $Index.IndexTypeCode
												$HCIndex.IsActive = $Index.IsActive
												
												foreach ($IndexColumn in $Index.IndexColumns)
												{
													$HCIndexColumn = New-HCEmptyIndexColumnObject
													$HCIndexColumn.Ordinal = $IndexColumn.Ordinal
													$HCIndexColumn.ColumnNM = ($Entity.Columns | Where-Object { $_.'$Id' -eq $IndexColumn.Column.'$Ref' }).ColumnNM
													$HCIndexColumn.IsCovering = $IndexColumn.IsCovering
													$HCIndexColumn.IsDescending = $IndexColumn.IsDescending
													
													$HCIndex.IndexColumns += $HCIndexColumn
												}
												
												$HCEntity.Indexes += $HCIndex
											}
											#endregion
											#region BINDING PROPS
											foreach ($Binding in $Bindings)
											{
												$HCBinding = New-HCEmptyBindingObject
												$HCBinding.ContentId = $Binding.ContentId
												$HCBinding.BindingName = $Binding.BindingName
												$HCBinding.BindingNameNoSpaces = (Get-CleanFileName -Name $Binding.BindingName -RemoveSpace)
												$HCBinding.BindingStatus = $Binding.BindingStatus
												$HCBinding.BindingDescription = $Binding.BindingDescription
												if ($ClassificationCode)
												{
													$HCBinding.ClassificationCode = "$($Binding.ClassificationCode)-$($ClassificationCode)"
												}
												else
												{
													$HCBinding.ClassificationCode = $Binding.ClassificationCode
												}
												$HCBinding.GrainName = $Binding.GrainName
												$HCBinding.UserDefinedSQL = ($Binding.AttributeValues | Where-Object AttributeName -eq "UserDefinedSQL").LongTextValue
												
												#New attributes introduced with CAP 4.0
												$IsProtected = $Binding.AttributeValues | Where-Object AttributeName -eq 'IsProtected'
												if ($IsProtected)
												{
													$HCBinding | Add-Member -Type NoteProperty -Name IsProtected -Value $([System.Convert]::ToBoolean($IsProtected.TextValue))
												}
												$LoadType = if ($Binding.LoadType) { $Binding.LoadType }
												else { $HCEntity.LoadType }
												if ($LoadType)
												{
													$HCBinding | Add-Member -Type NoteProperty -Name LoadType -Value $LoadType
													
													if ($Binding.IncrementalConfigurations)
													{
														$HCBinding | Add-Member -Type NoteProperty -Name IncrementalConfigurations -Value @()
														
														foreach ($IncrementalConfiguration in $Binding.IncrementalConfigurations)
														{
															$HCIncrementalConfiguration = New-HCEmptyIncrementalConfigurationObject
															$HCIncrementalConfiguration.IncrementalColumnName = $IncrementalConfiguration.IncrementalColumnName
															$HCIncrementalConfiguration.OverlapNumber = $IncrementalConfiguration.OverlapNumber
															$HCIncrementalConfiguration.OverlapType = $IncrementalConfiguration.OverlapType
															$HCIncrementalConfiguration.SourceDatabaseName = $IncrementalConfiguration.SourceDatabaseName
															$HCIncrementalConfiguration.SourceSchemaName = $IncrementalConfiguration.SourceSchemaName
															$HCIncrementalConfiguration.SourceTableAlias = $IncrementalConfiguration.SourceTableAlias
															$HCIncrementalConfiguration.SourceTableName = $IncrementalConfiguration.SourceTableName
															
															$HCBinding.IncrementalConfigurations += $HCIncrementalConfiguration
														}
													}
												}
												$HCEntity.Bindings += $HCBinding
											}
											#endregion        
											#region EXTENSION PROPS
											$ExtensionContentIds = New-HCEmptyExtensionContentIdsObject
											if ($Entity.ChildEntityRelationships -or $Entity.ParentEntityRelationships)
											{
												$HCEntity | Add-Member -Type NoteProperty -Name IsExtended -Value $true -Force
												$HCEntity | Add-Member -Type NoteProperty -Name ExtensionContentIds -Value $ExtensionContentIds -Force
											}
											
											foreach ($Ext in $Entity.ParentEntityRelationships | Where-Object { $_.ParentRoleName })
											{
												$ExtensionContentIds."$($Ext.ParentRoleName)" = $HCEntity.ContentId
												
												foreach ($Ext2 in $Ext.ChildEntity)
												{
													$ExtensionContentIds."$($Ext.ChildRoleName)" = $Ext2.ContentId
													
													foreach ($Ext3 in $Ext2.ChildEntityRelationships | Where-Object { $_.ParentRoleName })
													{
														$ExtensionContentIds."$($Ext3.ParentRoleName)" = $Ext3.ParentEntity.ContentId
													}
													New-HCInnerEntityObject -Entity $Ext2 -Bindings $Ext2.FedByBindings
												}
												$HCEntity | Add-Member -Type NoteProperty -Name ExtensionContentIds -Value $ExtensionContentIds -Force
											}
											
											foreach ($Ext in $Entity.ChildEntityRelationships | Where-Object { $_.ChildRoleName })
											{
												$ExtensionContentIds."$($Ext.ChildRoleName)" = $HCEntity.ContentId
												
												foreach ($Ext2 in $Ext.ParentEntity)
												{
													$ExtensionContentIds."$($Ext.ParentRoleName)" = $Ext2.ContentId
													
													foreach ($Ext3 in $Ext2.ParentEntityRelationships | Where-Object { $_.ChildRoleName })
													{
														$ExtensionContentIds."$($Ext3.ChildRoleName)" = $Ext3.ChildEntity.ContentId
													}
													New-HCInnerEntityObject -Entity $Ext2 -Bindings $Ext2.FedByBindings
												}
												$HCEntity | Add-Member -Type NoteProperty -Name ExtensionContentIds -Value $ExtensionContentIds -Force
											}
											#endregion
											#region CUSTOM GROUP PROPS
											$HCEntity.EntityGroupNM = $HCEntity.Bindings[0].GrainName #Set the EntityGroupNM to the first Grain name for now // not a perfect solution
											if ($HCEntity.Bindings)
											{
												$HCEntity.ClassificationCode = $HCEntity.Bindings[0].ClassificationCode #Set the ClassificationCode to the first ClassificationCode for now // not a perfect solution
											}
											else
											{
												$HCEntity.ClassificationCode = $ClassificationCode
											}
											#endregion
										}
										End
										{
											return $HCEntity
										}
										
									}
								}
								process
								{
									$HCEntities += New-HCInnerEntityObject -Entity $Entity -Bindings $Bindings -ClassificationCode $ClassificationCode
								}
								end
								{
									return $HCEntities;
								}
							}
							#endregion							
							#region FUNCTIONS FOR SPLITTING OBJECT INTO A BUNCH OF FILES
							function New-Directory
							{
								param
								(
									[Parameter(Mandatory = $True, Position = 0)]
									[string]$Directory
								)
								process
								{
									If (Test-Path $Directory)
									{
										Remove-Item $Directory -Recurse -Force | Out-Null
									}
									New-Item -ItemType Directory -Force -Path $Directory -ErrorAction Stop | Out-Null
								}
							}
							function Get-CleanFileName
							{
								[CmdletBinding(DefaultParameterSetName = "Normal")]
								Param (
									[Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, ParameterSetName = "Normal")]
									[Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, ParameterSetName = "Replace")]
									[String[]]$Name,
									[Parameter(Position = 1, ParameterSetName = "Replace")]
									[String]$Replacement = '-',
									[Parameter(Position = 2, ParameterSetName = "Replace")]
									[Alias("RO")]
									[Object[]]$RemoveOnly,
									[Parameter(ParameterSetName = "Normal")]
									[Parameter(ParameterSetName = "Replace")]
									[Alias("RS")]
									[switch]$RemoveSpace
								)
								
								Begin
								{
									#Get an array of invalid characters 
									$arrInvalidChars = [System.IO.Path]::GetInvalidFileNameChars()
									
									#Cast into a string. This will include the space character 
									$invalidCharsWithSpace = [RegEx]::Escape([String]$arrInvalidChars)
									
									#Join into a string. This will not include the space character 
									$invalidCharsNoSpace = [RegEx]::Escape(-join $arrInvalidChars)
									
									#Check that the Replacement does not have invalid characters itself 
									if ($RemoveSpace)
									{
										if ($Replacement -match "[$invalidCharsWithSpace]")
										{
											Write-Error "The replacement string also contains invalid filename characters."; exit
										}
									}
									else
									{
										if ($Replacement -match "[$invalidCharsNoSpace]")
										{
											Write-Error "The replacement string also contains invalid filename characters."; exit
										}
									}
									
									Function Remove-Chars($String)
									{
										#Test if any charcters should just be removed first instead of replaced. 
										if ($RemoveOnly)
										{
											$String = Remove-ExemptCharsFromReplacement -String $String
										}
										
										#Replace the invalid characters with a blank string(removal) or the replacement value 
										#Perform replacement based on whether spaces are desired or not 
										if ($RemoveSpace)
										{
											[RegEx]::Replace($String, "[$invalidCharsWithSpace]", $Replacement)
										}
										else
										{
											[RegEx]::Replace($String, "[$invalidCharsNoSpace]", $Replacement)
										}
									}
									
									Function Remove-ExemptCharsFromReplacement($String)
									{
										#Remove the characters in RemoveOnly first before returning to the potential replacement 
										
										#Test that the entries are invalid filename characters, and are able to be converted to chars 
										$RemoveOnly = [RegEx]::Escape(-join $(foreach ($entry in $RemoveOnly)
												{
													#Try to cast to an int in case a valid integer as a string is passed. 
													try { $entry = [int]$entry }
													catch
													{
														#Silently ignore if it fails.  
													}
													
													try { $char = [char]$entry }
													catch { Write-Error "The entry `"$entry`" in RemoveOnly cannot be converted to a type of System.Char. Make sure the entry is either an integer or a one character string."; exit }
													
													if ($arrInvalidChars -contains $char -or $char -eq [char]32)
													{
														#Honor the RemoveSpace parameter 
														if (!$RemoveSpace -and $char -eq [char]32)
														{
															Write-Warning "The entry `"$char`" in RemoveOnly is a valid filename character, and does not need to be removed. This entry will be ignored."
														}
														else { $char }
													}
													else { Write-Warning "The entry `"$char`" in RemoveOnly is a valid filename character, and does not need to be removed. This entry will be ignored." }
												}))
										
										#Remove the exempt characters first before sending back 
										[RegEx]::Replace($String, "[$RemoveOnly]", '')
									}
								}
								
								Process
								{
									foreach ($n in $Name)
									{
										#Check if the string matches a valid path 
										if ($n -match '(?<start>^[a-zA-z]:\\|^\\\\)(?<path>(?:[^\\]+\\)+)(?<file>[^\\]+)$')
										{
											#Split the path into separate directories 
											$path = $Matches.path -split '\\'
											
											#This will remove any empty elements after the split, eg. double slashes "\\" 
											$path = $path | Where-Object { $_ }
											#Add the filename to the array 
											$path += $Matches.file
											
											#Send each part of the path, except the start, to the removal function 
											$cleanPaths = foreach ($p in $path)
											{
												Remove-Chars -String $p
											}
											#Remove any blank elements left after removal. 
											$cleanPaths = $cleanPaths | Where-Object { $_ }
											
											#Combine the path together again 
											$Matches.start + ($cleanPaths -join '\')
										}
										else
										{
											#String is not a path, so send immediately to the removal function 
											Remove-Chars -String $n
										}
									}
								}
							}
							function New-EmptyProperty
							{
								$Property = New-Object PSObject
								$Property | Add-Member -Type NoteProperty -Name Name -Value $Null
								$Property | Add-Member -Type NoteProperty -Name Property -Value $Null
								$Property | Add-Member -Type NoteProperty -Name Value -Value $Null
								return $Property
							}
							function Split-ObjectToFiles
							{
								[CmdletBinding()]
								param
								(
									[Parameter(Mandatory = $True, ValueFromPipelineByPropertyName)]
									[psobject]$MetadataNew,
									[Parameter(Mandatory = $True, ValueFromPipelineByPropertyName)]
									[string]$SplitDirectory
								)
								process
								{
									try
									{
										#create base directory
										New-Directory -Directory $SplitDirectory
										
										#region CREATE DATAMART FILES
										$Exclusions = @('DatamartNoSpacesNM', 'Entities', 'SourcedByEntities', '_hcposh', 'MaxLastModifiedTimestamp')
										$Out = @()
										$Props = $MetadataNew.psobject.properties.name | Where-Object { $MetadataNew.$_ }
										forEach ($Prop in $Props | Where-Object { $_ -NotIn $Exclusions })
										{
											$OutObj = New-EmptyProperty
											$OutObj.Name = $MetadataNew.DatamartNM
											$OutObj.Property = $Prop
											$OutObj.Value = $MetadataNew."$($OutObj.Property)"
											if ($OutObj) { $Out += $OutObj }
										}
										$OutFile = "$($SplitDirectory)\_Datamart.csv"
										if ($Out)
										{
											$Out | Sort-Object Name, @{
												e    = {
													if ($_.Property -eq 'ContentId') { 0 }
													else { 1 }
												}
											}, Property | Export-Csv $OutFile -Force -NoTypeInformation
										}
										#endregion
										#region CREATE SOURCE FILES
										$SourcedByColumns = @()
										forEach ($Entity in $MetadataNew.SourcedByEntities | Where-Object TableOrigin -eq 'External' | Sort-Object FullyQualifiedNM)
										{
											forEach ($Column in $Entity.SourcedByColumns | Sort-Object FullyQualifiedNM)
											{
												$SourcedByColumn = New-Object PSObject
												$SourcedByColumn | Add-Member -Type NoteProperty -Name DatabaseNM -Value $Entity.DatabaseNM
												$SourcedByColumn | Add-Member -Type NoteProperty -Name SchemaNM -Value $Entity.SchemaNM
												$SourcedByColumn | Add-Member -Type NoteProperty -Name TableNM -Value $Entity.TableNM
												$SourcedByColumn | Add-Member -Type NoteProperty -Name ColumnNM -Value $Column.ColumnNM
												$SourcedByColumns += $SourcedByColumn
											}
										}
										$ByDatabase = $SourcedByColumns | Group-Object DatabaseNM
										forEach ($db in $ByDatabase)
										{
											$db.Group | Sort-Object SchemaNM, TableNM, ColumnNM | Export-Csv -NoTypeInformation "$SplitDirectory\Sources-$($db.Name).csv" -Force | Out-Null
										}
										#endregion
										#region CREATE ENTITY FILES
										$Exclusions = @('Bindings', 'Columns', 'Indexes', 'SourcedByEntities', 'FullyQualifiedNames', 'LastModifiedTimestamp', 'DataEntryData', 'OverridingExtensionView')
										forEach ($Group in $MetadataNew.Entities | Group-Object ClassificationCode)
										{
											$Out = @()
											forEach ($Entity in $Group.Group)
											{
												$Props = $Entity.psobject.properties.name | Where-Object { $_ }
												forEach ($Prop in $Props | Where-Object { $_ -NotIn $Exclusions })
												{
													$OutObj = New-EmptyProperty
													$OutObj.Name = $Entity.FullyQualifiedNames.Table
													$OutObj.Property = $Prop
													$OutObj.Value = $($Entity."$($OutObj.Property)" -replace "`r`n", "")
													if ($OutObj) { $Out += $OutObj }
												}
											}
											$OutFile = "$($SplitDirectory)\Entities-$($Group.Name).csv"
											if ($Out)
											{
												$Out | Sort-Object Name, @{
													e    = {
														if ($_.Property -eq 'ContentId') { 0 }
														else { 1 }
													}
												}, Property | Export-Csv $OutFile -Force -NoTypeInformation
											}
										}
										#endregion
										#region CREATE BINDING FILES
										$Exclusions = @('BindingNameNoSpaces', 'UserDefinedSQL', 'SourcedByEntities', 'IncrementalConfigurations')
										forEach ($Group in $MetadataNew.Entities.Bindings | Group-Object ClassificationCode)
										{
											$Out = @()
											forEach ($Binding in $Group.Group)
											{
												$Props = $Binding.psobject.properties.name | Where-Object { $_ }
												forEach ($Prop in $Props | Where-Object { $_ -NotIn $Exclusions })
												{
													$OutObj = New-EmptyProperty
													$OutObj.Name = $Binding.BindingName
													$OutObj.Property = $Prop
													$OutObj.Value = $($Binding."$($OutObj.Property)" -replace "`r`n", "")
													if ($OutObj) { $Out += $OutObj }
												}
											}
											$OutFile = "$($SplitDirectory)\Bindings-$($Group.Name).csv"
											if ($Out)
											{
												$Out | Sort-Object Name, @{
													e    = {
														if ($_.Property -eq 'ContentId') { 0 }
														else { 1 }
													}
												}, Property | Export-Csv $OutFile -Force -NoTypeInformation
											}
										}
										#endregion
										#region CREATE SQL FILES
										forEach ($Binding in $MetadataNew.Entities.Bindings)
										{
											$OutFile = "$($SplitDirectory)\SQL-$($Binding.ClassificationCode)-$(Get-CleanFileName $Binding.BindingName -RemoveSpace).sql"
											$Binding.UserDefinedSQL | Out-File $OutFile -Encoding Default -Force
										}
										#endregion
										#region CREATE COLUMN FILES
										$Exclusions = @('Ordinal')
										forEach ($Group in $MetadataNew.Entities | Group-Object ClassificationCode)
										{
											$Out = @()
											forEach ($Entity in $Group.Group)
											{
												forEach ($Column in $Entity.Columns)
												{
													$Props = $Column.psobject.properties.name | Where-Object { $_ }
													forEach ($Prop in $Props | Where-Object { $_ -NotIn $Exclusions })
													{
														$OutObj = New-EmptyProperty
														$OutObj.Name = "$($Entity.FullyQualifiedNames.Table).$($Column.ColumnNM)"
														$OutObj.Property = $Prop
														$OutObj.Value = $($Column."$($OutObj.Property)" -replace "`r`n", "")
														if ($OutObj) { $Out += $OutObj }
													}
												}
											}
											$OutFile = "$($SplitDirectory)\Columns-$($Group.Name).csv"
											if ($Out)
											{
												$Out | Sort-Object Name, @{
													e    = {
														if ($_.Property -eq 'ContentId') { 0 }
														else { 1 }
													}
												}, Property | Export-Csv $OutFile -Force -NoTypeInformation
											}
										}
										#endregion
										#region CREATE INDEX FILES
										$Exclusions = @('IndexName')
										forEach ($Group in $MetadataNew.Entities | Group-Object ClassificationCode)
										{
											$Out = @()
											forEach ($Entity in $Group.Group)
											{
												forEach ($Index in $Entity.Indexes)
												{
													$Props = $Index.psobject.properties.name | Where-Object { $_ }
													forEach ($Prop in $Props | Where-Object { $_ -NotIn $Exclusions })
													{
														$OutObj = New-EmptyProperty
														$OutObj.Name = "$($Entity.FullyQualifiedNames.Table).$($Index.IndexName)"
														$OutObj.Property = $Prop
														if ($Prop -eq 'IndexColumns')
														{
															$OutObj.Value = $(($Index."$($OutObj.Property)" | Sort-Object ColumnNM).ColumnNM -join " | ")
														}
														else
														{
															$OutObj.Value = $($Index."$($OutObj.Property)" -replace "`r`n", "")
														}
														if ($OutObj) { $Out += $OutObj }
													}
												}
											}
											$OutFile = "$($SplitDirectory)\Indexes-$($Group.Name).csv"
											if ($Out)
											{
												$Out | Sort-Object Name, @{
													e    = {
														if ($_.Property -eq 'ContentId') { 0 }
														else { 1 }
													}
												}, Property | Export-Csv $OutFile -Force -NoTypeInformation
											}
										}
										#endregion
										#region CREATE INCREMENTAL CONFIG FILES
										$Exclusions = @()
										forEach ($Group in $MetadataNew.Entities.Bindings | Group-Object ClassificationCode)
										{
											$Out = @()
											forEach ($Binding in $Group.Group)
											{
												forEach ($Increment in $Binding.IncrementalConfigurations)
												{
													$Props = $Increment.psobject.properties.name | Where-Object { $_ }
													forEach ($Prop in $Props | Where-Object { $_ -NotIn $Exclusions })
													{
														$OutObj = New-EmptyProperty
														$OutObj.Name = $Binding.BindingName
														$OutObj.Property = $Prop
														$OutObj.Value = $($Increment."$($OutObj.Property)" -replace "`r`n", "")
														if ($null -ne $OutObj.Value -and $OutObj.Value -ne "") { $Out += $OutObj | Sort-Object { $_.Property, $_.Value } }
													}
												}
											}
											$OutFile = "$($SplitDirectory)\IncrementalConfigurations-$($Group.Name).csv"
											if ($Out)
											{
												$Out | Sort-Object Name, @{
													e    = {
														if ($_.Property -eq 'ContentId') { 0 }
														else { 1 }
													}
												}, Property | Export-Csv $OutFile -Force -NoTypeInformation
											}
										}
										#endregion
										#region CREATE DATA ENTRY ENTITY FILES
										ForEach ($Entity in $MetadataNew.Entities | Where-Object { $_.ClassificationCode -eq 'DataEntry' })
										{
											If ($Entity.DataEntryData)
											{
												$OutFile = "$($SplitDirectory)\DataEntryData-$(Get-CleanFileName $Entity.DataEntryData.FullyQualifiedNM -RemoveSpace).csv"
												if ($Entity.DataEntryData.Data_All)
												{
													$Entity.DataEntryData.Data_All | Export-Csv $OutFile -NoTypeInformation -Force
												}
											}
										}
										#endregion
										#region CREATE ISSUE FILES
										if (($MetadataNew.Entities.Bindings.SourcedByEntities.SourcedByPossibleColumns | Measure).Count -gt 0)
										{
											$Out = @()
											forEach ($Binding in $MetadataNew.Entities.Bindings)
											{
												forEach ($Issue in $Binding.SourcedByEntities.SourcedByPossibleColumns)
												{
													$OutObj = New-EmptyProperty
													$OutObj.Name = $Binding.BindingName
													$OutObj.Property = "Missing Alias - Unable To Parse"
													$OutObj.Value = $Issue.FullyQualifiedNM
													if ($OutObj.Value) { $Out += $OutObj }
												}
											}
											$OutFile = "$($SplitDirectory)\_ISSUES-Bindings-MissingAlias.csv"
											if ($Out)
											{
												$Out | Sort-Object Name, @{
													e    = {
														if ($_.Property -eq 'ContentId') { 0 }
														else { 1 }
													}
												}, Property | Export-Csv $OutFile -Force -NoTypeInformation
											}
										}
										#endregion
										#Get-Date | Out-File $SplitDirectory\_lastmodified.txt -Encoding Default -Force | Out-Null
									}
									catch
									{
										$Msg = "$(" " * 8)An error occurred while trying to split data object into smaller files :("; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
									}
								}
							}
							#endregion
						}
						process
						{
							#$OutDirFilePath = "$($OutDir)\metadata_new.json"
							$SplitDirectory = "$($OutDir)\Datamart"
							
							$Msg = "$(" " * 4)Creating new $(($MetadataRaw.DatamartNM).ToLower()) object..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
							$MetadataNew = New-HCEmptyDatamartObject
							
							#region DATAMART
							$MetadataNew.ContentId = $MetadataRaw.ContentId
							$MetadataNew.DatamartNM = $MetadataRaw.DatamartNM
							$MetadataNew.DatamartNoSpacesNM = (Get-CleanFileName -Name $MetadataRaw.DatamartNM -RemoveSpace)
							$MetadataNew.DataMartTypeDSC = $MetadataRaw.DataMartTypeDSC
							$MetadataNew.DescriptionTXT = $MetadataRaw.DescriptionTXT
							$MetadataNew.DestinationDatabaseName = $MetadataRaw.DestinationDatabaseName
							$MetadataNew.DestinationObjectPrefix = $MetadataRaw.DestinationObjectPrefix
							$MetadataNew.DestinationSchemaName = $MetadataRaw.DestinationSchemaName
							$MetadataNew.SamTypeCode = $MetadataRaw.SamTypeCode
							$MetadataNew.Status = $MetadataRaw.Status
							$MetadataNew.VersionText = $MetadataRaw.VersionText
							$MetadataNew.SAMDVersionText<#extension#> = $MetadataRaw.SAMDVersionText
							$MetadataNew._hcposh<#extension#> = $MetadataRaw._hcposh
							#endregion
							#region ENTITIES
							
							#Grab bindings that only have references to entities
							$RefBindings = New-Object PSObject;
							Foreach ($RefBinding in $MetadataRaw.Bindings | Where-Object { $_.DestinationEntity.'$Ref' })
							{
								if (!$RefBindings."$($RefBinding.DestinationEntity.'$Ref')")
								{
									$RefBindings | Add-Member -Type NoteProperty -Name "$($RefBinding.DestinationEntity.'$Ref')" -Value @()
								}
								$RefBindings."$($RefBinding.DestinationEntity.'$Ref')" += $RefBinding
							}
							
							Foreach ($Binding in $MetadataRaw.Bindings | Where-Object { $_.ContentId })
							{
								$Bindings = @()
								$Bindings += $Binding
								
								Foreach ($AnotherBinding in $Binding.DestinationEntity.FedByBindings | Where-Object { $_.ContentId })
								{
									$Bindings += $AnotherBinding
								}
								
								foreach ($Entity in $Binding.DestinationEntity | Where-Object { $_.ContentId })
								{
									if ($RefBindings."$($Entity.'$id')")
									{
										$Bindings += $RefBindings."$($Entity.'$id')";
									}
									$MetadataNew.Entities += New-HCEntityObject -Entity $Entity -Bindings $Bindings
								}
							}
							
							
							foreach ($Entity in $MetadataRaw.BatchDefinitions.Tables | Where-Object { $_.ContentId })
							{
								$Bindings = @()
								foreach ($Binding in $Entity.FedByBindings | Where-Object { $_.ContentId })
								{
									$Bindings += $Binding
								}
								$MetadataNew.Entities += New-HCEntityObject -Entity $Entity -Bindings $Bindings
							}
							
							foreach ($Entity in $MetadataRaw.Tables | Where-Object { $_.ContentId })
							{
								$Bindings = @()
								foreach ($Binding in $Entity.FedByBindings | Where-Object { $_.ContentId })
								{
									$Bindings += $Binding
								}
								$MetadataNew.Entities += New-HCEntityObject -Entity $Entity -Bindings $Bindings -ClassificationCode 'DataEntry'
							}
							
							
							#Update extension entities
							foreach ($Extension in $MetadataNew.Entities | Where-Object { ($_.ExtensionContentIds.PsObject.Properties.Value | measure).Count -eq 3 })
							{
								foreach ($property in $Extension.ExtensionContentIds.PsObject.Properties)
								{
									$Entity = $MetadataNew.Entities[$MetadataNew.Entities.ContentId.IndexOf($property.Value)];
									$Entity | Add-Member -Type NoteProperty -Name ExtensionTypeNM -Value $property.Name -Force;
									$Entity.ExtensionContentIds = $Extension.ExtensionContentIds;
									if ($property.Name -eq "OverridingExtensionView")
									{
										$Entity.ClassificationCode = "OverridingExtensionView";
									}
									elseif ($property.Name -ne "CoreEntity")
									{
										$Entity.ClassificationCode = "$($Entity.ClassificationCode)-Extension"
									}
									foreach ($Binding in $Entity.Bindings)
									{
										$Binding.ClassificationCode = $Entity.ClassificationCode;
									}
								}
							}							
							#endregion
							
							$MetadataNew.MaxLastModifiedTimestamp<#extension#> = ($MetadataNew.Entities.LastModifiedTimestamp | Measure -Maximum).Maximum
							
							$Msg = "$(" " * 8)$(($MetadataNew.Entities | Measure-Object).Count) - Entities"; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
							$Msg = "$(" " * 8)$(($MetadataNew.Entities.Bindings | Measure-Object).Count) - Bindings"; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
							#endregion
							
							#region ADD DATA ENTRY DATA
							if ($MetadataRaw.DataEntryData)
							{
								foreach ($HCEntity in $MetadataNew.Entities | Where-Object { $_.ClassificationCode -eq 'DataEntry' })
								{
									$DataEntryDataIndex = $MetadataRaw.DataEntryData.FullyQualifiedNM.IndexOf($HCEntity.FullyQualifiedNames.View)
									if ($DataEntryDataIndex -ne -1)
									{
										#New property added to store a maximum of 300 records for that Data entry entity
										#@{ FullyQualifiedNM = $Csv.BaseName; Data = Import-Csv -Path $Csv.FullName; Msg = $null }
										$DataEntryRecordCNT = ($MetadataRaw.DataEntryData[$DataEntryDataIndex].Data | Measure).Count
										if ($DataEntryRecordCNT -gt 300)
										{
											$Msg = "Displaying only 300 out of $($DataEntryRecordCNT) records"
										}
										else
										{
											$Msg = "Displaying $($DataEntryRecordCNT) records"
										}
										
										$DataEntryData = New-Object PSObject
										$DataEntryData | Add-Member -Type NoteProperty -Name FullyQualifiedNM -Value $MetadataRaw.DataEntryData[$DataEntryDataIndex].FullyQualifiedNM
										$DataEntryData | Add-Member -Type NoteProperty -Name Data -Value ($MetadataRaw.DataEntryData[$DataEntryDataIndex].Data | Select-Object -First 300)
										$DataEntryData | Add-Member -Type NoteProperty -Name Data_All -Value ($MetadataRaw.DataEntryData[$DataEntryDataIndex].Data)
										$DataEntryData | Add-Member -Type NoteProperty -Name Msg -Value $Msg
										
										$HCEntity | Add-Member -Type NoteProperty -Name DataEntryData -Value $DataEntryData
									}
								}
							}
							#endregion
							#region PARSE BINDINGS
							$Msg = "$(" " * 4)Parsing tables and columns from sql..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
							foreach ($HCEntity in $MetadataNew.Entities)
							{
								foreach ($HCBinding in $HCEntity.Bindings)
								{
									$SourcedByEntities = $(Split-Sql -Query $HCBinding.UserDefinedSQL -Log $False -SelectStar $False -Brackets $False)
									
									foreach ($SourcedByEntity in $SourcedByEntities | Where-Object { $_.DatabaseNM -and $_.SchemaNM -and $_.TableNM })
									{
										$HCSourcedByEntity = New-HCEmptySourcedByEntityObject
										#$HCSourcedByEntity.ServerNM = $SourcedByEntity.ServerNM
										$HCSourcedByEntity.DatabaseNM = $SourcedByEntity.DatabaseNM
										$HCSourcedByEntity.SchemaNM = $SourcedByEntity.SchemaNM
										$HCSourcedByEntity.TableNM = $SourcedByEntity.TableNM
										$HCSourcedByEntity.FullyQualifiedNM = $SourcedByEntity.FullyQualifiedNM
										$HCSourcedByEntity.AliasNM = $SourcedByEntity.AliasNM
										$HCSourcedByEntity.BindingCount = 1
										
										#if table originated from a system table
										if ($HCSourcedByEntity.SchemaNM -eq 'CatalystAdmin')
										{
											$HCSourcedByEntity.TableOrigin = 'System'
										}
										#or if table originated from a local table
										elseif (($MetadataNew.Entities.FullyQualifiedNames.Table -contains $HCSourcedByEntity.FullyQualifiedNM) -or `
											($MetadataNew.Entities.FullyQualifiedNames.View -contains $HCSourcedByEntity.FullyQualifiedNM))
										{
											$HCSourcedByEntity.TableOrigin = 'Local'
											$HCSourcedByEntity.SourceContentId = ($MetadataNew.Entities | Where-Object { (($_.FullyQualifiedNames.Table -eq $HCSourcedByEntity.FullyQualifiedNM) -or ($_.FullyQualifiedNames.View -eq $HCSourcedByEntity.FullyQualifiedNM)) -and $_.ClassificationCode -ne 'OverridingExtensionView' }).ContentId
											
											#if it's a universal entity then it originates outside of this datamart
											if ($MetadataNew.Entities[$MetadataNew.Entities.ContentId.IndexOf($HCSourcedByEntity.SourceContentId)].IsUniversal)
											{
												$HCSourcedByEntity.TableOrigin = 'External'
											}
										}
										#else table must have originated externally
										else
										{
											$HCSourcedByEntity.TableOrigin = 'External'
										}
										
										foreach ($SourcedByColumn in $SourcedByEntity.Columns)
										{
											$HCSourcedByColumn = New-HCEmptySourcedByColumnObject
											$HCSourcedByColumn.ColumnNM = $SourcedByColumn.ColumnNM
											$HCSourcedByColumn.FullyQualifiedNM = $SourcedByColumn.FullyQualifiedNM
											$HCSourcedByColumn.AliasNM = $SourcedByColumn.AliasNM
											$HCSourcedByColumn.BindingCount = 1
											
											$HCSourcedByEntity.SourcedByColumns += $HCSourcedByColumn
										}
										
										#check for missing alias ie PossibleColumns
										if ($SourcedByEntity.PossibleColumns)
										{
											$HCSourcedByEntity | Add-Member -Type NoteProperty -Name SourcedByPossibleColumns -Value @()
											foreach ($SourcedByPossibleColumn in $SourcedByEntity.PossibleColumns)
											{
												$HCSourcedByPossibleColumn = New-HCEmptySourcedByPossibleColumnObject
												$HCSourcedByPossibleColumn.ColumnNM = $SourcedByPossibleColumn.ColumnNM
												$HCSourcedByPossibleColumn.FullyQualifiedNM = "$($HCSourcedByEntity.FullyQualifiedNM).$($HCSourcedByPossibleColumn.ColumnNM)"
												
												$HCSourcedByEntity.SourcedByPossibleColumns += $HCSourcedByPossibleColumn
											}
										}
										
										$HCBinding.SourcedByEntities += $HCSourcedByEntity
									}
								}
								
								#region LEVEL-UP SOURCES (BINDING TO ENTITY)
								$HCEntityGroups = $HCEntity.Bindings.SourcedByEntities | Group-Object -Property FullyQualifiedNM
								foreach ($HCEntityGroup in $HCEntityGroups)
								{
									$HCSourcedByEntity = New-HCEmptySourcedByEntityObject
									#$HCSourcedByEntity.ServerNM = $HCEntityGroup.Group[0].ServerNM
									$HCSourcedByEntity.DatabaseNM = $HCEntityGroup.Group[0].DatabaseNM
									$HCSourcedByEntity.SchemaNM = $HCEntityGroup.Group[0].SchemaNM
									$HCSourcedByEntity.TableNM = $HCEntityGroup.Group[0].TableNM
									$HCSourcedByEntity.FullyQualifiedNM = $HCEntityGroup.Group[0].FullyQualifiedNM
									$HCSourcedByEntity.TableOrigin = $HCEntityGroup.Group[0].TableOrigin
									$HCSourcedByEntity.SourceContentId = $HCEntityGroup.Group[0].SourceContentId
									$HCSourcedByEntity.BindingCount = ($HCEntityGroup.Group.BindingCount | Measure-Object -Sum).Sum
									$HCSourcedByEntity.PSObject.Properties.Remove('AliasNM')
									
									
									$ColumnGroups = $HCEntityGroup.Group.SourcedByColumns | Group-Object ColumnNM
									foreach ($ColumnGroup in $ColumnGroups)
									{
										$HCSourcedByColumn = New-HCEmptySourcedByColumnObject
										$HCSourcedByColumn.ColumnNM = $ColumnGroup.Group[0].ColumnNM
										$HCSourcedByColumn.FullyQualifiedNM = $ColumnGroup.Group[0].FullyQualifiedNM
										$HCSourcedByColumn.BindingCount = ($ColumnGroup.Group.BindingCount | Measure-Object -Sum).Sum
										$HCSourcedByColumn.PSObject.Properties.Remove('AliasNM')
										
										$HCSourcedByEntity.SourcedByColumns += $HCSourcedByColumn
									}
									$HCEntity.SourcedByEntities += $HCSourcedByEntity
								}
								#endregion
							}
							#endregion
							#region UPDATE EXTENSION ENTITIES
							function Get-Entity ($ContentId)
							{
								return $MetadataNew.Entities[$MetadataNew.Entities.ContentId.IndexOf($ContentId)]
							}
							foreach ($HCEntity in $MetadataNew.Entities | Where-Object { $_.ExtensionTypeNM -eq 'CoreEntity' })
							{
								$ExtensionEntityId = $HCEntity.ExtensionContentIds.ExtensionEntity;
								$ExtensionEntity = Get-Entity($ExtensionEntityId);
								
								$OverridingExtensionViewId = $HCEntity.ExtensionContentIds.OverridingExtensionView;
								$OverridingExtensionView = Get-Entity($OverridingExtensionViewId);
								
								#Add the SourcedByEntities from the OverridingExtensionView to the CoreEntity
								$HCEntity.SourcedByEntities += $OverridingExtensionView.SourcedByEntities | Where-Object { $_.SourceContentId -ne $HCEntity.ContentId };
								
								#Add the Columns from the ExtensionEntity to the CoreEntity
								$ColumnsExt = $ExtensionEntity.Columns | Where-Object { $_.IsSystemColumnValue -eq $false -and $_.IsPrimaryKeyValue -eq $false };
								$MaxOrdinal = ($HCEntity.Columns.Ordinal | Measure-Object -Maximum).Maximum + 1;
								foreach ($ColumnExt in $ColumnsExt | Sort-Object Ordinal)
								{
									$ColumnExt | Add-Member -Type NoteProperty -Name IsExtended -Value $True;
									$ColumnExt.Ordinal = $MaxOrdinal;
									$MaxOrdinal++;
								}
								$HCEntity.Columns += $ColumnsExt;
								
								#Add the OverridingExtensionView as a property of the CoreEntity
								$HCEntity | Add-Member -Type NoteProperty -Name OverridingExtensionView -Value $OverridingExtensionView;
								
								#Remove the OverridingExtensionView as a true entity
								$MetadataNew.Entities = $MetadataNew.Entities | Where-Object { $_.ContentId -ne $OverridingExtensionViewId };
								
								#if the CoreEntity is not a public entity, then turn off the extension and overridingextension as being public
								#if (!($HCEntity.IsPublic))
								#{
								#	$ExtensionEntity.IsPublic = $false;
								#	$OverridingExtensionView.IsPublic = $false;
								#}
							}
							#endregion
							#region UPDATE OVERRIDING VIEW ENTITIES (SEPARATE FROM EXTENSIONS)
							$OverrideList = $MetadataNew.Entities | Group-Object -Property { $_.FullyQualifiedNames.View } | Where-Object Count -gt 1
							
							$OverrideObjects = @();
							foreach ($Override in $OverrideList)
							{
								$OverrideObject = New-Object PSObject
								$OverrideObject | Add-Member -Type NoteProperty -Name OverriddenContentId -Value $Null
								$OverrideObject | Add-Member -Type NoteProperty -Name OverridingContentId -Value $Null
								
								foreach ($Entity in $Override.Group)
								{
									if ($Entity.IsPersisted)
									{
										$OverrideObject.OverriddenContentId = $Entity.ContentId
									}
									else
									{
										$OverrideObject.OverridingContentId = $Entity.ContentId
									}
								}
								$OverrideObjects += $OverrideObject;
							}
							foreach ($OverrideObject in $OverrideObjects)
							{
								$OverriddenEntity = $MetadataNew.Entities[$MetadataNew.Entities.ContentId.IndexOf($OverrideObject.OverriddenContentId)];
								$OverriddenEntity | Add-Member -Type NoteProperty -Name IsOverridden -Value $True
								$OverriddenEntity.ViewName = $OverriddenEntity.ViewName + 'BASE'
								$OverriddenEntity.FullyQualifiedNames.View = $OverriddenEntity.FullyQualifiedNames.View + 'BASE'
								
								$OverridingEntity = $MetadataNew.Entities[$MetadataNew.Entities.ContentId.IndexOf($OverrideObject.OverridingContentId)];
								$OverridingEntity | Add-Member -Type NoteProperty -Name DoesOverride -Value $True
							}
							#endregion							
							#region LEVEL-UP SOURCES (ENTITY TO DATAMART)
							$MetadataNewGroups = $MetadataNew.Entities.SourcedByEntities | Group-Object -Property FullyQualifiedNM
							foreach ($MetadataNewGroup in $MetadataNewGroups)
							{
								$HCSourcedByEntity = New-HCEmptySourcedByEntityObject
								#$HCSourcedByEntity.ServerNM = $MetadataNewGroup.Group[0].ServerNM
								$HCSourcedByEntity.DatabaseNM = $MetadataNewGroup.Group[0].DatabaseNM
								$HCSourcedByEntity.SchemaNM = $MetadataNewGroup.Group[0].SchemaNM
								$HCSourcedByEntity.TableNM = $MetadataNewGroup.Group[0].TableNM
								$HCSourcedByEntity.FullyQualifiedNM = $MetadataNewGroup.Group[0].FullyQualifiedNM
								$HCSourcedByEntity.TableOrigin = $MetadataNewGroup.Group[0].TableOrigin
								$HCSourcedByEntity.SourceContentId = $MetadataNewGroup.Group[0].SourceContentId
								$HCSourcedByEntity.BindingCount = ($MetadataNewGroup.Group.BindingCount | Measure-Object -Sum).Sum
								$HCSourcedByEntity.PSObject.Properties.Remove('AliasNM')
								
								
								$ColumnGroups = $MetadataNewGroup.Group.SourcedByColumns | Group-Object ColumnNM
								foreach ($ColumnGroup in $ColumnGroups)
								{
									$HCSourcedByColumn = New-HCEmptySourcedByColumnObject
									$HCSourcedByColumn.ColumnNM = $ColumnGroup.Group[0].ColumnNM
									$HCSourcedByColumn.FullyQualifiedNM = $ColumnGroup.Group[0].FullyQualifiedNM
									$HCSourcedByColumn.BindingCount = ($ColumnGroup.Group.BindingCount | Measure-Object -Sum).Sum
									$HCSourcedByColumn.PSObject.Properties.Remove('AliasNM')
									
									$HCSourcedByEntity.SourcedByColumns += $HCSourcedByColumn
								}
								$MetadataNew.SourcedByEntities += $HCSourcedByEntity
							}
							#endregion
							#region ADD GIT REPO PROPERTIES
							try
							{
								$Msg = "$(" " * 4)Adding git properties..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
								function checkGit
								{
									[CmdletBinding()]
									param ()
									begin
									{
										if (!(Test-Path $((Get-Location).Path + '\.git'))) { throw; }
									}
									process
									{
										git --version
										$GitUrl = (git config --local remote.origin.url).Replace(".git", "")
										$MetadataNew | Add-Member -Type NoteProperty -Name Team -Value $(($GitUrl -split "/")[3])
										$MetadataNew | Add-Member -Type NoteProperty -Name Repository -Value $(($GitUrl -split "/")[4])
										$MetadataNew | Add-Member -Type NoteProperty -Name Branch -Value $(git rev-parse --abbrev-ref HEAD)
									}
								}
								checkGit -ErrorAction Stop
							}
							catch
							{
								$Msg = "$(" " * 8)Git not installed or not inside a git directory -- unable to add git properties"; Write-Host $Msg -ForegroundColor Yellow; Write-Verbose $Msg; Write-Log $Msg 'warning';
							}
							#endregion
							#region SPLIT OBJECT INTO SMALLER FILES
							if (!$NoSplit)
							{
								$Msg = "$(" " * 4)Splitting data object into smaller files..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
								Split-ObjectToFiles -metadataNew $MetadataNew -splitDirectory $SplitDirectory
							}
							#endregion
							
							
							$Msg = "Success!`r`n"; Write-Host $Msg -ForegroundColor Green; Write-Verbose $Msg; Write-Log $Msg;
							$Output = New-Object PSObject
							$Output | Add-Member -Type NoteProperty -Name MetadataNew -Value $MetadataNew
							$Output | Add-Member -Type NoteProperty -Name Outdir -Value $OutDir
							return $Output
						}
					}
				}
			}
			'Docs' {
				function Get-Docs
				{
					param
					(
						[Parameter(Mandatory = $True)]
						[psobject]$DocsData,
						[Parameter(Mandatory = $True)]
						[string]$OutDir,
						[switch]$OutZip
					)
					begin
					{
						#remove inactive bindings and non-dataentry entities without bindings
						foreach ($Entity in $DocsData.Entities)
						{
							$Bindings = @();
							foreach ($Binding in $Entity.Bindings)
							{
								if ($Binding.BindingStatus -eq 'Active')
								{
									$Bindings += $Binding
								}
							}
							$Entity.Bindings = $Bindings;
							
							if ($Entity.ClassificationCode -ne 'DataEntry' -and ($Entity.Bindings | Measure-Object).Count -eq 0)
							{
								$DocsData.Entities = $DocsData.Entities | Where-Object { $_ -ne $DocsData.Entities[$DocsData.Entities.ContentId.IndexOf($Entity.ContentId)] }
							}
						}
						$validPublicEntities = { !($_.IsOverridden) -and $_.IsPublic -and (@('Summary', 'Generic') -contains $_.ClassificationCode) }
						
						#region FUNCTIONS FOR DATA LINEAGE
						function New-EmptyNodes
						{
							$Nodes = New-Object PSObject
							$Nodes | Add-Member -Type NoteProperty -Name Upstream -Value @()
							$Nodes | Add-Member -Type NoteProperty -Name Downstream -Value @()
							return $Nodes
						}
						function New-EmptyNode
						{
							$Node = New-Object PSObject
							$Node | Add-Member -Type NoteProperty -Name Level -Value $Null
							$Node | Add-Member -Type NoteProperty -Name Direction -Value $Null
							$Node | Add-Member -Type NoteProperty -Name ContentId -Value $Null
							$Node | Add-Member -Type NoteProperty -Name Attributes -Value ([ordered]@{ DatabaseNM = $Null; SchemaNM = $Null; TableNM = $Null; FullyQualifiedNM = $Null; BindingCNT = $Null })
							$Node | Add-Member -Type NoteProperty -Name Groups -Value $Null;
							$Node | Add-Member -Type NoteProperty -Name Edges -Value @()
							return $Node
						}
						function New-EmptyEdge
						{
							$Edge = New-Object PSObject
							$Edge | Add-Member -Type NoteProperty -Name ContentId -Value $Null
							$Edge | Add-Member -Type NoteProperty -Name Attributes -Value ([ordered]@{ DatabaseNM = $Null; SchemaNM = $Null; TableNM = $Null; FullyQualifiedNM = $Null; BindingCNT = $Null })
							$Edge | Add-Member -Type NoteProperty -Name Groups -Value $Null;
							return $Edge
						}
						function Get-Entity ($ContentId)
						{
							return $DocsData.Entities[$DocsData.Entities.ContentId.IndexOf($ContentId)]
						}
						function Get-NodeGroups ($Node)
						{
							$Groups = [ordered]@{ GroupId = $Null; Group1 = $Null; Group2 = $Null; Group3 = $Null }
							$Attributes = $Node.Attributes
							function IsConfig ($Sources)
							{
								$IsConfig = $False
								forEach ($Source in $Sources)
								{
									if ($Source.TableOrigin -eq 'External' -and $Source.DatabaseNM -ne 'Shared' -and $Source.SchemaNM -notmatch 'Shared__')
									{
										$IsConfig = $True
										return $IsConfig
									}
								}
								return $IsConfig
							}
							if ($Node.ContentId -and !(Get-Entity -ContentId $Node.ContentId).IsUniversal) #Local
							{
								$Entity = Get-Entity -ContentId $Node.ContentId
								$Groups.Group1 = 'Local'
								if ($Entity.ClassificationCode -like '*Extension')
								{
									$Groups.Group2 = 'Extensions'
								}
								elseif ($Entity.DoesOverride)
								{
									$Groups.Group2 = 'Overriding'
								}
								elseif ($Entity.IsPublic)
								{
									$Groups.Group2 = 'Public'
								}
								elseif ((IsConfig -Sources $Entity.SourcedByEntities) -or $Entity.SchemaNM -match 'Config' -or $Entity.ClassificationCode -eq 'DataEntry')
								{
									$Groups.Group2 = 'Configurations'
								}
								elseif ($Entity.ClassificationCode -eq 'ReportingView')
								{
									$Groups.Group2 = 'Reports'
								}
								else
								{
									$Groups.Group2 = 'Staging'
									forEach ($Source in $Entity.SourcedByEntities | Where-Object SourceContentId)
									{
										if ((Get-Entity -ContentId $Source.SourceContentId).IsPublic)
										{
											$Groups.Group2 = 'Reports'
										}
									}
								}
								$Groups.Group3 = $Entity.ClassificationCode
							}
							else #External
							{
								$Groups.Group1 = 'External'
								if ($Attributes.DatabaseNM -eq 'SAM')
								{
									$Groups.Group2 = 'SubjectArea'
								}
								elseif ($Attributes.DatabaseNM -eq 'Shared')
								{
									$Groups.Group2 = 'Shared'
								}
								elseif ($Attributes.DatabaseNM -eq 'EDWAdmin' -or $Attributes.SchemaNM -eq 'CatalystAdmin')
								{
									$Groups.Group2 = 'System'
								}
								else
								{
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
						function New-UpstreamNode ($Entity, $Level)
						{
							$NewNode = New-EmptyNode
							$NewNode.Level = $Level
							$NewNode.Direction = 'Upstream'
							$NewNode.ContentId = $Entity.ContentId
							$NewNode.Attributes.DatabaseNM = $Entity.DatabaseNM
							$NewNode.Attributes.SchemaNM = $Entity.SchemaNM
							$NewNode.Attributes.TableNM = $Entity.ViewName
							$NewNode.Attributes.FullyQualifiedNM = $Entity.FullyQualifiedNames.View
							$NewNode.Attributes.BindingCNT = if ($Entity.Bindings) { "($(($Entity.Bindings | Measure).Count)) " } else { '' };
							foreach ($Upstream in $Entity.SourcedByEntities)
							{
								$NewEdge = New-EmptyEdge
								$NewEdge.ContentId = $Upstream.SourceContentId
								$NewEdge.Attributes.DatabaseNM = $Upstream.DatabaseNM
								$NewEdge.Attributes.SchemaNM = $Upstream.SchemaNM
								$NewEdge.Attributes.TableNM = $Upstream.TableNM -replace 'base$', ''
								$NewEdge.Attributes.FullyQualifiedNM = $Upstream.FullyQualifiedNM -replace 'base$', ''
								$NewEdge.Groups = Get-NodeGroups -Node $NewEdge
								$NewNode.Edges += $NewEdge
							}
							$NewNode.Groups = Get-NodeGroups -Node $NewNode
							return $NewNode
						}
						function New-DownstreamNode ($Entity, $Level)
						{
							$NewNode = New-EmptyNode
							$NewNode.Level = $Level
							$NewNode.Direction = 'Downstream'
							$NewNode.ContentId = $Entity.ContentId
							$NewNode.Attributes.DatabaseNM = $Entity.DatabaseNM
							$NewNode.Attributes.SchemaNM = $Entity.SchemaNM
							$NewNode.Attributes.TableNM = $Entity.ViewName
							$NewNode.Attributes.FullyQualifiedNM = $Entity.FullyQualifiedNames.View
							$NewNode.Attributes.BindingCNT = if ($Entity.Bindings) { "($(($Entity.Bindings | Measure).Count)) " } else { '' };
							foreach ($Downstream in $DocsData.Entities | Where-Object { $_.SourcedByEntities.SourceContentId -eq $NewNode.ContentId })
							{
								$NewEdge = New-EmptyEdge
								$NewEdge.ContentId = $Downstream.ContentId
								$NewEdge.Attributes.DatabaseNM = $Downstream.DatabaseNM
								$NewEdge.Attributes.SchemaNM = $Downstream.SchemaNM
								$NewEdge.Attributes.TableNM = $Downstream.ViewName
								$NewEdge.Attributes.FullyQualifiedNM = $Downstream.FullyQualifiedNames.View
								$NewEdge.Attributes.BindingCNT = if ($Entity.Bindings) { "($(($Entity.Bindings | Measure).Count)) " } else { '' };
								$NewEdge.Groups = Get-NodeGroups -Node $NewEdge
								$NewNode.Edges += $NewEdge
							}
							$NewNode.Groups = Get-NodeGroups -Node $NewNode
							return $NewNode
						}
						function Create-Nodes
						{
							[CmdletBinding()]
							param ($Entity)
							begin
							{
								$Nodes = New-EmptyNodes;
							}
							process
							{
								#UPSTREAM LINEAGE
								$Level = 0;
								$Nodes.Upstream += New-UpstreamNode -entity $Entity -level $Level;
								$Index = 0;
								$Batches = 1;
								do
								{
									$Edges = $Nodes.Upstream[$Index].Edges
									$EdgeCount = ($Edges | Measure).Count;
									$Level = $Nodes.Upstream[$Index].Level - 1;
									$Batches = $Batches + $EdgeCount;
									foreach ($Edge in $Edges)
									{
										if ($Edge.ContentId)
										{
											$Node = New-UpstreamNode -entity (Get-Entity -contentId $Edge.ContentId) -level $Level;
											if ($Nodes.Upstream.ContentId.indexOf($Node.ContentId) -eq -1)
											{
												$Nodes.Upstream += $Node;
											}
										}
										else
										{
											$ExtEntity = New-Object PSObject
											$ExtEntity | Add-Member -Type NoteProperty -Name DatabaseNM -Value $Edge.Attributes.DatabaseNM
											$ExtEntity | Add-Member -Type NoteProperty -Name SchemaNM -Value $Edge.Attributes.SchemaNM
											$ExtEntity | Add-Member -Type NoteProperty -Name ViewName -Value $Edge.Attributes.TableNM
											$ExtEntity | Add-Member -Type NoteProperty -Name FullyQualifiedNames -Value @{ View = $Edge.Attributes.FullyQualifiedNM; }
											$Node = New-UpstreamNode -entity $ExtEntity -level $Level;
											if ($Nodes.Upstream.Attributes.FullyQualifiedNM.indexOf($Node.Attributes.FullyQualifiedNM) -eq -1)
											{
												$Nodes.Upstream += $Node;
											}
										}
									}
									$Batches--
									$Index++
								}
								while ($Batches -gt 0)
								
								#DOWNSTREAM LINEAGE
								$Level = 0;
								$Nodes.Downstream += New-DownstreamNode -entity $Entity -level $Level;
								$Index = 0;
								$Batches = 1;
								do
								{
									$Edges = $Nodes.Downstream[$Index].Edges | Where-Object { $_.ContentId }
									$EdgeCount = ($Edges | Measure).Count;
									$Level = $Nodes.Downstream[$Index].Level + 1;
									$Batches = $Batches + $EdgeCount;
									foreach ($Edge in $Edges)
									{
										$Node = New-DownstreamNode -entity (Get-Entity -contentId $Edge.ContentId) -level $Level;
										if ($Nodes.Downstream.ContentId.indexOf($Node.ContentId) -eq -1)
										{
											$Nodes.Downstream += $Node;
										}
									}
									$Batches--
									$Index++
								}
								while ($Batches -gt 0)
								
							}
							end
							{
								return $Nodes
							}
						}
						function Get-LineageCollection
						{
							[CmdletBinding()]
							param (
								[Parameter(Mandatory = $True)]
								[psobject]$DocsData,
								[Parameter(Mandatory = $True)]
								[psobject]$Lineage,
								[switch]$keepRef
							)
							begin
							{
								function Get-ParentChildrenObj
								{
									$ParentChildren = New-Object PSObject;
									$ParentChildren | Add-Member -Type NoteProperty -Name Ordinal -Value $Null;
									$ParentChildren | Add-Member -Type NoteProperty -Name Parent -Value $Null;
									$ParentChildren | Add-Member -Type NoteProperty -Name Children -Value @();
									return $ParentChildren;
								}
							}
							process
							{
								$Collection = New-Object PSObject
								forEach ($Stream in $Lineage)
								{
									$Group1 = $Stream.Groups.Group1;
									$Group2 = $Stream.Groups.Group2;
									$Group3 = $Stream.Groups.Group3;
									
									if (!($Collection.PSobject.Properties.Name -match $Group1))
									{
										$Collection | Add-Member -Type NoteProperty -Name $Group1 -Value (New-Object PSObject)
									}
									if (!($Collection.$Group1.PSobject.Properties.Name -match $Group2))
									{
										$Collection.$Group1 | Add-Member -Type NoteProperty -Name $Group2 -Value (New-Object PSObject)
									}
									if (!($Collection.$Group1.$Group2.PSobject.Properties.Name -match $Group3))
									{
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
								forEach ($PropLevel1 in $PropsLevel1)
								{
									$Level1Obj = Get-ParentChildrenObj;
									$Level1Obj.Parent = $PropLevel1;
									$Level2 = $Level1.$PropLevel1
									$PropsLevel2 = $Level2.PSobject.Properties.Name
									forEach ($PropLevel2 in $PropsLevel2)
									{
										$Level2Obj = Get-ParentChildrenObj;
										$Level2Obj.Parent = $PropLevel2;
										$Level3 = $Level2.$PropLevel2
										$PropsLevel3 = $Level3.PSobject.Properties.Name
										forEach ($PropLevel3 in $PropsLevel3)
										{
											$Level3Obj = Get-ParentChildrenObj;
											$Level3Obj.Parent = $PropLevel3;
											$Level4 = $Level3.$PropLevel3
											$Level3Obj.Ordinal = ($Level4.Level | Measure -Average).Average
											$PropsLevel4 = $Level4
											$b = 1;
											forEach ($PropLevel4 in $PropsLevel4 | Sort-Object { $_.FullyQualifiedNM })
											{
												$Level4Obj = Get-ParentChildrenObj;
												$Level4Obj.Ordinal = $b;
												$Level4Obj.Parent = $PropLevel4.FullyQualifiedNM;
												forEach ($ContentId in $PropLevel4 | Where-Object ContentId)
												{
													$Index = $DocsData.Entities.ContentId.indexOf($ContentId.ContentId)
													$Bindings = $DocsData.Entities[$Index].Bindings.BindingNameNoSpaces | Sort-Object
													$a = 1;
													forEach ($Binding in $Bindings | Sort-Object)
													{
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
										if ($PropLevel2 -eq 'Extensions')
										{
											$Multiple = 1000;
										}
										$Level2Obj.Ordinal = ($Level3Obj.Ordinal | Measure -Average).Average + $Multiple
										$Level1Obj.Children += $Level2Obj
									}
									$Level1Obj.Ordinal = ($Level2Obj.Ordinal | Measure -Average).Average
									$LineageArray += $Level1Obj
								}
								return $LineageArray
							}
						}
						#endregion
						#region FUNCTIONS FOR EMPTY DIAGRAM OBJECTS
						function New-EmptyDiagramGraph
						{
							param
							(
								[Parameter(Mandatory = $True)]
								[string]$Name,
								[Parameter(Mandatory = $False)]
								[array]$Types
							)
							$Diagram = New-Object PSObject
							$Diagram | Add-Member -Type NoteProperty -Name $($Name) -Value (New-Object PSObject -Property @{ Data = $Null; Graphviz = $Null })
							
							$DiagramData = New-Object PSObject
							$DiagramData | Add-Member -Type NoteProperty -Name GraphId -Value $Null
							$DiagramData | Add-Member -Type NoteProperty -Name GraphName -Value $Null
							$DiagramData | Add-Member -Type NoteProperty -Name Subgraphs -Value @()
							$DiagramData | Add-Member -Type NoteProperty -Name Nodes -Value @()
							#$DiagramData | Add-Member -Type NoteProperty -Name Edges -Value @()
							
							$DiagramGraphviz = New-Object PSObject
							forEach ($Type in $Types)
							{
								$DiagramGraphviz | Add-Member -Type NoteProperty -Name $Type -Value $Null
							}
							
							$Diagram.$($Name).Data = $DiagramData
							$Diagram.$($Name).Graphviz = $DiagramGraphviz
							
							return $Diagram
						}
						function New-EmptyDiagramSubgraph
						{
							$Subgraph = New-Object PSObject
							$Subgraph | Add-Member -Type NoteProperty -Name SubgraphId -Value $Null
							$Subgraph | Add-Member -Type NoteProperty -Name SubgraphName -Value $Null
							$Subgraph | Add-Member -Type NoteProperty -Name Props -Value @()
							$Subgraph | Add-Member -Type NoteProperty -Name Subgraphs -Value @()
							$Subgraph | Add-Member -Type NoteProperty -Name Ports -Value @()
							return $Subgraph
						}
						function New-EmptyDiagramNode
						{
							$DiagramNode = New-Object PSObject
							$DiagramNode | Add-Member -Type NoteProperty -Name NodeId -Value $Null
							$DiagramNode | Add-Member -Type NoteProperty -Name NodeName -Value $Null
							$DiagramNode | Add-Member -Type NoteProperty -Name Ports -Value @()
							$DiagramNode | Add-Member -Type NoteProperty -Name Props -Value @()
							return $DiagramNode
						}
						function New-EmptyDiagramPort
						{
							$DiagramPort = New-Object PSObject
							$DiagramPort | Add-Member -Type NoteProperty -Name PortId -Value $Null
							$DiagramPort | Add-Member -Type NoteProperty -Name Props -Value @()
							$DiagramPort | Add-Member -Type NoteProperty -Name Items -Value @()
							$DiagramPort | Add-Member -Type NoteProperty -Name Edges -Value @()
							return $DiagramPort
						}
						function New-EmptyDiagramItem
						{
							$DiagramItem = New-Object PSObject
							$DiagramItem | Add-Member -Type NoteProperty -Name ItemId -Value $Null
							$DiagramItem | Add-Member -Type NoteProperty -Name ItemName -Value $Null
							$DiagramItem | Add-Member -Type NoteProperty -Name Props -Value @()
							return $DiagramItem
						}
						function New-EmptyDiagramEdge
						{
							$DiagramEdge = New-Object PSObject
							$DiagramEdge | Add-Member -Type NoteProperty -Name From -Value (New-Object PSObject -Property @{ NodeId = $Null; PortId = $Null; })
							$DiagramEdge | Add-Member -Type NoteProperty -Name To -Value (New-Object PSObject -Property @{ NodeId = $Null; PortId = $Null; })
							return $DiagramEdge
						}
						#endregion
						#region FUNCTIONS FOR ERD DIAGRAMS
						function Create-Erd
						{
							param
							(
								[Parameter(Mandatory = $True, Position = 0)]
								[psobject]$DocsData
							)
							
							#Gcreate a new ERD object using the datamart name as the ERD name
							$Erd = New-EmptyDiagramGraph -Name Erd -Types @('Full', 'Minimal')
							$Erd.Erd.Data.GraphId = """" + $DocsData.DatamartNM + """"
							$Erd.Erd.Data.GraphName = $DocsData.DatamartNM
							
							#Get all the entities that we want to be nodes in the ERD diagram
							$Entities = $DocsData.Entities | Where-Object $validPublicEntities
							
							
							#Interate through these entities and create a new node
							forEach ($Entity in $Entities)
							{
								$ErdNode = New-EmptyDiagramNode
								$ErdNode.NodeId = """" + $Entity.FullyQualifiedNames.View + """"
								$ErdNode.NodeName = $Entity.FullyQualifiedNames.View
								$ErdNode.Props = $Entity.Columns
								
								#For those entities with primary keys...create a default PK port
								$PkColumns = $ErdNode.Props | Where-Object IsPrimaryKeyValue
								if ($PkColumns)
								{
									$PkPort = New-EmptyDiagramPort
									$PkPort.PortId = 0
									foreach ($PkColumn in $PkColumns)
									{
										$PkItem = New-EmptyDiagramItem
										$PkItem.ItemId = $PkColumn.ContentId
										$PkItem.ItemName = $PkColumn.ColumnNM
										$PkItem.Props += @{ DataTypeDSC  = $PkColumn.DataTypeDSC; Ordinal = $PkColumn.Ordinal }
										$PkPort.Items += $PkItem
									}
									$PkPort.Props += @{ PortType = 'PK'; PortLinkId = ($PkPort.Items.ItemName | Sort-Object ItemName) -join "_" }
									$ErdNode.Ports += $PkPort
								}
								
								$Erd.Erd.Data.Nodes += $ErdNode
							}
							
							#loop back through the nodes and add any foreign key nodes
							forEach ($Node in $Erd.Erd.Data.Nodes)
							{
								#foreign keys nodes have to be primary keys from other nodes
								forEach ($OtherNode in $Erd.Erd.Data.Nodes | Where-Object { $_.NodeId -ne $Node.NodeId })
								{
									$OtherPort = $OtherNode.Ports | Where-Object { $_.Props.PortType -eq 'PK' }
									$Count = 0;
									$TotalCount = ($OtherPort.Items | Measure).Count
									$MaxPortId = ($Node.Ports.PortId | Measure -Maximum).Maximum
									if (!$MaxPortId) { $MaxPortId = 0 }
									$FkPort = New-EmptyDiagramPort
									
									forEach ($OtherItem in $OtherPort.Items)
									{
										if ($Node.Props.ColumnNM.ToLower() -contains $OtherItem.ItemName.ToLower())
										{
											$TempColumn = $Node.Props[$Node.Props.ColumnNM.ToLower().IndexOf($OtherItem.ItemName.ToLower())]
											$FkPort.PortId = $MaxPortId + 1
											$FkItem = New-EmptyDiagramItem
											$FkItem.ItemId = $TempColumn.ContentId
											$FkItem.ItemName = $TempColumn.ColumnNM
											$FkItem.Props += @{ DataTypeDSC = $TempColumn.DataTypeDSC; Ordinal = $TempColumn.Ordinal }
											$FkPort.Items += $FkItem
											$Count++
										}
										if ($Count -eq $TotalCount)
										{
											$FkPort.Props += @{ PortType = 'FK'; PortLinkId	= ($FkPort.Items.ItemName | Sort-Object ItemName) -join "_" }
											
											$FkEdge = New-EmptyDiagramEdge
											$FkEdge.From.NodeId = $Node.NodeId
											$FkEdge.To.NodeId = $OtherNode.NodeId
											$FkEdge.To.PortId = 0
											
											if ($Node.Ports.Props.PortLinkId)
											{
												$Index = $Node.Ports.Props.PortLinkId.indexOf($FkPort.Props.PortLinkId)
												if ($Index -ne -1)
												{
													$FkEdge.From.PortId = $Node.Ports[$Index].PortId
													$Node.Ports[$Index].Edges += $FkEdge
												}
												else
												{
													$FkEdge.From.PortId = $FkPort.PortId
													$FkPort.Edges += $FkEdge
													$Node.Ports += $FkPort
												}
											}
											else
											{
												$FkEdge.From.PortId = $FkPort.PortId
												$FkPort.Edges += $FkEdge
												$Node.Ports += $FkPort
											}
										}
									}
								}
								
								$MaxPortId = ($Node.Ports.PortId | Measure -Maximum).Maximum
								if (!$MaxPortId) { $MaxPortId = 0 }
								$LastPort = New-EmptyDiagramPort
								$LastPort.PortId = $MaxPortId + 1
								$LastPort.Props += @{ PortType = ' ' }
								forEach ($Col in $Node.Props | Sort-Object Ordinal)
								{
									if ($Node.Ports.Items.ItemName -notcontains $Col.ColumnNM)
									{
										$LastItem = New-EmptyDiagramItem
										$LastItem.ItemId = $Col.ContentId
										$LastItem.ItemName = "$(if ($Col.IsExtended) {'*'})$($Col.ColumnNM)"
										$LastItem.Props += @{ DataTypeDSC = $Col.DataTypeDSC; Ordinal = $Col.Ordinal }
										$LastPort.Items += $LastItem
									}
								}
								if (($LastPort.Items | Measure).Count -gt 0)
								{
									$Node.Ports += $LastPort
								}
								$Node.PSObject.Properties.Remove('Props')
							}
							$Erd.Erd.Data.PSObject.Properties.Remove('Subgraphs')
							
							if ($Erd.Erd.Data.Nodes.Ports.Edges)
							{
								$Erd.Erd.Graphviz.Full = Create-ErdGraphviz -ErdData $Erd.Erd.Data
								$Erd.Erd.Graphviz.Minimal = Create-ErdGraphviz -ErdData $Erd.Erd.Data -Minimal
							}
							else
							{
								$Msg = "$(" " * 8)Requirements not met for erd diagram:`n$(" " * 10)At least 2 public entities with primary keys and one foreign key relationship"; Write-Host $Msg -ForegroundColor Yellow; Write-Verbose $Msg; Write-Log $Msg 'warning';
							}
							return $Erd
						}
						function Create-ErdGraphviz
						{
							[CmdletBinding()]
							param
							(
								[Parameter(Mandatory = $True, Position = 0)]
								[psobject]$ErdData,
								[Parameter(Mandatory = $False)]
								[switch]$Minimal
							)
							begin
							{
								$Tab = " " * 4;
								$GraphTmp = "digraph {{ GraphId }}{`n$($Tab)graph[rankdir=RL];`n$($Tab)node [shape=plaintext, fontname=""Arial""];`n{{ Nodes }}{{ Edges }}`n}";
								$NodeTmp = "`n$($Tab){{ NodeId }} [label=<`n$($Tab * 2)<table>`n$($Tab * 3)<tr><td border=""0"" bgcolor=""#D7DDE4""><b>{{ NodeName }}</b></td></tr>`n{{ Ports }}$($Tab * 2)</table>>];`n";
								$PortTmp = "$($Tab * 3)<tr><td sides=""t"" port=""{{ PortId }}"" align=""left"">`n$($Tab * 4)<table border=""0"" cellspacing=""0"" fixedsize=""true"" align=""left"">{{ Items }}`n$($Tab * 4)</table>`n$($Tab * 3)</td></tr>`n";
								$ItemTmp = "`n$($Tab * 5)<tr>`n$($Tab * 6)<td align=""left"" fixedsize=""true"" width=""20""><font point-size=""10"">{{ PortType }}</font></td>`n$($Tab * 6)<td align=""left"">{{ ItemName }}</td>`n$($Tab * 6)<td align=""left""><font point-size=""10"" color=""#767676"">{{ DataTypeDSC }}</font></td>`n$($Tab * 5)</tr>";
								$EdgeTmp = "`n$($Tab){{ From.NodeId }}:{{ From.PortId }} -> {{ To.NodeId }}:{{ To.PortId }} [arrowtail=crow, arrowhead=odot, dir=both];";
							}
							process
							{
								#BASE
								$GvErd = $GraphTmp -replace '{{ GraphId }}', $ErdData.GraphId
								
								#NODES
								$GvNodes = @()
								forEach ($Node in $ErdData.Nodes)
								{
									$GvNode = $NodeTmp -replace '{{ NodeId }}', $Node.NodeId -replace '{{ NodeName }}', $Node.NodeName
									$GvPorts = @()
									if ($Minimal)
									{
										$Ports = $Node.Ports | Where-Object { $_.Props.PortType -ne ' ' }
									}
									else
									{
										$Ports = $Node.Ports
									}
									forEach ($Port in $Ports)
									{
										$GvPort = $PortTmp -replace '{{ PortId }}', $Port.PortId
										$GvItems = @()
										forEach ($Item in $Port.Items)
										{
											$GvItem = $ItemTmp -replace '{{ PortType }}', $Port.Props.PortType -replace '{{ ItemName }}', $Item.ItemName -replace '{{ DataTypeDSC }}', $Item.Props.DataTypeDSC
											$GvItems += $GvItem
										}
										$GvPort = $GvPort -replace '{{ Items }}', $GvItems
										$GvPorts += $GvPort
									}
									$GvNode = $GvNode -replace '{{ Ports }}', $GvPorts
									$GvNodes += $GvNode
								}
								
								#EDGES
								$GvEdges = @()
								forEach ($Edge in $ErdData.Nodes.Ports.Edges)
								{
									$GvEdge = $EdgeTmp -replace '{{ From.NodeId }}', $Edge.From.NodeId -replace '{{ From.PortId }}', $Edge.From.PortId -replace '{{ To.NodeId }}', $Edge.To.NodeId -replace '{{ To.PortId }}', $Edge.To.PortId
									$GvEdges += $GvEdge
								}
							}
							end
							{
								return $GvErd -replace '{{ Nodes }}', $GvNodes -replace '{{ Edges }}', $GvEdges
							}
						}
						#endregion
						#region FUNCTIONS FOR DFD DIAGRAMS
						function Create-Dfd
						{
							[CmdletBinding()]
							param
							(
								[Parameter(Mandatory = $True)]
								[string]$Name,
								[Parameter(Mandatory = $True)]
								[array]$Lineage,
								[Parameter()]
								[ValidateSet('Upstream', 'Downstream', 'Both')]
								[string]$Type
							)
							begin
							{
								function Get-Color ($code)
								{
									switch ($code)
									{
										"Datamart"       { @{ ColorLight = "#F0F3F6" } }
										"Source"         { @{ ColorLight = "#FCFAD0" } }
										"System"         { @{ ColorLight = "#FDE2C1" } }
										"Shared"         { @{ ColorLight = "#FDE2C1" } }
										"SubjectArea"    { @{ ColorLight = "#FDE2C1" } }
										"Overriding"     { @{ ColorLight = "#C7C7C7"; ColorDark = "#A2A2A2" } }
										"Extensions"     { @{ ColorLight = "#C7C7C7"; ColorDark = "#A2A2A2" } }
										"Configurations" { @{ ColorLight = "#FBC9CC"; ColorDark = "#F8A6AA" } }
										"Staging"        { @{ ColorLight = "#B9E8FF"; ColorDark = "#73D2FF" } }
										"Public"         { @{ ColorLight = "#B9E7D1"; ColorDark = "#8BD7B3" } }
										"Reports"        { @{ ColorLight = "#D7D0E5"; ColorDark = "#BDB0D5" } }
										default { "Color could not be determined." }
									}
								}
								function Spacer ($string)
								{
									return ($string -creplace '([A-Z\W_]|\d+)(?<![a-z])', ' $&').trim()
								}
								$Dfd = New-EmptyDiagramGraph -Name Dfd -Types @('LR', 'TB')
								$Dfd.Dfd.Data.GraphId = """$($Name)"""
								$Dfd.Dfd.Data.GraphName = $Name
							}
							process
							{
								#region EXTERNAL
								if ($Type -eq 'Upstream' -or $Type -eq 'Both')
								{
									$Externals = $Lineage.Upstream | Where-Object { $_.Groups.Group1 -eq 'External' } | Group-Object { "$($_.Groups.GroupId)" }
									forEach ($External in $Externals)
									{
										$Subgraph = New-EmptyDiagramSubgraph
										$Subgraph.SubgraphId = """cluster_$($External.Name)"""
										$Subgraph.SubgraphName = $External.Group[0].Groups.Group3.ToUpper()
										$Subgraph.Props = (Get-Color -code $External.Group[0].Groups.Group2).ColorLight
										$Port = New-EmptyDiagramPort
										$Port.PortId = """$($External.Name)"""
										forEach ($Item in $External.Group)
										{
											$NewItem = New-EmptyDiagramItem
											$NewItem.ItemId = """$($Item.Attributes.FullyQualifiedNM)"""
											$NewItem.ItemName = "$($Item.Attributes.SchemaNM).$($Item.Attributes.TableNM)"
											if ($Port.Items.ItemId -notcontains $NewItem.ItemId)
											{
												$Port.Items += $NewItem
											}
										}
										if ($Subgraph.Ports.PortId -notcontains $Port.PortId)
										{
											$Subgraph.Ports += $Port
										}
										if ($Dfd.Dfd.Data.Subgraphs.SubgraphId -notcontains $Subgraph.SubgraphId)
										{
											$Dfd.Dfd.Data.Subgraphs += $Subgraph
										}
									}
								}
								#endregion
								#region LOCAL
								$Subgraph = New-EmptyDiagramSubgraph
								$Subgraph.SubgraphId = """cluster_$($Name)"""
								$Subgraph.SubgraphName = $Name
								$Subgraph.Props = (Get-Color -code "Datamart").ColorLight
								
								if ($Type -eq 'Both')
								{
									$Locals = $Lineage.Upstream + $Lineage.Downstream | Where-Object { $_.Groups.Group1 -eq 'Local' } | Group-Object { "$($_.Groups.Group2)" }
								}
								else
								{
									$Locals = $Lineage.$Type | Where-Object { $_.Groups.Group1 -eq 'Local' } | Group-Object { "$($_.Groups.Group2)" }
								}
								forEach ($Local in $Locals)
								{
									$Subgraph2 = New-EmptyDiagramSubgraph
									$Subgraph2.SubgraphId = """cluster_$($Local.Name)"""
									$Subgraph2.SubgraphName = $Local.Group[0].Groups.Group2.ToUpper()
									$Subgraph2.Props = (Get-Color -code $Local.Group[0].Groups.Group2).ColorLight
									
									$Locals2 = $Local.Group | Group-Object { "$($_.Groups.Group3)" }
									forEach ($Local2 in $Locals2)
									{
										$Subgraph3 = New-EmptyDiagramSubgraph
										$Subgraph3.SubgraphId = """cluster_$($Local2.Name)"""
										$Subgraph3.SubgraphName = $Local2.Group[0].Groups.Group3.ToUpper()
										$Subgraph3.Props = (Get-Color -code $Local.Group[0].Groups.Group2).ColorDark
										
										$Port = New-EmptyDiagramPort
										$Port.PortId = """$($Local2.Group[0].Groups.GroupId)"""
										forEach ($Item in $Local2.Group)
										{
											$NewItem = New-EmptyDiagramItem
											$NewItem.ItemId = """$($Item.Attributes.FullyQualifiedNM)"""
											$NewItem.ItemName = "$($Item.Attributes.BindingCNT)$($Item.Attributes.SchemaNM).$($Item.Attributes.TableNM)"
											if ($Port.Items.ItemId -notcontains $NewItem.ItemId)
											{
												$Port.Items += $NewItem
											}
											$Downstream = $Item | Where-Object { $_.Direction -eq 'Downstream' }
											$Upstream = $Item | Where-Object { $_.Direction -eq 'Upstream' }
											
											ForEach ($Edge in $Downstream.Edges.Groups.GroupId)
											{
												$NewEdge = New-EmptyDiagramEdge
												$NewEdge.From.PortId = $Item.Groups.GroupId
												$NewEdge.To.PortId = $Edge
												$Port.Edges += $NewEdge
											}
											ForEach ($Edge in $Upstream.Edges.Groups.GroupId)
											{
												$NewEdge = New-EmptyDiagramEdge
												$NewEdge.From.PortId = $Edge
												$NewEdge.To.PortId = $Item.Groups.GroupId
												$Port.Edges += $NewEdge
											}
										}
										if ($Subgraph3.Ports.PortId -notcontains $Port.PortId)
										{
											$Subgraph3.Ports += $Port
										}
										if ($Subgraph2.Subgraphs.SubgraphId -notcontains $Subgraph3.SubgraphId)
										{
											$Subgraph2.Subgraphs += $Subgraph3
										}
									}
									
									if ($Subgraph.Subgraphs.SubgraphId -notcontains $Subgraph2.SubgraphId)
									{
										$Subgraph.Subgraphs += $Subgraph2
									}
								}
								$Dfd.Dfd.Data.Subgraphs += $Subgraph
								#endregion
							}
							end
							{
								$Dfd.Dfd.Data.PSObject.Properties.Remove('Nodes')
								$Dfd.Dfd.Graphviz.LR = Create-DfdGraphviz -DfdData $Dfd.Dfd.Data -Direction LR
								$Dfd.Dfd.Graphviz.TB = Create-DfdGraphviz -DfdData $Dfd.Dfd.Data -Direction TB
								return $Dfd
							}
						}
						function Create-DfdGraphviz
						{
							[CmdletBinding()]
							param
							(
								[Parameter(Mandatory = $True, Position = 0)]
								[psobject]$DfdData,
								[ValidateSet('LR', 'TB')]
								[string]$Direction
								
							)
							begin
							{
								$Tab = " " * 4;
								$Justify = 'c'
								if ($Direction -eq 'TB') { $Justify = 'l' }
								$GraphTmp = "digraph {{ GraphId }}{`n$($Tab)graph [layout=dot, rankdir=$($Direction), fontname=Arial, pencolor=transparent, style=""rounded, filled"", labeljust=""$($Justify)""];`n$($Tab)node [shape=box, fixedsize=false, fontname=Arial, style=""rounded, filled"", fillcolor=white];`n$($Tab)edge [style=dashed];`n{{ Subgraphs }}`n{{ Edges }}`n}";
								function Get-SubgraphTmp ($i) { return "`n$($Tab * (1 + $i))subgraph {{ SubgraphId }} {`n$($Tab * (2 + $i))label=<<B>{{ SubgraphName }}</B>>;`n$($Tab * (2 + $i))bgcolor=""{{ Color }}"";`n{{ Subgraphs }}{{ Ports }}`n$($Tab * (1 + $i))};"; }
								function Get-PortTmp ($i) { return "$($Tab * (1 + $i)){{ PortId }} [label=<`n$($Tab * (2 + $i))<table border=""0"">{{ Items }}`n$($Tab * (2 + $i))</table>>];"; }
								function Get-ItemTmp ($i) { return "`n$($Tab * (1 + $i))<tr><td align=""left"">{{ ItemName }}</td></tr>"; }
								$EdgeTmp = "`n$($Tab)""{{ From.PortId }}"" -> ""{{ To.PortId }}"";";
							}
							process
							{
								#BASE
								$GvGraph = $GraphTmp -replace '{{ GraphId }}', $DfdData.GraphId
								
								#SUBGRAPHS
								$GvSubgraph = @()
								$GvPort = $Null
								forEach ($Sub1 in $DfdData.Subgraphs)
								{
									if ($Sub1.Subgraphs)
									{
										
										$GvSubgraph2 = @()
										forEach ($Sub2 in $Sub1.Subgraphs)
										{
											if ($Sub2.Subgraphs)
											{
												
												$GvSubgraph3 = @()
												forEach ($Sub3 in $Sub2.Subgraphs)
												{
													$GvItems = @()
													forEach ($Item in $Sub3.Ports.Items | Sort-Object ItemName)
													{
														$GvItems += (Get-ItemTmp -i 5) -replace '{{ ItemName }}', $Item.ItemName
													}
													$GvPort = (Get-PortTmp -i 3) -replace '{{ PortId }}', $Sub3.Ports.PortId -replace '{{ Items }}', $GvItems
													$GvSubgraph3 += (Get-SubgraphTmp -i 2) -replace '{{ SubgraphId }}', $Sub3.SubgraphId -replace '{{ SubgraphName }}', $Sub3.SubgraphName -replace '{{ Color }}', $Sub3.Props -replace '{{ Subgraphs }}', '' -replace '{{ Ports }}', $GvPort
												}
												
												$GvSubgraph2 += (Get-SubgraphTmp -i 1) -replace '{{ SubgraphId }}', $Sub2.SubgraphId -replace '{{ SubgraphName }}', $Sub2.SubgraphName -replace '{{ Color }}', $Sub2.Props -replace '{{ Ports }}', '' -replace '{{ Subgraphs }}', $GvSubgraph3
											}
											else
											{
												$GvItems = @()
												forEach ($Item in $Sub2.Ports.Items | Sort-Object ItemName)
												{
													$GvItems += (Get-ItemTmp -i 4) -replace '{{ ItemName }}', $Item.ItemName
												}
												$GvPort = (Get-PortTmp -i 2) -replace '{{ PortId }}', $Sub2.Ports.PortId -replace '{{ Items }}', $GvItems
												$GvSubgraph2 += (Get-SubgraphTmp -i 1) -replace '{{ SubgraphId }}', $Sub2.SubgraphId -replace '{{ SubgraphName }}', $Sub2.SubgraphName -replace '{{ Color }}', $Sub2.Props -replace '{{ Subgraphs }}', '' -replace '{{ Ports }}', $GvPort
											}
										}
										
										$GvSubgraph += (Get-SubgraphTmp -i 0) -replace '{{ SubgraphId }}', $Sub1.SubgraphId -replace '{{ SubgraphName }}', $Sub1.SubgraphName -replace '{{ Color }}', $Sub1.Props -replace '{{ Ports }}', '' -replace '{{ Subgraphs }}', $GvSubgraph2
									}
									else
									{
										$GvItems = @()
										forEach ($Item in $Sub1.Ports.Items | Sort-Object ItemName)
										{
											$GvItems += (Get-ItemTmp -i 3) -replace '{{ ItemName }}', $Item.ItemName
										}
										$GvPort = (Get-PortTmp -i 1) -replace '{{ PortId }}', $Sub1.Ports.PortId -replace '{{ Items }}', $GvItems
										$GvSubgraph += (Get-SubgraphTmp -i 0) -replace '{{ SubgraphId }}', $Sub1.SubgraphId -replace '{{ SubgraphName }}', $Sub1.SubgraphName -replace '{{ Color }}', $Sub1.Props -replace '{{ Subgraphs }}', '' -replace '{{ Ports }}', $GvPort
									}
								}
								
								#EDGES
								$Edges = $DfdData.Subgraphs.Ports.Edges + $DfdData.Subgraphs.Subgraphs.Ports.Edges + $DfdData.Subgraphs.Subgraphs.Subgraphs.Ports.Edges
								$GvEdges = @()
								forEach ($Edge in $Edges)
								{
									if ($Edge)
									{
										$GvEdge = $EdgeTmp -replace '{{ From.PortId }}', $Edge.From.PortId -replace '{{ To.PortId }}', $Edge.To.PortId
										if ($GvEdges -notcontains $GvEdge)
										{
											$GvEdges += $GvEdge
										}
									}
								}
							}
							end
							{
								return $GvGraph -replace '{{ Subgraphs }}', $GvSubgraph -replace '{{ Edges }}', $GvEdges
							}
						}
						#endregion						
					}
					process
					{
						$Msg = "DOCS - $($DocsData._hcposh.FileBaseName)"; Write-Host $Msg -ForegroundColor Magenta; Write-Verbose $Msg; Write-Log $Msg;
						#region ADD LINEAGE
						try
						{
							$Msg = "$(" " * 4)Adding entity data lineage..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
							foreach ($Entity in $DocsData.Entities)
							{
								$Entity | Add-Member -Type NoteProperty -Name Lineage -Value @()
								$Entity.Lineage = Create-Nodes -entity $Entity
							}
						}
						catch
						{
							$Msg = "$(" " * 8)Unable to add data lineage properties"; Write-Host $Msg -ForegroundColor Yellow; Write-Verbose $Msg; Write-Log $Msg 'warning';
							$Msg = "$(" " * 8)$($Error[0])"; Write-Host $Msg -ForegroundColor Yellow; Write-Verbose $Msg; Write-Log $Msg 'warning';
						}
						#endregion
						#region ADD DIAGRAMS
						$DocsData | Add-Member -Type NoteProperty -Name Diagrams -Value (New-Object PSObject -Property @{ Erd = $Null; Dfd = $Null; DfdUpstream = $Null; DfdDownstream = $Null })
						#region ERD
						try
						{
							$Msg = "$(" " * 4)Adding erd diagram..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
							$DocsData.Diagrams.Erd = (Create-Erd -DocsData $DocsData).Erd
							
							if (!$KeepFullLineage)
							{
								#Remove un-needed properties
								if (($DocsData.Diagrams.Erd.PSobject.Properties.Name -match 'Data'))
								{
									$DocsData.Diagrams.Erd.PSObject.Properties.Remove('Data')
								}
							}							
						}
						catch
						{
							$Msg = "$(" " * 8)Unable to add erd diagram"; Write-Host $Msg -ForegroundColor Yellow; Write-Verbose $Msg; Write-Log $Msg 'warning';
						}
						#endregion
						#region DFD
						$Msg = "$(" " * 4)Adding dfd diagrams..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
						try
						{
							$DocsData.Diagrams.Dfd = (Create-Dfd -Name $DocsData.DatamartNM -Lineage ($DocsData.Entities | Where-Object $validPublicEntities).Lineage -Type Both).Dfd
							$DocsData.Diagrams.DfdUpstream = (Create-Dfd -Name $DocsData.DatamartNM -Lineage ($DocsData.Entities | Where-Object $validPublicEntities).Lineage -Type Upstream).Dfd
							$DocsData.Diagrams.DfdDownstream = (Create-Dfd -Name $DocsData.DatamartNM -Lineage ($DocsData.Entities | Where-Object $validPublicEntities).Lineage -Type Downstream).Dfd
							
							if (!$KeepFullLineage)
							{
								#Remove un-needed properties
								if (($DocsData.Diagrams.Dfd.PSobject.Properties.Name -match 'Data'))
								{
									$DocsData.Diagrams.Dfd.PSObject.Properties.Remove('Data')
								}
								if (($DocsData.Diagrams.DfdUpstream.PSobject.Properties.Name -match 'Data'))
								{
									$DocsData.Diagrams.DfdUpstream.PSObject.Properties.Remove('Data')
								}
								if (($DocsData.Diagrams.DfdDownstream.PSobject.Properties.Name -match 'Data'))
								{
									$DocsData.Diagrams.DfdDownstream.PSObject.Properties.Remove('Data')
								}
							}							
							
							#ADD DFD DIAGRAM TO EVERY PUBLIC ENTITY
							forEach ($PublicEntity in $DocsData.Entities | Where-Object $validPublicEntities)
							{
								if ($PublicEntity.SourcedByEntities)
								{
									$PublicEntity | Add-Member -Type NoteProperty -Name Diagrams -Value (New-Object PSObject -Property @{ Dfd = $Null; DfdUpstream = $Null; DfdDownstream = $Null })
									$Msg = "$(" " * 4)Adding dfd diagrams...$($PublicEntity.FullyQualifiedNames.Table)..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
									$PublicEntity.Diagrams.Dfd = (Create-Dfd -Name $PublicEntity.FullyQualifiedNames.Table -Lineage $PublicEntity.Lineage -Type Both).Dfd
									$PublicEntity.Diagrams.DfdDownstream = (Create-Dfd -Name $PublicEntity.FullyQualifiedNames.Table -Lineage $PublicEntity.Lineage -Type Downstream).Dfd
									$PublicEntity.Diagrams.DfdUpstream = (Create-Dfd -Name $PublicEntity.FullyQualifiedNames.Table -Lineage $PublicEntity.Lineage -Type Upstream).Dfd
								}
							}
						}
						catch
						{
							$Msg = "$(" " * 8)Requirements not met for dfd diagrams:`n$(" " * 10)At least 1 public ""summary"" entity for Framework SAM or 1 public entity in Generic SAM"; Write-Host $Msg -ForegroundColor Yellow; Write-Verbose $Msg; Write-Log $Msg 'warning';
						}
						
						#Replace Lineage property with a cleaner version for display purposes
						forEach ($Entity in $DocsData.Entities | Where-Object $validPublicEntities)
						{
							$Upstream = Get-LineageCollection -Lineage $Entity.Lineage.Upstream -DocsData $DocsData;
							$Downstream = New-Object PSObject;
							if ($($Entity.Lineage.Downstream | Where-Object Level -NE 0))
							{
								$Downstream = Get-LineageCollection -Lineage $($Entity.Lineage.Downstream | Where-Object Level -NE 0) -DocsData $DocsData;
							}
							$Entity | Add-Member -Type NoteProperty -Name LineageMinimal -Value (
								New-Object PSObject -Property @{
									Upstream   = $Upstream;
									Downstream = $Downstream;
								}
							)
						}
						if (!$KeepFullLineage)
						{
							forEach ($Entity in $DocsData.Entities)
							{
								if (($Entity.PSobject.Properties.Name -match 'Lineage'))
								{
									$Entity.PSObject.Properties.Remove('Lineage')
								}
							}
						}
						
						#endregion						
						#endregion
						#region ADD COUNT DETAILS
						$Sources = New-Object PSObject
						$Sources | Add-Member -Type NoteProperty -Name DelimitedList -Value (($DocsData.SourcedByEntities | Where-Object { $_.TableOrigin -eq 'External' -and $_.DatabaseNM -notin @('Shared', 'IDEA') } | Group-Object DatabaseNM).Name -join ', ');
						$Sources | Add-Member -Type NoteProperty -Name List -Value ($DocsData.SourcedByEntities | Where-Object { $_.TableOrigin -eq 'External' -and $_.DatabaseNM -notin @('Shared', 'IDEA') } | Group-Object DatabaseNM | Select-Object Name).Name;
						$Sources | Add-Member -Type NoteProperty -Name Count -Value (($DocsData.SourcedByEntities | Where-Object { $_.TableOrigin -eq 'External' -and $_.DatabaseNM -notin @('Shared', 'IDEA') } | Group-Object DatabaseNM | Measure-Object).Count);
						$Sources | Add-Member -Type NoteProperty -Name EntitiesCount -Value (($DocsData.SourcedByEntities | Where-Object { $_.TableOrigin -eq 'External' -and $_.DatabaseNM -notin @('Shared', 'IDEA') } | Measure-Object).Count);
						
						$Entities = New-Object PSObject
						$Entities | Add-Member -Type NoteProperty -Name Count -Value ($DocsData.Entities | Measure-Object).Count;
						$Entities | Add-Member -Type NoteProperty -Name PersistedCount -Value ($DocsData.Entities | Where-Object { $_.IsPersisted } | Measure-Object).Count;
						$Entities | Add-Member -Type NoteProperty -Name NonPersistedCount -Value ($DocsData.Entities | Where-Object { !($_.IsPersisted) } | Measure-Object).Count;
						$Entities | Add-Member -Type NoteProperty -Name ProtectedCount -Value ($DocsData.Entities | Where-Object { $_.IsProtected } | Measure-Object).Count;
						$Entities | Add-Member -Type NoteProperty -Name PublicCount -Value ($DocsData.Entities | Where-Object { $_.IsPublic } | Measure-Object).Count;
						
						$Columns = New-Object PSObject
						$Columns | Add-Member -Type NoteProperty -Name PublicCount -Value (($DocsData.Entities | Where-Object { $_.IsPublic }).Columns | Measure-Object).Count;
						$Columns | Add-Member -Type NoteProperty -Name ExtendedCount -Value (($DocsData.Entities | Where-Object { $_.IsPublic }).Columns | Where-Object { $_.IsExtended } | Measure-Object).Count;
						
						$Bindings = New-Object PSObject
						$Bindings | Add-Member -Type NoteProperty -Name Count -Value ($DocsData.Entities.Bindings | Where-Object { $_.BindingStatus -eq 'Active' } | Measure-Object).Count;
						$Bindings | Add-Member -Type NoteProperty -Name ProtectedCount -Value ($DocsData.Entities.Bindings | Where-Object { $_.BindingStatus -eq 'Active' -and $_.IsProtected } | Measure-Object).Count;
						$Bindings | Add-Member -Type NoteProperty -Name FullCount -Value ($DocsData.Entities.Bindings | Where-Object { $_.LoadType -eq 'Full' -and $_.BindingStatus -eq 'Active' } | Measure-Object).Count;
						$Bindings | Add-Member -Type NoteProperty -Name IncrementalCount -Value ($DocsData.Entities.Bindings | Where-Object { $_.LoadType -eq 'Incremental' -and $_.BindingStatus -eq 'Active' } | Measure-Object).Count;
						
						$Indexes = New-Object PSObject
						$Indexes | Add-Member -Type NoteProperty -Name ClusteredCount -Value ($DocsData.Entities.Indexes | Where-Object { $_.IndexTypeCode -eq 'Clustered' -and $_.IsActive } | Measure-Object).Count;
						$Indexes | Add-Member -Type NoteProperty -Name NonClusteredCount -Value ($DocsData.Entities.Indexes | Where-Object { $_.IndexTypeCode -eq 'Non-Clustered' -and $_.IsActive } | Measure-Object).Count;
						
						$Counts = New-Object PSObject
						$Counts | Add-Member -Type NoteProperty -Name Sources -Value $Sources;
						$Counts | Add-Member -Type NoteProperty -Name Entities -Value $Entities;
						$Counts | Add-Member -Type NoteProperty -Name Columns -Value $Columns;
						$Counts | Add-Member -Type NoteProperty -Name Bindings -Value $Bindings;
						$Counts | Add-Member -Type NoteProperty -Name Indexes -Value $Indexes;
						
						$DocsData | Add-Member -Type NoteProperty -Name Counts -Value $Counts;
						#endregion
						#region REMOVE DATA_ALL PROPERTY (UNECESSARY FOR DOCS)
						foreach ($Entity in $DocsData.Entities)
						{
							if ($Entity.DataEntryData)
							{
								if ($Entity.DataEntryData.Data_All)
								{
									$Entity.DataEntryData.PSObject.Properties.Remove('Data_All')
								}
							}
						}
						#endregion
						
						$DocsData._hcposh.LastWriteTime = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.ffffff")
						
						#Directories
						$DataDir = "$($OutDir)\static\data"; New-Directory -Dir $DataDir;
						
						#Files
						$DocsSourcePath = "$(Split-Path (Get-Module -ListAvailable HCPosh)[0].path -Parent)\docs\*";
						$DocsDestinationPath = $OutDir;
						$DataFilePath = "$($DataDir)\dataMart.js";
						try
						{
							if (($DocsData.Entities | Where-Object $validPublicEntities | measure).Count -eq 0) { throw; }
							Copy-Item -Path $DocsSourcePath -Recurse -Destination $DocsDestinationPath -Force
							'dataMart = ' + ($DocsData | ConvertTo-Json -Depth 100 -Compress) | Out-File $DataFilePath -Encoding Default -Force | Out-Null
							$Msg = "$(" " * 4)Created new file --> $($DocsData._hcposh.FileBaseName)\$(Split-Path $DataDir -Leaf)\$(Split-Path $DataFilePath -Leaf)."; Write-Host $Msg -ForegroundColor Cyan; Write-Verbose $Msg; Write-Log $Msg;
						}
						catch
						{
							$Msg = "$(" " * 4)Unable to find valid public entities or An error occurred when trying to create the docs folder structure"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
						}
						if ($OutZip)
						{
							try
							{
								Zip -Directory $DocsDestinationPath -Destination ($DocsDestinationPath + '_docs.zip')
								if (Test-Path $DocsDestinationPath)
								{
									Remove-Item $DocsDestinationPath -Recurse -Force | Out-Null
								}
								$Msg = "$(" " * 4)Zipped file of directory --> $($DocsDestinationPath + '_docs.zip')"; Write-Host $Msg -ForegroundColor Cyan; Write-Verbose $Msg; Write-Log $Msg;
							}
							catch
							{
								$Msg = "$(" " * 4)Unable to zip the docs directory"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
							}
						}
						$Msg = "Success!`r`n"; Write-Host $Msg -ForegroundColor Green; Write-Verbose $Msg; Write-Log $Msg;
						$Output = New-Object PSObject
						$Output | Add-Member -Type NoteProperty -Name DocsData -Value $DocsData
						return $Output
					}
				}
			}
			'Diagrams' {
				function Get-Diagrams
				{
					param
					(
						[Parameter(Mandatory = $True)]
						[psobject]$DocsData,
						[Parameter(Mandatory = $True)]
						[string]$OutDir,
						[switch]$OutZip
					)
					begin
					{
						#region CREATE DIRECTORIES
						function New-Directory ($Dir)
						{
							If (!(Test-Path $Dir))
							{
								New-Item -ItemType Directory -Force -Path $Dir -ErrorAction Stop | Out-Null
							}
						}
						#endregion
						
						$validPublicEntities = { !($_.IsOverridden) -and $_.IsPublic -and (@('Summary', 'Generic') -contains $_.ClassificationCode) }
						
						#Directories
						$DiagramsDir = "$($OutDir)"; New-Directory -Dir $DiagramsDir;
						$GvDir = "$($DiagramsDir)\gv"; New-Directory -Dir $GvDir;
					}
					process
					{
						$Msg = "DIAGRAMS - $($DocsData._hcposh.FileBaseName)"; Write-Host $Msg -ForegroundColor Magenta; Write-Verbose $Msg; Write-Log $Msg;
						$Msg = "$(" " * 4)Adding graphviz files (gv)..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
						#region CREATE GV FILES
						$DocsData.Diagrams.Erd.Graphviz.Minimal | Out-File -FilePath $($GvDir + '\ERD_Minimal.gv') -Encoding Default | Out-Null
						$DocsData.Diagrams.Erd.Graphviz.Full | Out-File -FilePath $($GvDir + '\ERD_Full.gv') -Encoding Default | Out-Null
						$DocsData.Diagrams.Dfd.Graphviz.LR | Out-File -FilePath $($GvDir + '\DFD_LR.gv') -Encoding Default | Out-Null
						$DocsData.Diagrams.Dfd.Graphviz.TB | Out-File -FilePath $($GvDir + '\DFD_TB.gv') -Encoding Default | Out-Null
						$DocsData.Diagrams.DfdUpstream.Graphviz.LR | Out-File -FilePath $($GvDir + '\DFD_LR_Upstream.gv') -Encoding Default | Out-Null
						$DocsData.Diagrams.DfdUpstream.Graphviz.TB | Out-File -FilePath $($GvDir + '\DFD_TB_Upstream.gv') -Encoding Default | Out-Null
						$DocsData.Diagrams.DfdDownstream.Graphviz.LR | Out-File -FilePath $($GvDir + '\DFD_LR_Downstream.gv') -Encoding Default | Out-Null
						$DocsData.Diagrams.DfdDownstream.Graphviz.TB | Out-File -FilePath $($GvDir + '\DFD_TB_Downstream.gv') -Encoding Default | Out-Null
						forEach ($DocsPublic in $DocsData.Entities | Where-Object $validPublicEntities)
						{
							$PublicDFD_LR = $DocsPublic.Diagrams.Dfd.Graphviz.LR
							$PublicDFD_TB = $DocsPublic.Diagrams.Dfd.Graphviz.TB
							if ($PublicDFD_LR -and $PublicDFD_TB)
							{
								$PublicDFD_LR | Out-File -FilePath $($GvDir + "\DFD_$($DocsPublic.FullyQualifiedNames.Table)_LR.gv") -Encoding Default | Out-Null
								$PublicDFD_TB | Out-File -FilePath $($GvDir + "\DFD_$($DocsPublic.FullyQualifiedNames.Table)_TB.gv") -Encoding Default | Out-Null
							}
							
							$PublicDFD_LR_UPSTREAM = $DocsPublic.Diagrams.DfdUpstream.Graphviz.LR
							$PublicDFD_TB_UPSTREAM = $DocsPublic.Diagrams.DfdUpstream.Graphviz.TB
							if ($PublicDFD_LR_UPSTREAM -and $PublicDFD_TB_UPSTREAM)
							{
								$PublicDFD_LR_UPSTREAM | Out-File -FilePath $($GvDir + "\DFD_$($DocsPublic.FullyQualifiedNames.Table)_LR_Upstream.gv") -Encoding Default | Out-Null
								$PublicDFD_TB_UPSTREAM | Out-File -FilePath $($GvDir + "\DFD_$($DocsPublic.FullyQualifiedNames.Table)_TB_Upstream.gv") -Encoding Default | Out-Null
							}
							
							$PublicDFD_LR_DOWNSTREAM = $DocsPublic.Diagrams.DfdDownstream.Graphviz.LR
							$PublicDFD_TB_DOWNSTREAM = $DocsPublic.Diagrams.DfdDownstream.Graphviz.TB
							if ($PublicDFD_LR_DOWNSTREAM -and $PublicDFD_TB_DOWNSTREAM)
							{
								$PublicDFD_LR_DOWNSTREAM | Out-File -FilePath $($GvDir + "\DFD_$($DocsPublic.FullyQualifiedNames.Table)_LR_Downstream.gv") -Encoding Default | Out-Null
								$PublicDFD_TB_DOWNSTREAM | Out-File -FilePath $($GvDir + "\DFD_$($DocsPublic.FullyQualifiedNames.Table)_TB_Downstream.gv") -Encoding Default | Out-Null
							}
							
						}
						#endregion
						$Msg = "$(" " * 4)Adding svg, pdf, and png files using Graphviz..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
						#region CREATE SVG, PDF, PNG FILES
						HCPosh -Graphviz -InputDir $GvDir -OutDir $DiagramsDir -OutType svg
						HCPosh -Graphviz -InputDir $GvDir -OutDir "$($DiagramsDir)\pdf" -OutType pdf
						HCPosh -Graphviz -InputDir $GvDir -OutDir "$($DiagramsDir)\png" -OutType png
						#endregion
						if ($OutZip)
						{
							try
							{
								Zip -Directory $DiagramsDir -Destination ($DiagramsDir + '_diagrams.zip')
								if (Test-Path $DiagramsDir)
								{
									Remove-Item $DiagramsDir -Recurse -Force | Out-Null
								}
								$Msg = "$(" " * 4)Zipped file of directory --> $($DiagramsDir + '_diagrams.zip')"; Write-Host $Msg -ForegroundColor Cyan; Write-Verbose $Msg; Write-Log $Msg;
							}
							catch
							{
								$Msg = "$(" " * 4)Unable to zip the diagrams directory"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
							}
						}						
					}
					end
					{
						$Msg = "Success!`r`n"; Write-Host $Msg -ForegroundColor Green; Write-Verbose $Msg; Write-Log $Msg;
					}
				}
			}
			'Impact' {
				function Invoke-ImpactAnalysis
				{
					[CmdletBinding()]
					[OutputType([PSObject])]
					param
					(
						[Parameter(Mandatory = $True)]
						[string]$Server,
						[Parameter(Mandatory = $False)]
						[string]$ConfigPath = "./_impactConfig.json",
						[Parameter(Mandatory = $False)]
						[string]$OutDir = "./_impact"
					)
					begin
					{
						function create-emptyfile ($OutFile)
						{
							try
							{
								if (Test-Path $OutFile)
								{
									Remove-Item $OutFile -Force | Out-Null
								}
								New-Item -ItemType File -Force -Path $OutFile -ErrorAction Stop | Out-Null
							}
							catch
							{
								$Msg = "$(" " * 4)Unable to create output directory (""$(Split-Path $OutDir -Leaf)"")"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
							}
						}
						
						$Msg = "Impact analysis [$($Server)]"; Write-Host $Msg -ForegroundColor Magenta; Write-Verbose $Msg; Write-Log $Msg;
						if (!(Test-Path $ConfigPath))
						{
							$Msg = "$(" " * 4)Unable to find configuration file in current directory or specified path"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
							Do { $TemplateFlag = Read-Host -Prompt 'Create a config template? (Y/N)' }
							while ('y', 'n' -notcontains $TemplateFlag)
							
							if ($TemplateFlag -eq 'y')
							{
								create-emptyfile './_impactConfig.json'; Add-Content ./_impactConfig.json "{`n  ""Columns"": {`n    ""SQL"": {`n      ""Connection"": {`n        ""Database"": ""<database>""`n      },`n      ""FilePath"": ""./columns.sql""`n    }`n  },`n  ""Queries"": {`n    ""SQL"": {`n      ""Connection"": {`n        ""Database"": ""<database>""`n      },`n      ""FilePath"": ""./queries.sql""`n    }`n  },`n  ""Mappings"": {`n    ""CSV"": {`n      ""FilePath"": ""./mappings.csv""`n    }`n  }`n}";
								create-emptyfile './columns.sql'; Add-Content ./columns.sql "SELECT`n   /******REQUIRED******/`n    tbl.DatabaseNM`n   ,tbl.SchemaNM`n   ,tbl.TableNM`n   ,col.ColumnNM`n   /********************/`n   /* ADD ANY OTHER GROUPERS YOU NEED`n   ,Grouper1NM?`n   ,Grouper2NM?`n   */`nFROM CatalystAdmin.TableBASE AS tbl`nINNER JOIN CatalystAdmin.DatamartBASE AS dm`n   ON dm.DatamartID = tbl.DatamartID`nINNER JOIN CatalystAdmin.ColumnBASE AS col`n   ON col.TableID = tbl.TableID`n      AND col.IsSystemColumnFLG = 'N'`nWHERE dm.DatamartNM = '<MY_DATAMART>'`n      AND tbl.PublicFLG = 1;"
								create-emptyfile './mappings.csv'; '' | Select-Object FromDatabaseNM, FromSchemaNM, FromTableNM, FromColumnNM, ToDatabaseNM, ToSchemaNM, ToTableNM, ToColumnNM | Export-Csv './mappings.csv' -NoTypeInformation
								create-emptyfile './queries.sql'; Add-Content ./queries.sql "SELECT`n   /******REQUIRED******/`n    obj.AttributeValueLongTXT AS QueryTXT`n   /********************/`n   /* ADD ANY OTHER GROUPERS YOU NEED`n   ,tbl.ViewNM+' ('+b.BindingNM+')' AS QueryNM`n   ,'SAM Designer' AS Grouper1NM`n   ,dm.DatamartNM AS Grouper2NM`n   */`nFROM CatalystAdmin.ObjectAttributeBASE AS obj`nINNER JOIN CatalystAdmin.BindingBASE AS b`n   ON b.BindingID = obj.ObjectID`nINNER JOIN CatalystAdmin.TableBASE AS tbl`n   ON tbl.TableID = b.DestinationEntityID`nINNER JOIN CatalystAdmin.DataMartBASE AS dm`n   ON dm.DatamartID = tbl.DatamartID`nWHERE obj.ObjectTypeCD = 'Binding'`n      AND obj.AttributeNM = 'UserDefinedSQL'`n      AND b.BindingClassificationCD != 'SourceMart'`n      AND LEN(obj.AttributeValueLongTXT) > 0`n      AND tbl.TableID NOT IN`n(`n SELECT`n     tbl.TableID`n FROM CatalystAdmin.TableBASE AS tbl`n INNER JOIN CatalystAdmin.DatamartBASE AS dm`n    ON dm.DatamartID = tbl.DatamartID`n WHERE dm.DatamartNM = '<MY_DATAMART>'`n);"
								
								$Msg = "Configuration files created, rerun when you are ready.`r`n"; Write-Host $Msg -ForegroundColor Green; Write-Verbose $Msg; Write-Log $Msg;
							}
							Break;
						}
						else
						{
							$Msg = "$(" " * 4)Creating output directory..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
							try
							{
								if (Test-Path $OutDir)
								{
									Remove-Item $OutDir -Recurse -Force | Out-Null
								}
								New-Item -ItemType Directory -Force -Path $OutDir -ErrorAction Stop | Out-Null
								$Msg = "$(" " * 8)Created ""$(Split-Path $OutDir -Leaf)"" directory"; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
								
								New-Item -ItemType Directory -Force -Path "$($OutDir)/raw/csv" -ErrorAction Stop | Out-Null
								$Msg = "$(" " * 8)Created ""$(Split-Path $OutDir -Leaf)/raw/csv"" directory"; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
								
								New-Item -ItemType Directory -Force -Path "$($OutDir)/raw/json" -ErrorAction Stop | Out-Null
								$Msg = "$(" " * 8)Created ""$(Split-Path $OutDir -Leaf)/raw/json"" directory"; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
							}
							catch
							{
								$Msg = "$(" " * 4)Unable to create output directory (""$(Split-Path $OutDir -Leaf)"" or ""$(Split-Path $OutDir -Leaf)/raw"")"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
							}
							
							try
							{
								$Config = Get-Content $ConfigPath | ConvertFrom-Json
								
								$Properties = ($Config | Get-Member | Where-Object MemberType -eq NoteProperty).Name
								if (!($Properties -contains 'Columns' -and $Properties -contains 'Queries'))
								{
									$Msg = "$(" " * 8)Configruation file (""$(Split-Path $ConfigPath -Leaf)"") must contain all of the the following properies: Columns, Queries"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
									Break;
								}
								$MappingsFlag = $False;
								if ($Properties -contains 'Mappings')
								{
									$MappingsFlag = $True;
								}
								
								$Msg = "$(" " * 4)Getting data..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
								#region Columns  (REQUIRED)
								$ColumnsPath = $Config.Columns.SQL.FilePath
								if (!(Test-Path $ColumnsPath))
								{
									$Msg = "$(" " * 4)Unable to find ""$(Split-Path $ColumnsPath -Leaf)"" specified in the configuration file"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
									Break;
								}
								else
								{
									try
									{
										$ColumnsSQL = Get-Content $ColumnsPath | Out-String
										
										try
										{
											$ColumnsDb = $Config.Columns.SQL.Connection.Database
											if (!($ColumnsDb))
											{
												$Columns = Invoke-Sqlcmd -Query $ColumnsSQL -ServerInstance $Server
											}
											else
											{
												$Columns = Invoke-Sqlcmd -Query $ColumnsSQL -ServerInstance $Server -Database $ColumnsDb
											}
											$Msg = "$(" " * 8)$(($Columns | Measure).Count) records from query ""$(Split-Path $ColumnsPath -Leaf)"""; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
											
											$Properties = ($Columns[0] | Get-Member | Where-Object MemberType -eq Property).Name
											
											if (!($Properties.ToLower() -contains 'databasenm' -and $Properties.ToLower() -contains 'schemanm' -and $Properties.ToLower() -contains 'tablenm' -and $Properties.ToLower() -contains 'columnnm'))
											{
												$Msg = "$(" " * 8)Sql query must contain the following columns: DatabaseNM, SchemaNM, TableNM, and ColumnNM"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
												Break;
											}
											
											$UpdatedColumns = @()
											$I = 0
											foreach ($Column in $Columns)
											{
												$Fqn = "$($Column.DatabaseNM.ToLower()).$($Column.SchemaNM.ToLower()).$($Column.TableNM.ToLower() -replace 'base$', '').$($Column.ColumnNM.ToLower())"
												$UpdatedColumn = New-Object PSObject
												$UpdatedColumn | Add-Member -Type NoteProperty -Name `$ColumnId -Value $I
												$UpdatedColumn | Add-Member -Type NoteProperty -Name `$Fqn -Value $Fqn
												$UpdatedColumn | Add-Member -Type NoteProperty -Name `$Queries -Value @()
												if ($MappingsFlag)
												{
													$UpdatedColumn | Add-Member -Type NoteProperty -Name `$Mappings -Value @()
												}
												foreach ($Property in $Properties)
												{
													$UpdatedColumn | Add-Member -Type NoteProperty -Name $Property -Value $Column.$Property
												}
												$UpdatedColumns += $UpdatedColumn
												$I++
											}
											$Columns = $UpdatedColumns;
										}
										catch
										{
											$Msg = "$(" " * 8)Unable to establish a connection to db or execute query"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
											$Msg = "$(" " * 8)$($Error[0])"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
										}
									}
									catch
									{
										$Msg = "$(" " * 4)Unable to get the contents of the ""$(Split-Path $Config.Queries.SQL.FilePath -Leaf)"" file"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
										Break;
									}
								}
								#endregion
								#region Queries  (REQUIRED)
								$QueriesPath = $Config.Queries.SQL.FilePath
								if (!(Test-Path $QueriesPath))
								{
									$Msg = "$(" " * 4)Unable to find ""$(Split-Path $QueriesPath -Leaf)"" specified in the configuration file"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
									Break;
								}
								else
								{
									try
									{
										$QueriesSQL = Get-Content $QueriesPath | Out-String
										
										try
										{
											$QueriesDb = $Config.Queries.SQL.Connection.Database
											if (!($QueriesDb))
											{
												$Queries = Invoke-Sqlcmd -Query $QueriesSQL -ServerInstance $Server -MaxCharLength 8000000
											}
											else
											{
												$Queries = Invoke-Sqlcmd -Query $QueriesSQL -ServerInstance $Server -Database $QueriesDb -MaxCharLength 8000000
											}
											$Msg = "$(" " * 8)$(($Queries | Measure).Count) records from query ""$(Split-Path $QueriesPath -Leaf)"""; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
											
											$Properties = ($Queries[0] | Get-Member | Where-Object MemberType -eq Property).Name
											
											if (!($Properties.ToLower() -contains 'querytxt'))
											{
												$Msg = "$(" " * 8)Sql query must contain the following column: QueryTXT"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
												Break;
											}
											
											$I = 0
											$UpdatedQueries = @()
											foreach ($Query in $Queries)
											{
												$UpdatedQuery = New-Object PSObject
												$UpdatedQuery | Add-Member -Type NoteProperty -Name `$QueryId -Value $I
												$UpdatedQuery | Add-Member -Type NoteProperty -Name `$Query -Value $Query.querytxt
												$UpdatedQuery | Add-Member -Type NoteProperty -Name `$Columns -Value @()
												foreach ($Property in $Properties | Where-Object { $_.ToLower() -ne 'querytxt' })
												{
													$UpdatedQuery | Add-Member -Type NoteProperty -Name $Property -Value $Query.$Property
												}
												$UpdatedQueries += $UpdatedQuery
												$I++
											}
											$Queries = $UpdatedQueries;
										}
										catch
										{
											$Msg = "$(" " * 8)Unable to establish a connection to db or execute query"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
											$Msg = "$(" " * 8)$($Error[0])"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
										}
									}
									catch
									{
										$Msg = "$(" " * 4)Unable to get the contents of the ""$(Split-Path $Config.Queries.SQL.FilePath -Leaf)"" file"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
										Break;
									}
								}
								#endregion
								#region Mappings (OPTIONAL)
								if ($MappingsFlag)
								{
									$MappingsPath = $Config.Mappings.CSV.FilePath
									if (!(Test-Path $MappingsPath))
									{
										$Msg = "$(" " * 4)Unable to find ""$(Split-Path $MappingsPath -Leaf)"" specified in the configuration file"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
										Break;
									}
									else
									{
										try
										{
											$Mappings = Get-Content $MappingsPath | ConvertFrom-Csv
										}
										catch
										{
											$Msg = "$(" " * 4)Unable to parse the contents of the ""$(Split-Path $Config.Mappings.CSV.FilePath -Leaf)"" file"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
											Break;
										}
										$Msg = "$(" " * 8)$(($Mappings | Measure).Count) records from csv ""$(Split-Path $MappingsPath -Leaf)"""; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
										
										$Properties = ($Mappings[0] | Get-Member | Where-Object MemberType -eq NoteProperty).Name
										
										if (!($Properties.ToLower() -contains 'fromdatabasenm' -and $Properties.ToLower() -contains 'fromschemanm' -and $Properties.ToLower() -contains 'fromtablenm' -and $Properties.ToLower() -contains 'fromcolumnnm' -and `
												$Properties.ToLower() -contains 'todatabasenm' -and $Properties.ToLower() -contains 'toschemanm' -and $Properties.ToLower() -contains 'totablenm' -and $Properties.ToLower() -contains 'tocolumnnm'))
										{
											
											$Msg = "$(" " * 8)Csv file must contain the following columns: FromDatabaseNM, FromSchemaNM, FromTableNM, FromColumnNM, ToDatabaseNM, ToSchemaNM, ToTableNM, ToColumnNM"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
											Break;
										}
										
										foreach ($Mapping in $Mappings)
										{
											$Fqn = "$($Mapping.FromDatabaseNM.ToLower()).$($Mapping.FromSchemaNM.ToLower()).$($Mapping.FromTableNM.ToLower() -replace 'base$', '').$($Mapping.FromColumnNM.ToLower())"
											$Index = $Columns.'$Fqn'.indexOf($Fqn)
											if ($Index -gt -1)
											{
												$AddMapping = New-Object PSObject
												$AddMapping | Add-Member -Type NoteProperty -Name ToDatabaseNM -Value $Mapping.ToDatabaseNM
												$AddMapping | Add-Member -Type NoteProperty -Name ToSchemaNM -Value $Mapping.ToSchemaNM
												$AddMapping | Add-Member -Type NoteProperty -Name ToTableNM -Value $Mapping.ToTableNM
												$AddMapping | Add-Member -Type NoteProperty -Name ToColumnNM -Value $Mapping.ToColumnNM
												$Columns[$Index].'$Mappings' += $AddMapping
											}
										}
										$Msg = "$(" " * 8)$(($Columns.'$Mappings' | Measure).Count) columns assigned mappings"; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
										
										$MappingsFlag = $Columns | Where-Object { ($_.'$Mappings' | Measure).Count -eq 0 } | Select-Object @{ n = 'FromDatabaseNM'; e = { $_.DatabaseNM } }, @{ n = 'FromSchemaNM'; e = { $_.SchemaNM } }, @{ n = 'FromTableNM'; e = { $_.TableNM } }, @{ n = 'FromColumnNM'; e = { $_.ColumnNM } }, ToDatabaseNM, ToSchemaNM, ToTableNM, ToColumnNM
									}
								}
								#endregion
							}
							catch
							{
								$Msg = "$(" " * 4)Unable to parse the contents of ""$(Split-Path $ConfigPath -Leaf)"""; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
								$Msg = "$(" " * 4)$($Error[0])"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
								Break;
							}
						}
					}
					process
					{
						$Msg = "$(" " * 4)Parsing queries..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
						
						$ScriptStart = (Get-Date)
						
						$DataColumns = $Columns
						
						if ($MappingsFlag)
						{
							$DataMappings = @()
							foreach ($Column in $Columns)
							{
								foreach ($Mapping in $Column.'$Mappings')
								{
									$ColumnMapping = New-Object PSObject
									$ColumnMapping | Add-Member -Type NoteProperty -Name `$ColumnId -Value $Column.'$ColumnId'
									$ColumnMapping | Add-Member -Type NoteProperty -Name ToDatabaseNM -Value $Mapping.ToDatabaseNM
									$ColumnMapping | Add-Member -Type NoteProperty -Name ToSchemaNM -Value $Mapping.ToSchemaNM
									$ColumnMapping | Add-Member -Type NoteProperty -Name ToTableNM -Value $Mapping.ToTableNM
									$ColumnMapping | Add-Member -Type NoteProperty -Name ToColumnNM -Value $Mapping.ToColumnNM
									$DataMappings += $ColumnMapping
								}
							}
						}
						
						try
						{
							$I = 0; $J = 0; $Total = ($Queries | Measure).Count;
							$DataQueriesToColumns = @()
							$DataQueries = @()
							foreach ($Query in $Queries)
							{
								if ($I -eq 0)
								{
									$Msg = "$(" " * 8)$(("{0:P0}" -f ($J/$Total)).PadLeft(5)) $($J.ToString().PadLeft($Total.ToString().Length))/$($Total) ...parsing..."; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
								}
								$Q = $True;
								$ParsedTables = $(Split-Sql -Query $Query.'$Query' -Log $False -SelectStar $False -Brackets $False)
								
								foreach ($ParsedTable in $ParsedTables)
								{
									foreach ($ParsedColumn in $ParsedTable.Columns)
									{
										$Fqn = "$($ParsedTable.FullyQualifiedNM.ToLower() -replace 'base$', '').$($ParsedColumn.ColumnNM.ToLower())"
										$Index = $DataColumns.'$Fqn'.indexOf($Fqn)
										if ($Index -gt -1)
										{
											$Match = New-Object PSObject
											$Match | Add-Member -Type NoteProperty -Name `$QueryId -Value $Query.'$QueryId'
											$Match | Add-Member -Type NoteProperty -Name `$ColumnId -Value $DataColumns[$Index].'$ColumnId'
											
											$DataQueriesToColumns += $Match
											if ($Q)
											{
												$DataQueries += $Query;
												$Q = $False;
											}
										}
									}
								}
								$I++; $J++;
								if ($I -eq 100) { $I = 0; }
							}
							$ScriptEnd = (Get-Date)
							$RunTime = New-Timespan -Start $ScriptStart -End $ScriptEnd
							$Msg = "$(" " * 8)$(("{0:P0}" -f ($Total/$Total)).PadLeft(5)) $($Total)/$($Total) Done ~ $("Elapsed Time: {0}:{1}:{2}" -f $RunTime.Hours, $Runtime.Minutes, $RunTime.Seconds)"; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
						}
						catch
						{
							$Msg = "$(" " * 8)An error occurred during query parsing"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
							$Msg = "$(" " * 8)$($Error[0])"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
							Break;
						}
						
						foreach ($Column in $DataQueriesToColumns)
						{
							$IXColumn = $DataColumns.'$ColumnId'.IndexOf($Column.'$ColumnId')
							$IXQuery = $DataQueries.'$QueryId'.IndexOf($Column.'$QueryId')
							$QueryObj = New-Object PSObject; $QueryObj | Add-Member -Type NoteProperty -Name '$QueryId' -Value $DataQueries[$IXQuery].'$QueryId';
							$ColumnObj = New-Object PSObject; $ColumnObj | Add-Member -Type NoteProperty -Name '$ColumnId' -Value $DataColumns[$IXColumn].'$ColumnId';
							$DataColumns[$IXColumn].'$Queries' += $QueryObj;
							$DataQueries[$IXQuery].'$Columns' += $ColumnObj;
						}
						
						#region CSV files
						$Msg = "$(" " * 4)Creating output csv files..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
						try
						{
							$DataColumns | Select-Object * -ExcludeProperty '$Mappings', '$Queries' | Export-Csv -Path "$($OutDir)/raw/csv/columns.csv" -NoTypeInformation -Force
							$Msg = "$(" " * 8)File created ""$(Split-Path $OutDir -Leaf)/raw/csv/columns.csv"""; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
						}
						catch
						{
							$Msg = "$(" " * 8)Something failed when creating the ""$(Split-Path $OutDir -Leaf)/raw/csv/columns.csv"" files"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
						}
						
						try
						{
							$DataQueries | Select-Object * -ExcludeProperty '$Query', '$Columns' | Export-Csv -Path "$($OutDir)/raw/csv/queries.csv" -NoTypeInformation -Force
							$Msg = "$(" " * 8)File created ""$(Split-Path $OutDir -Leaf)/raw/csv/queries.csv"""; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
						}
						catch
						{
							$Msg = "$(" " * 8)Something failed when creating the ""$(Split-Path $OutDir -Leaf)/raw/csv/queries.csv"" files"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
						}
						
						try
						{
							$DataQueriesToColumns | Export-Csv -Path "$($OutDir)/raw/csv/queries-to-columns.csv" -NoTypeInformation -Force
							$Msg = "$(" " * 8)File created ""$(Split-Path $OutDir -Leaf)/raw/csv/queries-to-columns.csv"""; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
						}
						catch
						{
							$Msg = "$(" " * 8)Something failed when creating the ""$(Split-Path $OutDir -Leaf)/raw/csv/queries-to-columns.csv"" files"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
						}
						
						if ($MappingsFlag)
						{
							try
							{
								$DataMappings | Export-Csv -Path "$($OutDir)/raw/csv/mappings.csv" -NoTypeInformation -Force
								$Msg = "$(" " * 8)File created ""$(Split-Path $OutDir -Leaf)/raw/csv/mappings.csv"""; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
							}
							catch
							{
								$Msg = "$(" " * 8)Something failed when creating the ""$(Split-Path $OutDir -Leaf)/raw/csv/mappings.csv"" files"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
							}
							
							try
							{
								$MappingsFlag | Export-Csv -Path $OutDir/raw/csv/unmapped.csv -NoTypeInformation
								$Msg = "$(" " * 8)File created ""$(Split-Path $OutDir -Leaf)/raw/csv/unmapped.csv"""; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
							}
							catch
							{
								$Msg = "$(" " * 8)Something failed when creating the ""$(Split-Path $OutDir -Leaf)/raw/csv/unmapped.csv"" files"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
							}
						}
						#endregion
						#region JSON files
						$Msg = "$(" " * 4)Creating output json files..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; Write-Log $Msg;
						try
						{
							$DataColumns | ConvertTo-Json -Depth 100 -Compress | Out-File "$($OutDir)/raw/json/columns.json" -Encoding Default -Force
							$Msg = "$(" " * 8)File created ""$(Split-Path $OutDir -Leaf)/raw/json/columns.json"""; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
						}
						catch
						{
							$Msg = "$(" " * 8)Something failed when creating the ""$(Split-Path $OutDir -Leaf)/raw/json/columns.json"" files"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
						}
						
						try
						{
							$DataQueries | ConvertTo-Json -Depth 100 -Compress | Out-File "$($OutDir)/raw/json/queries.json" -Encoding Default -Force
							$Msg = "$(" " * 8)File created ""$(Split-Path $OutDir -Leaf)/raw/json/queries.json"""; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
						}
						catch
						{
							$Msg = "$(" " * 8)Something failed when creating the ""$(Split-Path $OutDir -Leaf)/raw/json/queries.json"" files"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
						}
						
						if ($MappingsFlag)
						{
							try
							{
								$MappingsFlag | ConvertTo-Json -Depth 100 -Compress | Out-File $OutDir/raw/json/unmapped.json -Encoding Default -Force
								$Msg = "$(" " * 8)File created ""$(Split-Path $OutDir -Leaf)/raw/json/unmapped.json"""; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; Write-Log $Msg;
							}
							catch
							{
								$Msg = "$(" " * 8)Something failed when creating the ""$(Split-Path $OutDir -Leaf)/raw/json/unmapped.json"" files"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
							}
						}
						#endregion
					}
					end
					{
						$Msg = "Success!`r`n"; Write-Host $Msg -ForegroundColor Green; Write-Verbose $Msg; Write-Log $Msg;
					}
				}
			}
		}
	}
	process
	{
		switch ($PsCmdlet.ParameterSetName)
		{
			'SqlParser'  {
				Split-Sql -Query $Query -Log $Log -SelectStar $SelectStar -Brackets $Brackets
			}
			'Data'  {
				$Pipe = $Files | Select-Object @{ n = 'File'; e = { $_.FullName } }, @{ n = 'OutDir'; e = { "$($_.Directory)\_hcposh\$($_.BaseName)" } }
				
				if ($OutVar)
				{
					if ($Raw)
					{
						($Pipe | Get-Metadata_Raw | Select-Object MetadataRaw).MetadataRaw
					}
					else
					{
						($Pipe | Get-Metadata_Raw | Get-Metadata_New | Select-Object MetadataNew).MetadataNew
					}
				}
				else
				{
					if ($Raw)
					{
						$Pipe | Get-Metadata_Raw | Out-Null
					}
					else
					{
						$Pipe | Get-Metadata_Raw | Get-Metadata_New | Out-Null
					}
				}
			}
			'Docs' {
				if (!$OutDir)
				{
					$OutDir = (Get-Location).Path + '\_hcposh_docs'
				}
				$DocsDataArr = HCPosh -Data -OutVar -NoSplit | Where-Object { $_ };
				forEach ($DocsData in $DocsDataArr)
				{
					$NewOutDir = $OutDir + '\' + $DocsData._hcposh.FileBaseName
					if ($OutZip)
					{
						if ($OutVar)
						{
							(Get-Docs -DocsData $DocsData -OutDir $NewOutDir -OutZip | Select-Object DocsData).DocsData
						}
						else
						{
							Get-Docs -DocsData $DocsData -OutDir $NewOutDir -OutZip | Out-Null
						}
					}
					else
					{
						if ($OutVar)
						{
							(Get-Docs -DocsData $DocsData -OutDir $NewOutDir | Select-Object DocsData).DocsData
						}
						else
						{
							Get-Docs -DocsData $DocsData -OutDir $NewOutDir | Out-Null
						}
					}
				}
			}
			'Diagrams' {
				if (!$OutDir)
				{
					$OutDir = (Get-Location).Path + '\_hcposh_diagrams'
				}
				if ($OutZip)
				{
					$DocsDataArr = HCPosh -Docs -OutVar -OutDir $OutDir -OutZip | Where-Object { $_ };
				}
				else
				{
					$DocsDataArr = HCPosh -Docs -OutVar -OutDir $OutDir | Where-Object { $_ };
				}
				forEach ($DocsData in $DocsDataArr)
				{
					$NewOutDir = $OutDir + '\' + $DocsData._hcposh.FileBaseName
					if ($OutZip)
					{
						Get-Diagrams -DocsData $DocsData -OutDir $NewOutDir -OutZip | Out-Null
					}
					else
					{
						Get-Diagrams -DocsData $DocsData -OutDir $NewOutDir | Out-Null
					}
				}
			}
			'Impact' {
				if ($ConfigPath -or $OutDir)
				{
					if ($ConfigPath -and $OutDir)
					{
						Invoke-ImpactAnalysis -Server $Server -ConfigPath $ConfigPath -OutDir $OutDir
					}
					elseif ($ConfigPath)
					{
						Invoke-ImpactAnalysis -Server $Server -ConfigPath $ConfigPath
					}
					else
					{
						Invoke-ImpactAnalysis -Server $Server -OutDir $OutDir
					}
				}
				else
				{
					Invoke-ImpactAnalysis -Server $Server
				}
			}
			'Graphviz' {
				if (!$OutType) { $OutType = 'svg' }
				if (!$OutDir)
				{
					if ($InputDir)
					{
						$OutDir = $InputDir
					}
					else
					{
						$OutDir = (Get-Location).Path
					}
				}
				If (!(Test-Path $OutDir))
				{
					New-Item -ItemType Directory -Force -Path $OutDir -ErrorAction Stop | Out-Null
				}
				$Pipe = $GvFiles | Select-Object @{ n = 'File'; e = { $_.FullName } }, @{ n = 'OutType'; e = { $OutType } }, @{ n = 'OutFile'; e = { "$($OutDir)\$($_.BaseName).$($OutType)" } }
				$Pipe | Invoke-Graphviz | Out-Null
			}
		}
	}
}

Export-ModuleMember -Function HCPosh