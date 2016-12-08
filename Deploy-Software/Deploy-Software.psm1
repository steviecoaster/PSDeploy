Function Deploy-Software
{
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $false)]
		[switch]$Deploy,
		
		[parameter(Mandatory = $false)]
		[switch]$Inventory,
		
		[parameter(Mandatory = $true)]
		[string]$server
		
		
	)
	
	
#Enable verbose output
$VerbosePreference = "Continue"
	
	If ($Deploy)
	{
		#Grab the list of packages from the server into an array
		$PDQPackages = Invoke-Command -ComputerName $server { "SELECT Name from Packages;" | sqlite3.exe "C:\ProgramData\Admin Arsenal\PDQ Deploy\Database.db" } | Sort-Object
		#Empty placeholder
		$targets = ""
		#Empty array for the custom objects of Packages so I can show ID PackageName to the user.
		$Packages = @()
		#Starting ID number, since I don't care to pull it in with the query, this is easier.
		$i = 1
		#We need an array of items for deployment results. There has to be a more elegant way to do this, but I can't think of anything just yet.
		$deploytargets = @()
		
		#Loop through every package from the SQL Query and make a PSCustomObject and put it in the Packages Array.
		Foreach ($p in $PDQPackages)
		{
			
			$PackageObject = New-Object System.Object
			$PackageObject | Add-Member -Type NoteProperty -Name ID -Value $i
			$PackageObject | Add-Member -Type NoteProperty -Name Name -Value $p
			
			$Packages += $PackageObject
			#Increment the ID by 1
			$i++
		}
		
		#Show the ID and Package to the user for selection
		$Packages | Format-Table
		
		#Store the ID of the package they want to install
		$choice = Read-Host "Select Package ID"
		
		#Store the package object they want to a variable so I can use it against the PDQ Deploy server for Deployment
		$selectedpackage = $Packages | Where ID -EQ "$choice"
		
		#Ask the user what target they want to deploy too.
		$selectedtargets = (Read-Host "Enter Target Hostname(s) (comma separated)").Split(',')
		
		#Transform the targets so that they separate correctly into the Deploy -Targets parameter
		Foreach ($st in $selectedtargets)
		{
			
			$deploytargets += $st
			#Use a here-string to wrap quotes around each item, and add it to $target
			$targets += @" 
"$st" 
"@
			
		}
		
		$targets = $targets.Substring(0, $targets.Length - 1)
		
		#Start the deployment
		Write-Verbose -Message "Starting Deployment on targets: $targets"
		Invoke-Command -ComputerName $server -ScriptBlock { pdqdeploy deploy -Package $args[0] -Targets $args[1] } -ArgumentList $selectedpackage.Name, $targets
		
		#Give the remote processes time to start before we start looking for them. Noone likes a false positive.
		Start-Sleep -Seconds 10
		
		
		Foreach ($dt in $deploytargets)
		{
			#Get Deployment Result
			Do
			{
				$ProcessesFound = Invoke-Command $dt { Get-Process -ErrorAction Ignore | Where -Property Name -Match "PDQDeploy" } -ErrorAction Ignore
				If ($ProcessesFound)
				{
					
					Out-Null
				}
			}
			Until (!$ProcessesFound)
			
			
			#Grab the log from each target.
			$find = (Select-String -Path "\\$dt\ADMIN`$\AdminArsenal\PDQDeployRunner\Service.Log" -SimpleMatch "Got exit code:").Line
			
			
			#Grab the exit code, which is the last character of the line we grabbed above.
			$find = $find.Substring($find.Length - 1)
			
			#Display Success/Failure message based on code. 0 is Success, anything else is a failure.
			If ($find -eq "0")
			{
				
				$deployresult = Write-Output $("$dt" + ':' + ' ' + 'Deployment was successful!')
				
			}
			
			Else
			{
				
				
				$deployresult = Write-Output $("$dt" + ":" + ' ' + "Deployment failed! Check console logs")
				
			}
			
			#Show the user the deployment result. 
			Write-Output $deployresult
			
		}
	}
	
	elseif ($Inventory)
	{
		
		$app = Read-Host "Enter Application Name"
		$target = Read-Host "Enter target hostname"
		
		$UpperTarget = $target.ToUpper()
		$sql = "Select Applications.Name , Applications.Version FROM Applications WHERE  Applications.Name LIKE '%%$App%%' AND Applications.ComputerId = (SELECT Computers.ComputerId FROM Computers WHERE Computers.Name = '$UpperTarget');"
		$result = Invoke-Command -ComputerName $server -ScriptBlock { $args[0] | sqlite3.exe 'C:\ProgramData\Admin Arsenal\PDQ Inventory\Database.db' } -ArgumentList $sql
		
		Write-Output $result.Replace('|', ' ')
		
		
	}
}

Export-ModuleMember -Function Deploy-Software
