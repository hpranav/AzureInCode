# Set variables 
$AADTenant="72f988bf-86f1-41af-91ab-2d7cd011db47"
$SubID="357ff2c9-cb3d-41f5-a7f1-de3764b3b8c5"

$RGName="FirewallTesting-RG1"
$ResourceLoc="Australia East"
$NSGName="FWTesting-RG1-NSG"
$VNETName="FWTesting-RG1-VNET"

# Connect to the subscription
Connect-AzAccount -Tenant $AADTenant -SubscriptionId $SubID

#Create new new ResourceGroup
New-AzResourceGroup -Name $RGName -Location $ResourceLoc


#Adding a NSG rule to enable RDP port, add more rules as needed
$rdpRule= New-AzNetworkSecurityRuleConfig -Name rdp-rule -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 200 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389

#Create the NSG
$networkSecurityGroup = New-AzNetworkSecurityGroup -ResourceGroupName $RGName -Location $ResourceLoc -Name $NSGName -SecurityRules $rdpRule

#Create Subnets
$servicesSubnet= New-AzVirtualNetworkSubnetConfig -Name servicesSubnet -AddressPrefix "192.168.0.0/23" -NetworkSecurityGroup $networkSecurityGroup
$FWSubnet= New-AzVirtualNetworkSubnetConfig -Name AzureFirewallSubnet  -AddressPrefix "192.168.2.0/23"

# Create the VNET
$VNET = New-AzVirtualNetwork -Name $VNETName -ResourceGroupName $RGName -Location $ResourceLoc -AddressPrefix "192.168.0.0/22" -Subnet $servicesSubnet,$FWSubnet


#Deploy Azure FW
# Get a Public IP for the firewall
$FWpip = New-AzPublicIpAddress -Name "fw-pip" -ResourceGroupName $RGName -Location $ResourceLoc -AllocationMethod Static -Sku Standard
$pip = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name "fw-pip"

# Create the firewall
$Azfw = New-AzFirewall -Name Test-FW01 -ResourceGroupName $RGName -Location $ResourceLoc -VirtualNetwork $VNET -PublicIpAddress @($pip)

#Save the firewall private IP address for future use
$AzfwPrivateIP = $Azfw.IpConfigurations.privateipaddress

#Create a route table and assign it to services subnet where your functions/VMs will reside
$routeTableDG = New-AzRouteTable -Name Firewall-rt-table -ResourceGroupName $RGName -location $ResourceLoc -DisableBgpRoutePropagation

#Create a route
Add-AzRouteConfig -Name "DG-Route" -RouteTable $routeTableDG -AddressPrefix 0.0.0.0/0 -NextHopType "VirtualAppliance" -NextHopIpAddress $AzfwPrivateIP | Set-AzRouteTable

#Associate the route table to the subnet
Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $VNET -Name servicesSubnet -AddressPrefix 192.168.0.0/23 -RouteTable $routeTableDG | Set-AzVirtualNetwork



# Create the function
# Your Code 

# Create a VM and assign it to services Subnet
$VMLocalAdminUser = "msadmin"
$VMLocalAdminSecurePassword = ConvertTo-SecureString "P@ssw0rddcba" -AsPlainText -Force
$ComputerName = "FirewallTestVM"
$VMName = "FirewallTestVM"
$VMSize = "Standard_D4s_v3"
$NICName = $ComputerName + "-NIC"

# Get a Public IP for the VM
$VMpip = New-AzPublicIpAddress -Name "VM-pip" -ResourceGroupName $RGName -Location $ResourceLoc -AllocationMethod Static -Sku Standard
$VMpipAddress = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name "VM-pip"

$Subnet = Get-AzVirtualNetwork -Name $VNETName -ResourceGroupName $RGName
$NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $RGName -Location $ResourceLoc -SubnetId $Subnet.Subnets[0].Id -PublicIpAddressId $VMpip.Id


$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword)

$VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize
$VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
$VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2019-Datacenter' -Version latest

New-AzVM -ResourceGroupName $RGName -Location $ResourceLoc -VM $VirtualMachine -Verbose 


