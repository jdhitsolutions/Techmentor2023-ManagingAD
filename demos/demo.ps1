return 'This is a demo script file.'

#region Install RSAT

# Add-WindowsCapability -name Rsat.ActiveDirectory* -online
Get-WindowsCapability -Name Rsat.ActiveDirectory* -Online

#endregion

#region Exploring the module

Import-Module ActiveDirectory
Get-Command -Module ActiveDirectory

#Install-Module PSScriptTools
Get-ModuleCommand ActiveDirectory | more

#READ THE HELP!!!

#endregion

#region Forest and Domain

Get-ADDomain
Get-ADDomain | Select-Object *master, PDC*
Get-ADForest

#run the functions from a domain member
psedit .\Get-FSMO.ps1
. .\Get-FSMO.ps1

Get-FSMORole
Get-FSMORole -role PDCEmulator, DomainNamingMaster

#endregion

#region AD Recycle Bin

Get-ADOptionalFeature -filter *

Help Enable-ADOptionalFeature
Enable-ADOptionalFeature  'Recycle Bin Feature' -Scope ForestOrConfigurationSet -Target 'company.pri' -Whatif

#endregion

#region User Management

#get a user
#ask for what you want
Get-ADUser ArtD
Get-ADUser ArtD -Properties Title, Department, Description

#discover
#can only use a wildcard like this:
Get-ADUser ArtD -Properties *

#find users with filters
Get-ADUser -Filter * -SearchBase "OU=Employees,DC=company,DC=pri" -Properties Department, City -ov a |
Group-Object -property Department

Get-ADUser -Filter "Department -eq 'IT'" |
Select-Object -Property DistinguishedName,Enabled

#create a user
psedit .\demo-usermgmt.ps1

#managing users at scale
psedit .\demo-reorg.ps1

#removing a user
Search-ADAccount -AccountDisabled -SearchBase "OU=Employees,DC=Company,DC=Pri" |
Remove-ADObject -WhatIf

#endregion
#region Group Management

#listing groups
Get-ADGroup -filter *

#Getting group membership
Get-ADGroupMember -Identity Sales

#creating a new group
New-ADGroup -Name DenverUsers -GroupCategory Security -GroupScope Global -Path "OU=Employees,DC=Company,DC=pri" -PassThru

#adding a user to a group
Add-ADGroupMember DenverUsers -members (Get-ADUser -filter "City -eq 'Denver'")
Get-ADGroupMember denverusers | Select name
#endregion
#region Find empty groups

#can't use -match in the filter
$paramHash = @{
    filter     = "Members -notlike '*'"
    Properties = 'Members', 'Created', 'Modified', 'ManagedBy'
    SearchBase = 'DC=company,DC=pri'
}

Get-ADGroup @paramHash |
Select-Object Name, Description,
@{Name = 'Location'; Expression = { $_.DistinguishedName.split(',', 2)[1] } },
Group*, Modified, ManagedBy |
Sort-Object Location |
Format-Table -GroupBy Location -Property Name, Description, Group*, Modified, ManagedBy

#filter out User and Builtin
#can't seem to filter on DistinguishedName
$paramHash = @{
    filter     = "Members -notlike '*'"
    Properties = 'Members', 'Modified', 'ManagedBy'
    SearchBase = 'DC=company,DC=pri'
}

#formatting to make this nice to read
Get-ADGroup @paramHash |
Where-Object { $_.DistinguishedName -notmatch 'CN=(Users)|(BuiltIn)' } |
Sort-Object -Property GroupCategory |
Format-Table -GroupBy GroupCategory -Property DistinguishedName, Name, Modified, ManagedBy

<#
This is the opposite. These are groups with any type of member.
The example is including builtin and default groups.
#>
$data = Get-ADGroup -Filter * -Properties Members, Created, Modified |
Select-Object Name, Description,
@{Name = 'Location'; Expression = { $_.DistinguishedName.split(',', 2)[1] } },
Group*, Created, Modified,
@{Name = 'MemberCount'; Expression = { $_.Members.count } } |
Sort-Object MemberCount -Descending

#sample
$data[0]

#I renamed properties from Group-Object to make the result easier to understand
$data | Group-Object MemberCount -NoElement |
Select-Object -Property @{Name = 'TotalNumberOfGroups'; Expression = { $_.count } },
@{Name = 'TotalNumberOfGroupMembers'; Expression = { $_.Name } }

<#
TotalNumberOfGroups TotalNumberOfGroupMembers
------------------- -------------------------
                1 8
                1 6
                1 5
                2 4
                6 3
                3 2
                9 1
                40 0
#>

#here's an alternate approach

Get-ADGroup -filter * | Select Name,@
{Name="MemberCount";Expression={(Get-ADGroupMember $_.DistinguishedName -Recursive).count}} |
Where Membercount -gt 0 | Sort MemberCount -descending | format-table -AutoSize

#endregion

#region Enumerate Nested Group Membership

#list all group members recursively
Get-ADGroupMember -Identity Sales -Recursive |
Select-Object DistinguishedName, samAccountName

#show nested groups
psedit .\Get-ADNested.ps1

. .\Get-ADNested.ps1

