#Clear-AzContext
#Connect-AzAccount

$Sdate=get-date
Write-Host -ForegroundColor Green "Installation started on $Sdate"

###   Create new resource group, location and Subnet and VNET for User001   ### 
$rgUserName="Task-X-User001"
$locUserName="westeurope"
$VnetTaskUser=$rgUserName+"-Vnet"
New-AZResourceGroup -Name $rgUserName -Location $locUserName
$virtualNetwork = New-AzVirtualNetwork -ResourceGroupName $rgUserName -Location $locUserName -Name $VnetTaskUser -AddressPrefix 192.168.0.0/16
$subnetConfig = Add-AzVirtualNetworkSubnetConfig -Name default -AddressPrefix 192.168.0.0/24 -VirtualNetwork $virtualNetwork
$virtualNetwork | Set-AzVirtualNetwork

$Sdate=get-date
Write-Host -ForegroundColor Green "Installation started on $Sdate"

###   Create new resource group, location and Subnet and VNET for User002   ### 
$rgUserName="Task-X-User002"
$locUserName="westeurope"
$VnetTaskUser=$rgUserName+"-Vnet"
New-AZResourceGroup -Name $rgUserName -Location $locUserName
$virtualNetwork = New-AzVirtualNetwork -ResourceGroupName $rgUserName -Location $locUserName -Name $VnetTaskUser -AddressPrefix 128.17.0.0/16
$subnetConfig = Add-AzVirtualNetworkSubnetConfig -Name default -AddressPrefix 128.17.0.0/24 -VirtualNetwork $virtualNetwork
$virtualNetwork | Set-AzVirtualNetwork

$Sdate=get-date
Write-Host -ForegroundColor Green "Installation for RG-UserXXX Ended on $Sdate"




$Sdate=get-date
Write-Host -ForegroundColor Green "Installation started on $Sdate"

###   Create your new resource group and location   ### 
$rgName="ProjectX"
$locName="westeurope"
$locName=$location
New-AZResourceGroup -Name $rgName -Location $locName


###   Create user object - same user and password for all VMs   ###

$user = "wsadmin"
$password = "Password123456"
$secureStringPwd = $password | ConvertTo-SecureString -AsPlainText -Force 
$cred = New-Object System.Management.Automation.PSCredential -ArgumentList $user, $secureStringPwd

#####################################


$BaseCIDR = "10.1.0.0/24" #This would change for each network
$IPSplit = $BaseCIDR.Split(".")
$First2Octet = "$($IPSplit[0]).$($IPSplit[1])"
#$3rdOctet = [int]$IPSplit[2]


###   Create DNS Zone   ###
$zone = New-AzPrivateDnsZone -ResourceGroupName $rgname -Name "privatelink.azurewebsites.net"
$DNSconfig = New-AzPrivateDnsZoneConfig -Name "privatelink.azurewebsites.net" -PrivateDnsZoneId $zone.ResourceId


