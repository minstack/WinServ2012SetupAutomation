Import-Module servermanager

$Global:sVars=@{}

## init dictionary with variables for server setup
## left hand side of the config.csv must be kept as-is for
## this script to work
Import-Csv c:\scripts\config.txt | 

ForEach {
    [string]$confLine=$_.ConfigVars

    $key,$val = $confLine.Split('=')

    $Global:sVars.Add($key,$val)
}

$objShell = New-Object -ComObject "WScript.Shell"
$objShortCut = $objShell.CreateShortcut($env:USERPROFILE + "\Start Menu\Programs\Startup" + "\InstallAdDc.lnk")
$objShortCut.TargetPath = "c:\scripts\bat\InstallAdDc.bat"
$objShortCut.Save()


Rename-Computer -NewName $Global:sVars['DCName']
Restart-Computer