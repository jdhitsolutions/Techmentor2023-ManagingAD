Function Get-FSMORole {
    [cmdletbinding()]
    [OutputType("fsmoInfo")]
    Param(
        [Parameter(
            Position = 0,
            HelpMessage = 'Specify a FSMO role or select ALL to display all roles.'
        )]
        [ValidateSet('All', 'PDCEmulator', 'RIDMaster', 'InfrastructureMaster', 'SchemaMaster', 'DomainNamingMaster')]
        [string[]]$Role = 'All',

        [Parameter(HelpMessage = 'Specify the distinguished name of a domain')]
        [ValidateNotNullOrEmpty()]
        [string]$Domain = (Get-ADDomain).DistinguishedName
    )

    Try {
        $ADDomain = Get-ADDomain -Identity $Domain -ErrorAction Stop
        $ADForest = $ADDomain | Get-ADForest -ErrorAction Stop
    }
    Catch {
        Throw $_
    }

    if ($ADDomain -AND $ADForest) {
        $fsmo = [PSCustomObject]@{
            PSTypeName           = 'fsmoInfo'
            Domain               = $ADDomain.Name
            Forest               = $ADForest.Name
            PDCEmulator          = $ADDomain.PDCEmulator
            RIDMaster            = $ADDomain.RIDMaster
            InfrastructureMaster = $ADdomain.InfrastructureMaster
            SchemaMaster         = $ADForest.SchemaMaster
            DomainNamingMaster   = $ADForest.DomainNamingMaster
        }
        if ($Role -eq 'All') {
            $fsmo
        }
        else {
            $fsmo | Select-Object -Property $Role
        }
    }
} #end Get-FSMORole