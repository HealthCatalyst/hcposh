function Get-EntityFilterLogic {
    begin {
    
        $ConfigPath = "_hcposh.config"
        $Filters = New-Object PSObject -Property @{
            PowerShell = "{ (@('Summary','ReportingView','Generic') -contains `$_.ClassificationCode) -and (@('True') -contains `$_.IsPublic) }";
            JavaScript = ".filter(entity => (entity.ClassificationCode === 'Summary' || entity.ClassificationCode === 'ReportingView' || entity.ClassificationCode === 'Generic') && (entity.IsPublic === true))";
        };
    }
    process {

        if (Test-Path $ConfigPath) {
            $Config = Get-Content $ConfigPath | ConvertFrom-Json;
            
            ## Docs filtering
            if (($Config.Docs.PSobject.Properties | Where-Object {$_.Name -match "Include|Exclude"} | Measure-Object).Count) {
                $Filters = New-Object PSObject -Property @{PowerShell = @(); JavaScript = @(); };
                $ConfigDocsInclude = $Config.Docs.Include
                foreach ($Filter in $ConfigDocsInclude.PSobject.Properties) {
                    $FilterValues = $ConfigDocsInclude."$($Filter.Name)";
                    if ($FilterValues) {
                        $Filters.PowerShell += "(@(`'$($FilterValues -join("','"))`')$($Filter."$($Filter.Name)") -contains `$_.$($Filter.Name))";
                        $Filters.JavaScript += "(entity.$($Filter.Name) === `'$($FilterValues -join("' || entity.$($Filter.Name) === '"))`')";
                    }        
                }
                $ConfigDocsExclude = $Config.Docs.Exclude
                foreach ($Filter in $ConfigDocsExclude.PSobject.Properties) {
                    $FilterValues = $ConfigDocsExclude."$($Filter.Name)";
                    if ($FilterValues) {
                        $Filters.PowerShell += "(@(`'$($FilterValues -join("','"))`')$($Filter."$($Filter.Name)") -notcontains `$_.$($Filter.Name))";
                        $Filters.JavaScript += "(entity.$($Filter.Name) !== `'$($FilterValues -join("' || entity.$($Filter.Name) === '"))`')";
                    }        
                }
                if ($Filters.PowerShell) {
                    $Filters.PowerShell = "{ $($Filters.PowerShell -join(" -and ")) }";
                    $Filters.JavaScript = ".filter(entity => $($Filters.JavaScript -join(" && ")))"
                    $Filters.JavaScript = [Regex]::Replace($Filters.JavaScript, [regex]::Escape("== 'true'"), "== true", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase);
                    $Filters.JavaScript = [Regex]::Replace($Filters.JavaScript, [regex]::Escape("== 'false'"), "== false", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase);
                }
                else {
                    $Filters.PowerShell = "{ `$_ }";
                    $Filters.JavaScript = "";
                }
            }
        }
        return $Filters;
    }
}