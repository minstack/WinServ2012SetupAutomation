function Create-BulkSiteLinks {
    param($CSVFile)

    Import-Csv $CSVFile |
    foreach {
        $site1,$site2 = [string]$_.Sites -split ","

        New-ADReplicationSiteLink $_.LinkName -SitesIncluded $site1,$site2 -Cost $_.Cost -ReplicationFrequencyInMinutes $_.ReplicationFreq -InterSiteTransportProtocol IP
    
    }

}