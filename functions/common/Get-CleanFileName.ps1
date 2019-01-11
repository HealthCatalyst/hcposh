function Get-CleanFileName {
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
    
    Begin {
        #Get an array of invalid characters 
        $arrInvalidChars = [System.IO.Path]::GetInvalidFileNameChars()
        
        #Cast into a string. This will include the space character 
        $invalidCharsWithSpace = [RegEx]::Escape([String]$arrInvalidChars)
        
        #Join into a string. This will not include the space character 
        $invalidCharsNoSpace = [RegEx]::Escape(-join $arrInvalidChars)
        
        #Check that the Replacement does not have invalid characters itself 
        if ($RemoveSpace) {
            if ($Replacement -match "[$invalidCharsWithSpace]") {
                Write-Error "The replacement string also contains invalid filename characters."; exit
            }
        }
        else {
            if ($Replacement -match "[$invalidCharsNoSpace]") {
                Write-Error "The replacement string also contains invalid filename characters."; exit
            }
        }
        
        Function Remove-Chars($String) {
            #Test if any charcters should just be removed first instead of replaced. 
            if ($RemoveOnly) {
                $String = Remove-ExemptCharsFromReplacement -String $String
            }
            
            #Replace the invalid characters with a blank string(removal) or the replacement value 
            #Perform replacement based on whether spaces are desired or not 
            if ($RemoveSpace) {
                [RegEx]::Replace($String, "[$invalidCharsWithSpace]", $Replacement)
            }
            else {
                [RegEx]::Replace($String, "[$invalidCharsNoSpace]", $Replacement)
            }
        }
        
        Function Remove-ExemptCharsFromReplacement($String) {
            #Remove the characters in RemoveOnly first before returning to the potential replacement 
            
            #Test that the entries are invalid filename characters, and are able to be converted to chars 
            $RemoveOnly = [RegEx]::Escape( -join $(foreach ($entry in $RemoveOnly) {
                        #Try to cast to an int in case a valid integer as a string is passed. 
                        try { $entry = [int]$entry }
                        catch {
                            #Silently ignore if it fails.  
                        }
                        
                        try { $char = [char]$entry }
                        catch { Write-Error "The entry `"$entry`" in RemoveOnly cannot be converted to a type of System.Char. Make sure the entry is either an integer or a one character string."; exit }
                        
                        if ($arrInvalidChars -contains $char -or $char -eq [char]32) {
                            #Honor the RemoveSpace parameter 
                            if (!$RemoveSpace -and $char -eq [char]32) {
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
    
    Process {
        foreach ($n in $Name) {
            #Check if the string matches a valid path 
            if ($n -match '(?<start>^[a-zA-z]:\\|^\\\\)(?<path>(?:[^\\]+\\)+)(?<file>[^\\]+)$') {
                #Split the path into separate directories 
                $path = $Matches.path -split '\\'
                
                #This will remove any empty elements after the split, eg. double slashes "\\" 
                $path = $path | Where-Object { $_ }
                #Add the filename to the array 
                $path += $Matches.file
                
                #Send each part of the path, except the start, to the removal function 
                $cleanPaths = foreach ($p in $path) {
                    Remove-Chars -String $p
                }
                #Remove any blank elements left after removal. 
                $cleanPaths = $cleanPaths | Where-Object { $_ }
                
                #Combine the path together again 
                $Matches.start + ($cleanPaths -join '\')
            }
            else {
                #String is not a path, so send immediately to the removal function 
                Remove-Chars -String $n
            }
        }
    }
}