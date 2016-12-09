Function Deploy-Software
{
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $false)]
		[switch]$Deploy,
		
		[parameter(Mandatory = $false)]
		[switch]$Inventory,
        
        [parameter(Mandatory = $true)]
        [string]$Server,
               
        [parameter(Mandatory = $false)]
        [switch]$Collection
   	
		
		
	)
	
	
#Enable verbose output
$VerbosePreference = "Continue"
	
	If ($Deploy){
		#Grab the list of packages from the server into an array. We can't do Auto-Deploy packages unfortunately, so I'm stripping out any packages with that flag set.
		$PDQPackages = Invoke-Command -ComputerName $Server { "SELECT Packages.Name from Packages WHERE Packages.IsAutoDeploy IS NULL;" | sqlite3.exe "C:\ProgramData\Admin Arsenal\PDQ Deploy\Database.db" } | Sort-Object
		#Empty placeholder
		$targets = ""
		#Empty array for the custom objects of Packages so I can show ID PackageName to the user.
		$Packages = @()
        #Emtpy array for the custom objects of Collections so I can show ID CollectionName to the user.
        $Collections = @()
		#Starting Package ID number, since I don't care to pull it in with the query, this is easier.
		$pi = 1
        #Starting Collection ID number, since I don't care to pull it in with the query, this is easier.
        $ci = 1
		#We need an array of items for deployment results. There has to be a more elegant way to do this, but I can't think of anything just yet.
		$deploytargets = @()

      If($Collection){

        #Pull the names of the collections from the database.
        $listofcollections = Invoke-Command -ComputerName $Server -ScriptBlock { "SELECT Name from Collections;" | sqlite3.exe "C:\ProgramData\Admin Arsenal\PDQ Inventory\Database.db" } | Sort-Object
                Foreach ($l in $listofcollections){
			
			        $CollectionObject = New-Object System.Object
			        $CollectionObject | Add-Member -Type NoteProperty -Name ID -Value $ci
			        $CollectionObject | Add-Member -Type NoteProperty -Name Name -Value $l
			
			        $Collections += $CollectionObject
			        #Increment the ID by 1
			        $ci++
		    }
        
        #Show the ID and Collection name to the user for selection
        $Collections | Format-Table

        #Ask user which collection to Deploy too.
        $cchoice = Read-Host "Enter Collection Name"
        
        #Store the ID of the Collection they want to use
        $selectedcollection = $Collections | Where ID -EQ "$cchoice"

        #Grab the names of the computers in the selected collection. This will be an array
        $collectiontargets = Invoke-Command -ComputerName $Server -ScriptBlock {pdqinventory GetCollectionComputers $args[0] } -ArgumentList $selectedcollection.Name

        Foreach ($ct in $collectiontargets)
		{
			
			$deploytargets += $ct
			#Use a here-string to wrap quotes around each item, and add it to $target
			$targets += @" 
"$ct" 
"@
			
		}
		
		$targets = $targets.Substring(0, $targets.Length - 1)
}		
		#Loop through every package from the SQL Query and make a PSCustomObject and put it in the Packages Array.
		Foreach ($p in $PDQPackages)
		{
			
			$PackageObject = New-Object System.Object
			$PackageObject | Add-Member -Type NoteProperty -Name ID -Value $pi
			$PackageObject | Add-Member -Type NoteProperty -Name Name -Value $p
			
			$Packages += $PackageObject
			#Increment the ID by 1
			$pi++
		}
		
		#Show the ID and Package to the user for selection
		$Packages | Format-Table
		
		#Store the ID of the package they want to install
		$pchoice = Read-Host "Select Package ID"
		
		#Store the package object they want to a variable so I can use it against the PDQ Deploy server for Deployment
		$selectedpackage = $Packages | Where ID -EQ "$pchoice"
		

     If(!$Collection){
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
            
        }
       
        
        
        
        #If the target is a collection, get those machines.
  
		
		#Start the deployment
		Write-Verbose -Message "Starting Deployment on targets: $targets"
		Invoke-Command -ComputerName $Server -ScriptBlock { pdqdeploy deploy -Package $args[0] -Targets $args[1] } -ArgumentList $selectedpackage.Name, $targets
		
		#Give the remote processes time to start before we start looking for them. Noone likes a false positive.
		Start-Sleep -Seconds 45
#############################################################################################################################################################################		
	                                                            #SHOW RESULTS#
#############################################################################################################################################################################	
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

    }
    
    Write-Verbose "All deployment processes ended, starting to show results"	


$DB = "C:\ProgramData\Admin Arsenal\PDQ Deploy\Database.db"
$SuccessSQL = "Select DeploymentComputers.DeploymentId, DeploymentComputers.ShortName , DeploymentComputerSteps.IsFailed  From DeploymentComputers JOIN DeploymentComputerSteps on DeploymentComputers.DeploymentComputerId = DeploymentComputerSteps.DeploymentComputerId where DeploymentComputers.Deploymentid = (SELECT MAX(DeploymentComputers.Deploymentid) FROM DeploymentComputers);"
$complete = Invoke-Command -ComputerName $Server -Scriptblock { $SuccessSQL | sqlite3.exe $db }

Foreach($c in $complete){

$cname = (($c.Substring($c.IndexOf("|"))).Replace('|',''))

$deployobject = New-Object System.Object
$deployobject | Add-Member -Type NoteProperty -Name DeploymentID -Value $c.SubString(0,5)
$deployobject | Add-Member -Type NoteProperty -Name Name -Value $cname.SubString(0, $cname.Length - 1)
$deployobject | Add-Member -type NoteProperty -Name DeployStatus -Value $c[-1]

#Make the status code human readable.
If($deployobject.DeployStatus -eq "0"){
    
    $return = "Successful!"
    }

    Else{
     $return = "Failed!"
    }

Write-Verbose "Returning successful deployment targets"
Write-Output "$deployobject.Name deployment $return"
}


			
}
#############################################################################################################################################################################
                                                             #END SHOW RESULTS#
#############################################################################################################################################################################
	}
	
	elseif ($Inventory)
	{
		
		$app = Read-Host "Enter Application Name"
		$target = Read-Host "Enter target hostname"
		
		$UpperTarget = $target.ToUpper()
		$sql = "Select Applications.Name , Applications.Version FROM Applications WHERE  Applications.Name LIKE '%%$App%%' AND Applications.ComputerId = (SELECT Computers.ComputerId FROM Computers WHERE Computers.Name = '$UpperTarget');"
		$result = Invoke-Command -ComputerName $Server -ScriptBlock { $args[0] | sqlite3.exe 'C:\ProgramData\Admin Arsenal\PDQ Inventory\Database.db' } -ArgumentList $sql
		
		Write-Output $result.Replace('|', ' ')
		
		
	}


Export-ModuleMember -Function Deploy-Software