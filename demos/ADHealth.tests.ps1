#requires -version 5.1
#requires -Module ActiveDirectory, DNSClient,NetTCPIP

<#
Use Pester to test Active Directory

This test is designed for the Company.pri domain and should be run
from a domain member with domain admin credentials.

usage: Invoke-Pester ADHealth.tests.ps1
#>

#define a private helper function to test ports which supports a timeout
Function _testPort {
    [CmdletBinding()]
    [OutputType("boolean")]
    Param(
        [Parameter( Mandatory )]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName,

        [ValidateNotNullOrEmpty()]
        [int]$Port = 135,

        [int]$TimeOut = 1000
    )

    $TcpClient = [System.Net.Sockets.TcpClient]::new()
    Try {
        $async = $TcpClient.BeginConnect( $ComputerName, $port, $null, $null )
        $wait = $async.AsyncWaitHandle.WaitOne( $timeout, $false )
        If ($wait) {
            $True
        }
        else {
            $False
        }
    }
    Catch {
        [void]$TcpClient.EndConnect( $async )
        $false
    }
    Finally {
        $TcpClient.Close()
        $TcpClient.Dispose()
    }

}

BeforeAll {
    $MyDomain = Get-ADDomain
    $MyForest = Get-ADForest

    $DomainControllers = $MyDomain.ReplicaDirectoryServers

    Write-Host "[$(Get-Date)] Testing $($MyDomain.DistinguishedName)" -ForegroundColor DarkGreen -BackgroundColor Gray
    #$DomainControllers | Out-String | Write-Host -ForegroundColor yellow
}
Describe Active-Directory {

    Context 'Domain' {
        It 'Domain Admins should have 4 members' {
            (Get-ADGroupMember -Identity 'Domain Admins' | Measure-Object).Count | Should -Be 4
        }

        It 'Enterprise Admins should have 1 member' {
            (Get-ADGroupMember -Identity 'Enterprise Admins' | Measure-Object).Count | Should -Be 1
        }

        It 'The Administrator account should be enabled' {
            (Get-ADUser -Identity Administrator).Enabled | Should -Be $True
        }

        It 'The PDC emulator should be DOM1' {
            (Get-CimInstance -Class Win32_ComputerSystem -ComputerName DOM1).Roles -contains 'Primary_Domain_Controller' | Should -Be $True
        }
        It "The default Users container should be CN=Users,$($MyDomain.DistinguishedName)" {
            $MyDomain.usersContainer | Should -Be "CN=Users,$($MyDomain.DistinguishedName)"
        }

        It 'Should have 2 domain controllers' {
            $DomainControllers.Count | Should -Be 2
        }
    } #context

    Context 'Forest' {
        It 'The AD Forest functional level should be Window Server 2016' {
            $MyForest.ForestMode | Should -Be 'Windows2016Forest'
        }

        It 'Should have 1 site' {
            $MyForest.sites.count | Should -Be 1
        }
    } #context

} #describe AD

Describe DomainControllers {
    BeforeDiscovery {
        $GlobalCatalogServers = (Get-ADForest).GlobalCatalogs
        $script:DomainControllers = (Get-ADDomain).ReplicaDirectoryServers.Foreach({ @{Name = $_; IsGC = ($GlobalCatalogServers -contains $_) } })
        # $script:DomainControllers | Out-String | Write-Host
    }

    Context '<name>' -ForEach @($script:DomainControllers) {
        BeforeDiscovery {
            $script:PortTest = @(
                @{Port = 53; Open = $True }
                @{Port = 80; Open = $True }
                @{Port = 389; Open = $True }
                @{Port = 445; Open = $True }
                @{Port = 5985; Open = $True }
                @{Port = 9389; Open = $True }
                @{Port = 21; Open = $False }
                @{Port = 22; Open = $False }
            )
            if ($ISGc) {
                $script:PortTest += @{Port = 3268; Open = $True }
            }
        }

        Context Network {

            It 'Should respond to a ping' {
                Test-Connection -ComputerName $Name -Count 2 -Quiet | Should -Be $True
            }

            It 'Port <port> should be open is <Open>' -ForEach $script:PortTest {
                #(Test-NetConnection -Port $port -ComputerName $Name -WarningAction SilentlyContinue).TCPTestSucceeded | Should -Be $Open
                _testport -ComputerName $Name -Port $port | Should -Be $Open
            }

            #DNS name should resolve to same number of domain controllers
            It "should resolve the domain name $env:UserDNSDomain" {
            (Resolve-DnsName -Name $env:UserDNSDomain -DnsOnly -NoHostsFile | Measure-Object).Count | Should -Be $DomainControllers.count
            }
        }

        Context Disk {
            BeforeAll {
                $disk = Get-CimInstance -Class Win32_logicaldisk -Filter "DeviceID='c:'" -ComputerName $name
                $log = Get-CimInstance -Class win32_nteventlogfile -Filter "logfilename = 'security'" -ComputerName $name
            }
            It 'Should have at least 20% free space on C:' {
            ($disk.freespace / $disk.size) * 100 | Should -BeGreaterThan 20
            }
            It 'Should have at least 10% free space in Security log' {
            ($log.filesize / $log.maxfilesize) * 100 | Should -BeLessThan 90
            }
        } #disk
        Context Services {
            $services = 'ADWS', 'DNS', 'Netlogon', 'KDC'
            It '<_> service should be running' -ForEach $services {
            (Get-CimInstance -ClassName Win32_service -Filter "Name='$_'" -ComputerName $Name).State | Should -Be 'Running'
            }

        } #services
        Context Shares {
            $shares = 'Netlogon', 'SysVol'
            It 'Should have a share called <_>' -ForEach $shares {
                Test-Path "\\$Name\$_" | Should -Be $True
            }

            If ((Get-WindowsFeature -ComputerName $Name -Name AD-Certificate).installed) {
                It 'Should have a CertEnroll share' {
                    Test-Path "\\$Name\CertEnroll" | Should -Be $True
                }
            }
        } #shares
    }
}

