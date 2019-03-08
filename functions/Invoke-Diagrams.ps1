function Invoke-Diagrams {
    param
    (
        [Parameter(Mandatory = $True)]
        [psobject]$DocsData,
        [Parameter(Mandatory = $True)]
        [string]$OutDir,
        [switch]$OutZip
    )
    begin {
        $Filters = Get-EntityFilterLogic;
        $FilteredEntities = (Invoke-Expression $Filters.PowerShell);
        
        #Directories
        $DiagramsDir = "$($OutDir)"; New-Directory -Dir $DiagramsDir;
        $GvDir = "$($DiagramsDir)\gv"; New-Directory -Dir $GvDir;
    }
    process {
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
        forEach ($DocsPublic in $DocsData.Entities | Where-Object $FilteredEntities) {
            $PublicDFD_LR = $DocsPublic.Diagrams.Dfd.Graphviz.LR
            $PublicDFD_TB = $DocsPublic.Diagrams.Dfd.Graphviz.TB
            if ($PublicDFD_LR -and $PublicDFD_TB) {
                $PublicDFD_LR | Out-File -FilePath $($GvDir + "\DFD_$($DocsPublic.FullyQualifiedNames.Table)_LR.gv") -Encoding Default | Out-Null
                $PublicDFD_TB | Out-File -FilePath $($GvDir + "\DFD_$($DocsPublic.FullyQualifiedNames.Table)_TB.gv") -Encoding Default | Out-Null
            }
            
            $PublicDFD_LR_UPSTREAM = $DocsPublic.Diagrams.DfdUpstream.Graphviz.LR
            $PublicDFD_TB_UPSTREAM = $DocsPublic.Diagrams.DfdUpstream.Graphviz.TB
            if ($PublicDFD_LR_UPSTREAM -and $PublicDFD_TB_UPSTREAM) {
                $PublicDFD_LR_UPSTREAM | Out-File -FilePath $($GvDir + "\DFD_$($DocsPublic.FullyQualifiedNames.Table)_LR_Upstream.gv") -Encoding Default | Out-Null
                $PublicDFD_TB_UPSTREAM | Out-File -FilePath $($GvDir + "\DFD_$($DocsPublic.FullyQualifiedNames.Table)_TB_Upstream.gv") -Encoding Default | Out-Null
            }
            
            $PublicDFD_LR_DOWNSTREAM = $DocsPublic.Diagrams.DfdDownstream.Graphviz.LR
            $PublicDFD_TB_DOWNSTREAM = $DocsPublic.Diagrams.DfdDownstream.Graphviz.TB
            if ($PublicDFD_LR_DOWNSTREAM -and $PublicDFD_TB_DOWNSTREAM) {
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
        if ($OutZip) {
            try {
                Zip -Directory $DiagramsDir -Destination ($DiagramsDir + '_diagrams.zip')
                if (Test-Path $DiagramsDir) {
                    Remove-Item $DiagramsDir -Recurse -Force | Out-Null
                }
                $Msg = "$(" " * 4)Zipped file of directory --> $($DiagramsDir + '_diagrams.zip')"; Write-Host $Msg -ForegroundColor Cyan; Write-Verbose $Msg; Write-Log $Msg;
            }
            catch {
                $Msg = "$(" " * 4)Unable to zip the diagrams directory"; Write-Host $Msg -ForegroundColor Red; Write-Verbose $Msg; Write-Log $Msg 'error';
            }
        }						
    }
    end {
        $Msg = "Success!`r`n"; Write-Host $Msg -ForegroundColor Green; Write-Verbose $Msg; Write-Log $Msg;
    }
}