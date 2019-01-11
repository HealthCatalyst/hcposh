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
function HCPosh {
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
	
    begin {
        # Get function definition files.
        $functions = @( Get-ChildItem -Path $PSScriptRoot\functions -Recurse -Filter *.ps1 -ErrorAction SilentlyContinue )

        # Dot source the files
        foreach ($import in @($functions)) {
            try {
                . $import.fullname
            }
            catch {
                Write-Error -Message "Failed to import function $($import.fullname): $_"
            }
        }
    }
    process {
        switch ($PsCmdlet.ParameterSetName) {
            'Version' {
                try {
                    "HCPosh v$((Get-Module HCPosh -ListAvailable)[0].Version -join '.')"
                    if (!$Version) {
                        Get-Help HCPosh
                    }
                }
                catch {
                    "HCPosh is running as an in-memory module"
                }
            }
            'SqlParser' {
                Invoke-SqlParser -Query $Query -Log $Log -SelectStar $SelectStar -Brackets $Brackets
            }
            'Data' {
                $Files = Get-ChildItem | Where-Object Extension -eq '.hcx'
				
                try {
                    if (($Files | Measure-Object).Count -eq 0) { throw; }
                }
                catch {
                    $Msg = "Unable to find any hcx files in current directory."; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
                }

                $Pipe = $Files | Select-Object @{ n = 'File'; e = { $_.FullName } }, @{ n = 'OutDir'; e = { "$($_.Directory)\_hcposh\$($_.BaseName)" } }
				
                if ($OutVar) {
                    if ($Raw) {
                        ($Pipe | Invoke-DataRaw | Select-Object RawData).RawData
                    }
                    else {
                        ($Pipe | Invoke-DataRaw | Invoke-Data | Select-Object Data).Data
                    }
                }
                else {
                    if ($Raw) {
                        $Pipe | Invoke-DataRaw | Out-Null
                    }
                    else {
                        $Pipe | Invoke-DataRaw | Invoke-Data | Out-Null
                    }
                }
            }
            'Docs' {
                if (!$OutDir) {
                    $OutDir = (Get-Location).Path + '\_hcposh_docs'
                }
                $DataArr = HCPosh -Data -OutVar -NoSplit | Where-Object { $_ };
                forEach ($Data in $DataArr) {
                    $NewOutDir = $OutDir + '\' + $Data._hcposh.FileBaseName
                    if ($OutZip) {
                        if ($OutVar) {
                            (Invoke-Docs -Data $Data -OutDir $NewOutDir -OutZip | Select-Object DocsData).DocsData
                        }
                        else {
                            Invoke-Docs -Data $Data -OutDir $NewOutDir -OutZip | Out-Null
                        }
                    }
                    else {
                        if ($OutVar) {
                            (Invoke-Docs -Data $Data -OutDir $NewOutDir | Select-Object DocsData).DocsData
                        }
                        else {
                            Invoke-Docs -Data $Data -OutDir $NewOutDir | Out-Null
                        }
                    }
                }
            }
            'Diagrams' {
                if (!$OutDir) {
                    $OutDir = (Get-Location).Path + '\_hcposh_diagrams'
                }
                if ($OutZip) {
                    $DataArr = HCPosh -Docs -OutVar -OutDir $OutDir -OutZip | Where-Object { $_ };
                }
                else {
                    $DataArr = HCPosh -Docs -OutVar -OutDir $OutDir | Where-Object { $_ };
                }
                forEach ($Data in $DataArr) {
                    $NewOutDir = $OutDir + '\' + $Data._hcposh.FileBaseName
                    if ($OutZip) {
                        Invoke-Diagrams -DocsData $Data -OutDir $NewOutDir -OutZip | Out-Null
                    }
                    else {
                        Invoke-Diagrams -DocsData $Data -OutDir $NewOutDir | Out-Null
                    }
                }
            }
            'Impact' {
                if ($ConfigPath -or $OutDir) {
                    if ($ConfigPath -and $OutDir) {
                        Invoke-ImpactAnalysis -Server $Server -ConfigPath $ConfigPath -OutDir $OutDir
                    }
                    elseif ($ConfigPath) {
                        Invoke-ImpactAnalysis -Server $Server -ConfigPath $ConfigPath
                    }
                    else {
                        Invoke-ImpactAnalysis -Server $Server -OutDir $OutDir
                    }
                }
                else {
                    Invoke-ImpactAnalysis -Server $Server
                }
            }
            'Graphviz' {
                if ($InputDir) {
                    $GvFiles = Get-ChildItem -Path $InputDir | Where-Object Extension -eq '.gv'
                }
                else {
                    $GvFiles = Get-ChildItem | Where-Object Extension -eq '.gv'
                }
				
                try {
                    if (($GvFiles | Measure-Object).Count -eq 0) { throw; }
                }
                catch {
                    $Msg = "Unable to find any gv files in current directory."; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
                }

                if (!$OutType) { $OutType = 'svg' }
                if (!$OutDir) {
                    if ($InputDir) {
                        $OutDir = $InputDir
                    }
                    else {
                        $OutDir = (Get-Location).Path
                    }
                }
                If (!(Test-Path $OutDir)) {
                    New-Item -ItemType Directory -Force -Path $OutDir -ErrorAction Stop | Out-Null
                }
                $Pipe = $GvFiles | Select-Object @{ n = 'File'; e = { $_.FullName } }, @{ n = 'OutType'; e = { $OutType } }, @{ n = 'OutFile'; e = { "$($OutDir)\$($_.BaseName).$($OutType)" } }
                $Pipe | Invoke-Graphviz | Out-Null
            }
        }
    }
}

Export-ModuleMember -Function HCPosh