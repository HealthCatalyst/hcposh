function Get-EntityFilterCriteria {
    begin {        
        $ConfigPath = "_hcposh.config"
        $Filters = New-Object PSObject -Property @{
            PowerShell = "{ (@('Summary','ReportingView','Generic') -contains `$_.ClassificationCode) -and (@('True') -contains `$_.IsPublic) }";
            JavaScript = @{"Include" = (("ClassificationCode", ("Summary", "ReportingView", "Generic")), ("IsPublic", (, $true)))};
        };
    }
    process {

        if (Test-Path $ConfigPath) {
            $Config = Get-Content $ConfigPath | ConvertFrom-Json;
            
            ## Docs filtering
            if (($Config.Docs.PSobject.Properties | Where-Object {$_.Name -match "Include|Exclude"} | Measure-Object).Count) {
                $Filters = New-Object PSObject -Property @{PowerShell = @(); JavaScript = @{}; };
                $ConfigDocsInclude = $Config.Docs.Include
                foreach ($Filter in $ConfigDocsInclude.PSobject.Properties) {
                    $FilterValues = $ConfigDocsInclude."$($Filter.Name)";
                    if ($FilterValues) {
                        for ($i = 0; $i -lt $FilterValues.Length; $i++) {
                            if ($FilterValues[$i] -match "True|False") {
                                $FilterValues[$i] = [System.Convert]::ToBoolean($FilterValues[$i])
                            }
                        }
                        $Filters.PowerShell += "(@(`'$($FilterValues -join("','"))`')$($Filter."$($Filter.Name)") -contains `$_.$($Filter.Name))";
                        $Filters.JavaScript["Include"] += @(, @($Filter.Name, $FilterValues));
                    }        
                }
                $ConfigDocsExclude = $Config.Docs.Exclude
                foreach ($Filter in $ConfigDocsExclude.PSobject.Properties) {
                    $FilterValues = $ConfigDocsExclude."$($Filter.Name)";
                    if ($FilterValues) {
                        for ($i = 0; $i -lt $FilterValues.Length; $i++) {
                            if ($FilterValues[$i] -match "True|False") {
                                $FilterValues[$i] = [System.Convert]::ToBoolean($FilterValues[$i])
                            }
                        }
                        $Filters.PowerShell += "(@(`'$($FilterValues -join("','"))`')$($Filter."$($Filter.Name)") -notcontains `$_.$($Filter.Name))";
                        $Filters.JavaScript["Exclude"] += @(, @($Filter.Name, $FilterValues));
                    }        
                }
                if ($Filters.PowerShell) {
                    $Filters.PowerShell = "{ $($Filters.PowerShell -join(" -and ")) }";
                }
                else {
                    $Filters.PowerShell = "{ `$_ }";
                }
            }
        }
        return $Filters;
    }
}