return "This is a demo script file."

#parameters to splat to New-ADUser
$params = @{
    Name                  = 'Thomas Anderson'
    DisplayName           = 'Thomas (Neo) Anderson'
    SamAccountName        = 'tanderson'
    UserPrincipalName     = 'tanderson@company.com'
    PassThru              = $True
    GivenName             = 'Tom'
    Surname               = 'Anderson'
    Description           = 'the one'
    Title                 = 'Senior Web Developer'
    Department            = 'IT'
    Company               = 'Company.com'
    AccountPassword       = (ConvertTo-SecureString -String 'P@ssw0rd' -Force -AsPlainText)
    ChangePasswordAtLogon = $True
    Path                  = 'OU=IT,OU=Employees,DC=Company,DC=Pri'
    Enabled               = $True
}

#test if user account already exists
Function Test-ADUser {
    [cmdletbinding()]
    [OutputType('boolean')]
    Param(
        [Parameter(Position = 0, Mandatory, HelpMessage = "Enter a user's SamAccountName")]
        [ValidateNotNullOrEmpty()]
        [string]$Identity,
        [string]$Server,
        [PSCredential]$Credential
    )
    Try {
        [void](Get-ADUser @PSBoundParameters -ErrorAction Stop)
        $True
    }
    Catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        $False
    }
    Catch {
        Throw $_
    }
}

If (Test-ADUser $params.SamAccountName) {
    Write-Host "The user $($params.name) already exists" -ForegroundColor yellow

} else {
    Write-Host "Creating new user $($params.name)" -foreground cyan
    #splat the hashtable
    New-ADUser @params
}

#bulk import
#this must be run on a domain member
# copy .\100NewUsers.csv -Destination \\win10\c$\scripts -passthru

$csv = "C:\scripts\100NewUsers.csv"
Import-Csv $csv | Select-Object -First 1

#create OU if it doesn't exist
If (-Not (Test-Path 'AD:\OU=Imported,OU=Employees,DC=Company,DC=pri')) {
    $paramHash = @{
        Name                            = 'Imported'
        Path                            = 'OU=Employees,DC=Company,DC=pri'
        Description                     = 'Imported Test Accounts'
        ProtectedFromAccidentalDeletion = $False
    }

    New-ADOrganizationalUnit @paramHash
}

$secure = ConvertTo-SecureString -String 'P@ssw0rdXyZ' -AsPlainText -Force

#I'm not taking error handling for duplicate names into account
$newParams = @{
    ChangePasswordAtLogon = $True
    Path                  = 'OU=Imported,OU=Employees,DC=company,DC=pri'
    AccountPassword       = $secure
    Enabled               = $True
    PassThru              = $True
}

Import-Csv $csv | New-ADUser @newParams -WhatIf

#passwords
$new = ConvertTo-SecureString -String "NewP@ssw0rd" -AsPlainText -Force
Set-ADAccountPassword -Identity 'cbasu' -NewPassword $new -Reset -PassThru |
Set-ADUser -ChangePasswordAtLogon $True -PassThru

#do it at scale
Get-ADuser -filter * -SearchBase "OU=sales,OU=Employees,DC=Company,DC=pri" |
Set-AdAccountPassword -NewPassword $new -reset -PassThru |
Set-ADuser -ChangePasswordAtLogon $True -PasswordNeverExpires $False -PassThru |
Select-Object Name

#Enable/Disable
Set-ADUser -Identity sams -Enabled $False
Get-ADUser sams | Select Name,Enabled

