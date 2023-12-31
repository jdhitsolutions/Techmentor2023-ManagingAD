#requires -version 5.1
#requires -module ActiveDirectory

<#
Get-ADMemberOf -identity gladysk | Select-Object -property DistinguishedName

DistinguishedNAme
-----------------
CN=JEA Operators,OU=JEA_Operators,DC=Company,DC=Pri
CN=Foo,OU=Employees,DC=Company,DC=Pri
CN=Master Dev,OU=Dev,DC=Company,DC=Pri
CN=IT,OU=IT,DC=Company,DC=Pri

#>
Function Get-ADMemberOf {
    [cmdletBinding()]
    [OutputType("Microsoft.ActiveDirectory.Management.ADGroup")]
    Param(
        [Parameter(
            Position = 0,
            Mandatory,
            HelpMessage = "Enter a user's SAMAccountName or DistinguishedName",
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [string]$Identity
    )

    Begin {
        Write-Verbose "Starting $($MyInvocation.MyCommand)"
        #define a function used for getting all the nested group information
        Function Get-GroupMemberOf {
            Param([string]$identity)

            #get each group and see what it belongs to
            $group = Get-ADGroup -Identity $Identity -Properties MemberOf
            #write the group to the pipeline
            $group

            #if there is MemberOf property, recursively call this function
            if ($group.MemberOf) {
                $group | Select-Object -ExpandProperty MemberOf |
                ForEach-Object {
                    Get-GroupMemberOf -identity $_
                }
            }
        } #end function
    } #close Begin

    Process {
        Write-Verbose "Getting all groups for user $identity"
        Get-ADUser -Identity $identity -Properties MemberOf |
        Select-Object -ExpandProperty MemberOf |
        ForEach-Object {
            Write-Verbose "Getting group member of $_"
            Get-GroupMemberOf -identity $_
        } #foreach
    } #close process

    End {
        Write-Verbose "Ending $($MyInvocation.MyCommand)"
    }
} #end function
