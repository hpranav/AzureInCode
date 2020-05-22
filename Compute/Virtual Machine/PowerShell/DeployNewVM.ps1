# Set variables 
$AADTenant="37973956-8359-476d-8fb2-3df7bf53262a"
$SubID="1e053fb6-3d57-4280-9785-0a5296932429"

$RGName="WVDDemo-RG1"
$ResourceLoc="East US"
$VNETName="WVDDemo-RG1-VNET"

# Connect to the subscription
Connect-AzAccount -Tenant $AADTenant -SubscriptionId $SubID


# Create the VM
$VMLocalAdminUser = "msadmin"
$VMLocalAdminSecurePassword = ConvertTo-SecureString "P@ssw0rdda" -AsPlainText -Force
$ComputerName = "SCCM-Primary1"
$VMName = "SCCM-Primary1"
$VMSize = "Standard_D4as_v4"
$NICName = $ComputerName + "-NIC"


$Subnet = Get-AzVirtualNetwork -Name $VNETName -ResourceGroupName $RGName
$NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $RGName -Location $ResourceLoc -SubnetId $Subnet.Subnets[0].Id



$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword)

$VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize
$VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
$VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2019-Datacenter' -Version latest

New-AzVM -ResourceGroupName $RGName -Location $ResourceLoc -VM $VirtualMachine -Verbose