$group = 'Sales'
Get-ADNested $group | Select-Object Name, Level, ParentGroup,
@{Name = 'Top'; Expression = { $group } }

#endregion

#region List User Group Memberships

$user = Get-ADUser -Identity 'aprils' -Properties *

#this only shows direct membership
$user.MemberOf

psedit .\Get-ADMemberOf.ps1

. .\Get-ADMemberOf.ps1

$user | Get-ADMemberOf | Select-Object Name, DistinguishedName, GroupCategory -Unique

#endregion

#region Common Tasks

#region Find inactive user accounts

#this demo is only getting the first 25 accounts
$paramHash = @{
    AccountInactive = $True
    Timespan        = (New-TimeSpan -Days 120)
    SearchBase      = 'OU=Employees,DC=company,DC=pri'
    UsersOnly       = $True
    ResultSetSize   = '25'
}

Search-ADAccount @paramHash |
Select-Object Name, LastLogonDate, SamAccountName, DistinguishedName

#endregion

#region Find inactive computer accounts

#definitely look at help for this command
Search-ADAccount -ComputersOnly -AccountInactive

#endregion


#region Password Age Report

#get maximum password age.
#This doesn't take fine tuned password policies into account
$maxDays = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge.Days

#parameters for Get-ADUser
#get enabled accounts with passwords that can expire
$params = @{
    filter     = "Enabled -eq 'true' -AND PasswordNeverExpires -eq 'false'"
    Properties = 'PasswordLastSet', 'PasswordNeverExpires'
}

#skip user accounts under CN=Users and those with unexpired passwords
Get-ADUser @params |
Where-Object { (-Not $_.PasswordExpired) -and ($_.DistinguishedName -notmatch 'CN\=Users') } |
Select-Object DistinguishedName, Name, PasswordLastSet, PasswordNeverExpires,
@{Name = 'PasswordAge'; Expression = { (Get-Date) - $_.PasswordLastSet } },
@{Name = 'PassExpires'; Expression = { $_.passwordLastSet.addDays($maxDays) } } |
Sort-Object PasswordAge -Descending | Select-Object -First 10

#create an html report
psedit .\PasswordReport.ps1
# copy .\passwordreport.ps1 -destination \\win10\c$\scripts -passthru
c:\scripts\PasswordReport.ps1

# Invoke-item '\\win10\c$\users\artd\PasswordReport.html'
Invoke-Item .\PasswordReport.html

#get an OU
$params = @{
    SearchBase  = 'OU=Employees,DC=company,dc=pri'
    FilePath    = '.\employees.html'
    ReportTitle = 'Staff Password Report'
    Server      = 'DOM1'
    Verbose     = $True
}

.\PasswordReport.ps1 @params | Invoke-Item

#endregion
#use the AD PSDrive
Get-PSDrive AD
Get-ChildItem 'AD:\DC=Company,DC=Pri'

Get-ADOrganizationalUnit -Filter * | ForEach-Object {
    $ouPath = Join-Path -Path 'AD:\' -ChildPath $_.distinguishedName
    #test if the OU has any children other than OUs
    $test = Get-ChildItem -Path $ouPath -Recurse |
    Where-Object ObjectClass -NE 'OrganizationalUnit'
    if (-Not $Test) {
        $_.DistinguishedName
    }
}

#You could then decide to remove them,
#but beware of protection from accidental deletion
Set-ADOrganizationalUnit -Identity 'OU=Y2kResources,DC=Company,DC=pri' -ProtectedFromAccidentalDeletion $False -PassThru |
Remove-ADObject -WhatIf

#endregion

#region Domain Controller Health

Clear-Host

$dcs = (Get-ADDomain).ReplicaDirectoryServers

#services
#my domain controllers also run DNS
# the legacy way
# Get-Service adws,dns,ntds,kdc -ComputerName $dcs | Select-Object Machinename,Name,Status

$cim = @{
    ClassName    = 'Win32_Service'
    filter       = "name='adws' or name='dns' or name='ntds' or name='kdc'"
    ComputerName = $dcs
}
Get-CimInstance @cim | Select-Object SystemName, Name, State

#eventlog
Get-WinEvent -ListLog Active* -ComputerName DOM1
Get-WinEvent -FilterHashtable @{LogName = 'Active Directory Web Services';Level=2,3} -MaxEvents 10 -ComputerName DOM1

Get-WinEvent -FilterHashtable @{LogName = 'Active Directory Web Services';Level=2,3} -MaxEvents 10 -ComputerName DOM1


#how about a Pester-based health test?

psedit .\ADHealth.tests.ps1

Clear-Host

# copy .\ADHealth.tests.ps1 -Destination \\win10\c$\scripts -PassThru

invoke-pester C:\scripts\ADHealth.tests.ps1 -Show all -WarningAction SilentlyContinue

#You could automate running the test and taking action on failures

#endregion

#endregion
#region ADReportingTools

# https://github.com/jdhitsolutions/ADReportingTools
Install-Module ADReportingTools

Get-ADReportingTools

#get help: Open-ADReportingToolsHelp
Get-ADSummary
Show-DomainTree
Show-DomainTree -containers
Get-ADBranch "DC=Company,DC=pri"

#endregion