$i=1
1..2 | ForEach-Object {

###   Parameters   ###

$subuser00X="$First2Octet.$i.0"
$subname="Subnet-User00$i"
$VNetNameX="VNET-User00$i"
$SGUserName="NSG-User00$i"
$VmnameX="User00$i-VM"
$NICVMUSERX="NICVM-User00$i"
$VMOSDrive="VMOS-User00$i"
$StorageACCT="stgacctuser00$i"
$PrivEndPoint="PrivateEndPoint-User00$i"
$PrivDNSVnetLink="PrivDNSLink-User00$i"
$DNSZoneGRP="DNSZGRP-User00$i"
$LinkSVCCon="LinkSVCconn-User00$i"
Write-Host $subuser00X
Write-Host $subname



###   Create the Security group Network that will host the 2 Subnet2 subnet and protect it with a network security group   ###
$Sdate=get-date
Write-Host -ForegroundColor Green "Network Security Groups creation started on on $Sdate"
$rule1 = New-AZNetworkSecurityRuleConfig -Name "RDPTraffic" -Description "Allow RDP to all VMs on the subnet" -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389
$rule2 = New-AZNetworkSecurityRuleConfig -Name "WebTraffic" -Description "Allow HTTPS to the Exchange server" -Access Allow -Protocol Tcp -Direction Inbound -Priority 101 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix "$subuser00X" -DestinationPortRange 443
$NSG10=New-AZNetworkSecurityGroup -Name $SGUserName -ResourceGroupName $rgName -Location $locName -SecurityRules $rule1, $rule2

###   Create virtual network 1 (10Subnet)   ###
$Sdate=get-date
Write-Host -ForegroundColor Green "Virtual Netowrks creation started on on $Sdate"
$Addprefix=$subuser00X+"/24"
$subnet10Config = New-AZVirtualNetworkSubnetConfig -Name $subname -AddressPrefix $Addprefix -NetworkSecurityGroup $NSG10
$UserNET = New-AzVirtualNetwork -ResourceGroupName $rgName -Name $VNetNameX -AddressPrefix $Addprefix -Location $locName -Subnet $subnet10Config


###   Create Storage Private Endpoint   ###
New-AzStorageAccount -ResourceGroupName $rgName -AccountName $StorageACCT -Location $locName -SkuName Standard_GRS
$StorageAccount = Get-AzStorageAccount -ResourceGroupName $rgName -Name $StorageACCT
$privateEndpointConn = New-AzPrivateLinkServiceConnection -Name $LinkSVCCon -PrivateLinkServiceId $StorageAccount.Id -GroupId "blob"
$vnetnm = Get-AzVirtualNetwork -ResourceGroupName $rgname -Name $VNetNameX
## Disable private endpoint network policy ##
$vnetnm.Subnets[0].PrivateEndpointNetworkPolicies = "Disabled"
$vnetnm | Set-AzVirtualNetwork
$privateEndpoint = New-AzPrivateEndpoint -ResourceGroupName $rgName -Name $PrivEndPoint -Location $locName -Subnet $vnetnm.Subnets[0] -PrivateLinkServiceConnection $privateEndpointConn

###   Create DNS configuration for Storage Endpoint   ###
$link = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $rgname -ZoneName "privatelink.azurewebsites.net" -Name $PrivDNSVnetLink -VirtualNetworkId $vnetnm.id
$PrivZneGRP = New-AzPrivateDnsZoneGroup -ResourceGroupName $rgname -PrivateEndpointName $PrivEndPoint -Name $DNSZoneGRP -PrivateDnsZoneConfig $DNSconfig



$networkInterface = Get-AzResource -ResourceId $privateEndpoint.NetworkInterfaces[0].Id -ApiVersion “2019-04-01”

foreach ($ipconfig in $networkInterface.properties.ipConfigurations) {
foreach ($fqdn in $ipconfig.properties.privateLinkConnectionProperties.fqdns) {
Write-Host “$($ipconfig.properties.privateIPAddress) $($fqdn)”
$recordName = $fqdn.split(‘.’,2)[0]
#$dnsZone = $fqdn.split(‘.’,2)[1]
New-AzPrivateDnsRecordSet -Name $recordName -RecordType A -ZoneName “privatelink.azurewebsites.net” `
-ResourceGroupName $rgname -Ttl 600 `
-PrivateDnsRecords (New-AzPrivateDnsRecordConfig -IPv4Address $ipconfig.properties.privateIPAddress)
}
}

$imagid = (Get-AzGalleryImageDefinition -ResourceGroupName DevOps -GalleryName DevOpsSIGname -Name win10avd).id

###   Create the virtual machine   ###
$Sdate=get-date

Write-Host -ForegroundColor Green "$VmnameX Installation started on $Sdate"
$pubipuserX = New-AZPublicIpAddress -Name $NICVMUSERX -ResourceGroupName $rgName -Location $locName -AllocationMethod Static
$nicVM = New-AZNetworkInterface -Name $NICVMUSERX -ResourceGroupName $rgName -Location $locName -SubnetId $UserNET.Subnets[0].Id -PublicIpAddressId $pubipuserX.Id
$VMNEW=New-AZVMConfig -VMName $VmnameX -VMSize Standard_D2as_v5
$VMNEW=Set-AZVMOSDisk -VM $VMNEW -Name $VMOSDrive -DiskSizeInGB 128 -CreateOption FromImage -StorageAccountType "Standard_LRS"
$VMNEW=Set-AZVMOperatingSystem -VM $VMNEW -Windows -ComputerName $VmnameX -Credential $cred -ProvisionVMAgent -EnableAutoUpdate
#$VMNEW=Set-AZVMSourceImage -VM $VMNEW -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2016-Datacenter  -Version "latest"
$VMNEW=Set-AZVMSourceImage -VM $VMNEW -Id $imagid
$VMNEW=Add-AZVMNetworkInterface -VM $VMNEW -Id $nicVM.Id
New-AZVM -ResourceGroupName $rgName -Location $locName -VM $VMNEW
$Sdate=get-date
Write-Host -ForegroundColor Magenta "$VmnameX Installation ended on $Sdate"
#####################################

$CurrentUser="User00$i"
$Vnet2peer=(Get-AzResourceGroup Task-X-$CurrentUser | Get-AzVirtualNetwork)
# Peer VNet1 to VNet2.
Add-AzVirtualNetworkPeering -Name 'LinkVnet1ToVnet2' -VirtualNetwork  $UserNET -RemoteVirtualNetworkId $Vnet2peer.id

# Peer VNet2 to VNet1.
Add-AzVirtualNetworkPeering -Name 'LinkVnet2ToVnet1' -VirtualNetwork $Vnet2peer -RemoteVirtualNetworkId $UserNET.Id

$i=$i+1
}
$Sdate=get-date
Write-Host -ForegroundColor Green "Installation completed on on $Sdate"