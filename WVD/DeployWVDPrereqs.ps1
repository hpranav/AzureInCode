# Set variables 
$AADTenant="37973956-8359-476d-8fb2-3df7bf53262a"
$SubID="1e053fb6-3d57-4280-9785-0a5296932429"

$RGName="WVDDemo-RG1"
$ResourceLoc="East US"
$NSGName="WVDDemo-RG1-NSG"
$VNETName="WVDDemo-RG1-VNET"

# Connect to the subscription
Connect-AzAccount -Tenant $AADTenant -SubscriptionId $SubID

#Create new new ResourceGroup
New-AzResourceGroup -Name $RGName -Location $ResourceLoc


$rdpRule= New-AzNetworkSecurityRuleConfig -Name rdp-rule -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 200 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389
$networkSecurityGroup = New-AzNetworkSecurityGroup -ResourceGroupName $RGName -Location $ResourceLoc -Name $NSGName -SecurityRules $rdpRule
$servicesSubnet= New-AzVirtualNetworkSubnetConfig -Name servicesSubnet -AddressPrefix "192.168.0.0/23" -NetworkSecurityGroup $networkSecurityGroup
$WVDSubnet= New-AzVirtualNetworkSubnetConfig -Name WVDSubnet  -AddressPrefix "192.168.2.0/23" -NetworkSecurityGroup $networkSecurityGroup
$VNET = New-AzVirtualNetwork -Name $VNETName -ResourceGroupName $RGName -Location $ResourceLoc -AddressPrefix "192.168.0.0/22" -Subnet $frontendSubnet,$backendSubnet


# Create the VM
$VMLocalAdminUser = "msadmin"
$VMLocalAdminSecurePassword = ConvertTo-SecureString "P@ssw0rdda" -AsPlainText -Force
$ComputerName = "M365x940938-DC1"
$VMName = "M365x940938-DC1"
$VMSize = "Standard_D4as_v4"
$NICName = $ComputerName + "-NIC"


$Subnet = Get-AzVirtualNetwork -Name $VNETName -ResourceGroupName $RGName
$NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $RGName -Location $ResourceLoc -SubnetId $Subnet.Subnets[0].Id
#for a DC we need static IP
$NIC.IpConfigurations[0].PrivateIpAllocationMethod = "Static"


$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword)

$VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize
$VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
$VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2019-Datacenter' -Version latest

New-AzVM -ResourceGroupName $RGName -Location $ResourceLoc -VM $VirtualMachine -Verbose


