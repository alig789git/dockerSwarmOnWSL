Param(
    [Parameter(HelpMessage ="InstallWSL")][Alias('IsInstallWSL')][bool] $installWSL=$false,
    [Parameter(HelpMessage ="CreateDistibution")][Alias('CreateDistibution')][bool] $createDistro=$true,
    [Parameter(HelpMessage ="DeployMaster")][Alias('IsDeployMaster')][bool] $deployMaster=$true,
    [Parameter(HelpMessage ="DeployNodes")][Alias('IsDeployNodes')][bool] $deployNodes = $true,
    [Parameter(Mandatory=$true,HelpMessage ="QuantityNodes")][Alias('QuantityNodes')][int] $node,
    [Parameter(HelpMessage ="WSLDeployPath")][Alias('WSLDeployPath')] $wslpath='C:\WSL'
)

#$installWSL = $false
#$createDistro = $true
#$wslpath = 'C:\WSL'
$wslpath_pref = '\distro'
$wslpath_full = $wslpath+$wslpath_pref
#$deployMaster=$true
#$deployNodes=$true
#$node = 2

###+++++++ Enable WSL and Install WSL2+++++++###
if($installWSL){
    $requieredFeautures = 'Microsoft-Windows-Subsystem-Linux','VirtualMachinePlatform'
    $match = 'State : Enabled'

    foreach ($feauture in $requieredFeautures){
        $test = dism.exe /online /Get-FeatureInfo /FeatureName:$feauture
    
        if($test -like "*$match*"){
            Write-Host "Feauture $feauture is enabled"
        }
        else{
            dism.exe /online /enable-feature /featurename:$feauture /all /norestart
        }
    }
    Invoke-WebRequest https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi -OutFile wsl_update_x64.msi
    ./wsl_update_x64.msi /quiet
    Remove-Item wsl_update_x64.msi
    wsl --set-default-version 2
    Write-Host "Default WSL version set: 2" -BackgroundColor Yellow -ForegroundColor Black
    
}
else{
    Write-Host 'Windows-Subsystem-Linux Installation is skipped...' -BackgroundColor Red -ForegroundColor Black
    
}
###+++++++ Create Distro +++++++###
if($createDistro){
    ###+++++++ Install Debian +++++++###

    wsl --install -d Debian

    Start-Sleep -Seconds 60

    wsl -d Debian -u root "./scripts/setDebianDistro.sh"

    Write-Host "Debian subsystem is installed" -BackgroundColor Yellow -ForegroundColor Black
    
    ###+++++++ Install Docker +++++++###

    wsl -d Debian -u root "./scripts/addDocker2Debian.sh"
    Write-Host "Docker is installed" -BackgroundColor Yellow -ForegroundColor Black

    ###+++++++ Export Debian +++++++###

    if (Test-Path -Path $wslpath){
        Remove-Item -Path $wslpath -Recurse -Force
    }
    Write-Host "All old disttibutions are removed" -BackgroundColor Yellow -ForegroundColor Black

    if(-not(Test-Path -Path $wslpath)){
        New-Item -Path $wslpath_full -ItemType 'directory'
    }
    Write-Host "New place for WSLSwarmCluster is $wslpath_full" -BackgroundColor Yellow -ForegroundColor Black

    wsl --export Debian $wslpath_full'\dockerondebian.tar'

    Write-Host "Distribution exports to $wslpath_full\dockerondebian.tar" -BackgroundColor Yellow -ForegroundColor Black

    wsl --unregister Debian

}
else{
    Write-Host 'Create Distribution is skipped...' -BackgroundColor Red -ForegroundColor Black
}

###+++++++Deploy Debian deb-master +++++++###

if($deployMaster){
    wsl --import deb-master $wslpath'\master\' $wslpath_full'\dockerondebian.tar'
    wsl -d deb-master -u root exit
    wsl -d deb-master -u root service --status-all
    Start-Sleep -Seconds 15
    [System.Collections.ArrayList]$swarm_token = wsl -d deb-master -u root "./scripts/swarmInit.sh"
    "#!/bin/bash`n"+$swarm_token[4].Trim()+"`n" | Out-File -FilePath '.\scripts\swarmJoin.sh' -Encoding utf8
    Write-Host 'Deploy Master deb-master is done...' -BackgroundColor Yellow -ForegroundColor Black
}
else{
    Write-Host 'Deploy Master is skipped...' -BackgroundColor Red -ForegroundColor Black
}

###+++++++Deploy Debian deb-nodes +++++++###

if($deployNodes){
    While($node -gt 0){
        $tstamp = Get-Date
        $tstamp = $tstamp.Ticks
        wsl --import deb-node-$tstamp $wslpath'\node-'$tstamp $wslpath_full'\dockerondebian.tar' 
        wsl -d deb-node-$tstamp -u root exit
        wsl -d deb-node-$tstamp -u root service --status-all
        Start-Sleep -Seconds 15
        wsl -d deb-node-$tstamp -u root "./scripts/swarmJoin.sh"
        Write-Host "Deploy Node deb-node-$tstamp is done..." -BackgroundColor Yellow -ForegroundColor Black
        $node--
    }
}
else{
    Write-Host 'Deploy Nodes is skipped...' -BackgroundColor Red -ForegroundColor Black
}