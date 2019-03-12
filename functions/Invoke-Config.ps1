function Invoke-Config {
    [CmdletBinding()]
    param
    (
        [switch]$Force = $false,
        [string]$Json = '{"Docs":{"Include":{"ClassificationCode":["Summary","ReportingView","Generic"],"DatabaseNM":[],"SchemaNM":[],"TableNM":[],"IsPublic":["True"]},"Exclude":{"ClassificationCode":[],"DatabaseNM":[],"SchemaNM":[],"TableNM":[],"IsPublic":[]}}}'
    )
    process {
        $Msg = "Creating configuration file `"_hcposh.config`""; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg; #Write-Log $Msg;
        if ((Test-Path "_hcposh.config") -and !$Force) {
            $question = "The file `"_hcposh.config`" already exists in this directory, do you want to overwrite it? y/n";
            Write-Host "$(" " * 4)[WRN] " -ForegroundColor Yellow -NoNewline
            $answer = Read-Host $question;
            while ("y", "n" -notcontains $answer) {
                Write-Host "$(" " * 4)[WRN] " -ForegroundColor Yellow -NoNewline
                $answer = Read-Host $question
            }
            if ($answer -eq "y") {
                $Force = $true
                Write-Host "$(" " * 4)[INF] " -ForegroundColor Gray -NoNewline
                $Msg = "Overwriting existing file."; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; #Write-Log $Msg;
            }
            else {
                Write-Host "$(" " * 4)[INF] " -ForegroundColor Gray -NoNewline
                $Msg = "Exit."; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; #Write-Log $Msg;
                break;
            }
        }
        try {
            [Newtonsoft.Json.Linq.JObject]::Parse($Json).ToString() | Out-File "_hcposh.config" -Force;
            Write-Host "$(" " * 4)[INF] " -ForegroundColor Gray -NoNewline
            $Msg = "Created configuration file: $((Get-ChildItem "_hcposh.config").FullName)."; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; #Write-Log $Msg;
        }
        catch {
            Write-Host "$(" " * 4)[ERR] " -ForegroundColor Red -NoNewline
            $Msg = "Unable to validate `$Json as valid. $($Error[0])"; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; #Write-Log $Msg;
        }
        Write-Host "$(" " * 4)[INF] " -ForegroundColor Green -NoNewline
        $Msg = "Done."; Write-Host $Msg -ForegroundColor White; Write-Verbose $Msg; #Write-Log $Msg;
    }
}