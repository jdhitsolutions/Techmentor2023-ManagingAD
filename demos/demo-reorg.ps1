#move users to a new OU, new department, new city, and manager
return "This is a demo script file."

#SF Benefits department moving to Oakland and changing name
$splat = @{
    Name        = 'Oakland'
    Description = 'Oakland Benefits'
    ManagedBy   = (Get-ADUser artd)
    Path        = 'OU=Employees,DC=Company,DC=pri'
    Passthru    = $True
}

New-ADOrganizationalUnit @splat

#get users
$users = Get-ADUser -Filter "Department -eq 'benefits' -AND City -eq 'San Francisco'" -Properties City, Department, Company
$users | Select-Object -Property DistinguishedName, Name, City, Department, Company

$users | Move-ADObject -TargetPath 'OU=Oakland,OU=Employees,DC=Company,DC=pri' -PassThru |
Set-ADUser -City Oakland -Department 'Associates Assistance' -Company 'Associated Benefits'

Get-ADUser -Filter * -SearchBase 'OU=Oakland,OU=Employees,DC=Company,DC=pri' -Properties City, Department, Company |
Select-Object -Property DistinguishedName, Name, Department, City, Company

<#
reset demo

 Get-ADuser -filter * -SearchBase "OU=Oakland,OU=Employees,DC=Company,DC=pri" |
Move-ADObject -TargetPath "OU=Accounting,OU=Employees,DC=Company,DC=pri" -PassThru |
Set-ADuser -City 'San Francisco' -Department "Benefits" -Company "Company.com"
Get-ADOrganizationalUnit -filter "Name -eq 'oakland'" |
Set-ADOrganizationalUnit -ProtectedFromAccidentalDeletion $False -PassThru |
Remove-ADObject -confirm:$False

#>
