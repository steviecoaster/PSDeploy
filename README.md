# PSDeploy
Powershell console for PDQ Deploy

#Installing the Module

Download the zip file or clone this repo to your computer
Extract the Deploy-Software package to your PS Modules directory (C:\Program Files\WindowsPowershell\Modules\Deploy-Software works a treat!)

#Usage

Deploy-Software -Server [servername] -Deploy

Launches a menu based deployment system for pushing packages with PDQ Deploy's command-line interface.
Using the -Collection switch with -Deploy will enable you to select a Collection from Inventory to deploy too.

Deploy-Software -Server [servername] -Inventory

Launches a menu-based query for software versions on a target.
