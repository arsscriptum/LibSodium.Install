
function Get-GitCommandPath{
    $GitCmd = Get-Command 'git.exe'
    if($GitCmd -ne $Null){
        return $GitCmd.Source
    }
}


Function Set-EnvironmentVariable{
    [CmdletBinding(SupportsShouldProcess)]
        param(
        [parameter(mandatory=$true, Position=0)]
        [String]$Name,
        [parameter(mandatory=$true, Position=1)]
        [String]$Value,
        [parameter(mandatory=$false)]
        [ValidateSet('User', 'Machine', 'Session', 'UserSession')]
        [String]$Scope='UserSession'
        )
    switch($Scope.ToLower())
    {
        { 'session','usersession' -eq $_ } 
        { 
            $CurrentSetting=( Get-ChildItem -Path env: -Recurse | % -process { if($_.Name -eq $Name) {$_.Value} })
         
            if(($CurrentSetting -eq $null) -Or ($CurrentSetting -ne $null -And $CurrentSetting.Value -ne $Value)){
                Write-Verbose "Environment Setting $Name is not set or has a different value, changing to $Value"
                $TempPSDrive = $(get-date -Format "temp\hhh-\mmmm-\sss")
                new-psdrive -name $TempPSDrive -PsProvider Environment -Root env:| Out-null
                $NewValPath=( "$TempPSDrive" + ":\$Name")
                Remove-Item -Path $NewValPath -Force -ErrorAction Ignore | Out-null
                New-Item -Path $NewValPath -Value $Value -Force -ErrorAction Ignore | Out-null
                Remove-PSDrive $TempPSDrive -Force | Out-null
            }
        }
        { 'user','usersession' -eq $_ } 
        { 
            Write-Verbose "Setting $Name --> $Value [User]"
            [System.Environment]::SetEnvironmentVariable($Name,$Value,[System.EnvironmentVariableTarget]::User)
        }
        { 'machine' -eq $_ }
        {  
            Write-Verbose "Setting $Name --> $Value [Machine]"
            [System.Environment]::SetEnvironmentVariable($Name,$Value,[System.EnvironmentVariableTarget]::Machine)
        }
    }
    Publish-RegistryChanges
}


function Install-LibSodium
{
<#
    .SYNOPSIS
            Cmdlet to find in files (grep)
    .DESCRIPTION
            Cmdlet to find in files (grep)
    .PARAMETER Path

#>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$false)]
        [string]$VcPkgPath="$ENV:Temp\VcPkg"
    ) 
    
    $ThisScriptRoot = "$PSScriptRoot"
    if(!(Test-Path -Path "$VcPkgPath")){
        New-Item -Path "$VcPkgPath" -ItemType directory -Force -ErrorAction Ignore | Out-Null
    }
    Push-Location "$VcPkgPath"
    $GitExe = Get-GitCommandPath
    &"$GitExe" 'clone' 'https://github.com/Microsoft/vcpkg.git' 'tmpvcpkg'
    Push-Location "tmpvcpkg"

    $VcPkgRootPath = Join-Path "$VcPkgPath" "tmpvcpkg"

    $BootStrap = (get-item 'bootstrap-vcpkg.bat').Fullname
    
    &"$BootStrap"
    $VcpkgExe = (get-item 'vcpkg.exe').Fullname
    &"$VcpkgExe" 'integrate' 'install'

    &"$VcpkgExe" 'install' 'libsodium'
    &"$VcpkgExe" 'install' 'libsodium' '--triplet' 'x64-windows'


    $VcPkgPackagesPath = Join-Path "$VcPkgRootPath" "packages"
    $LibSodiumX86Path = Join-Path "$VcPkgPackagesPath" "libsodium_x86-windows"
    $LibSodiumX64Path = Join-Path "$VcPkgPackagesPath" "libsodium_x64-windows"

    if(!(Test-Path -Path "$LibSodiumX86Path")){
        throw "missing x86 path"
    }

    if(!(Test-Path -Path "$LibSodiumX64Path")){
        throw "missing x64 path"
    }

    Set-EnvironmentVariable -Name "LIBSODIUM_X86_PATH" -Value "$LibSodiumX86Path" -Scope Session
    Set-EnvironmentVariable -Name "LIBSODIUM_X86_PATH" -Value "$LibSodiumX86Path" -Scope User

    Set-EnvironmentVariable -Name "LIBSODIUM_X64_PATH" -Value "$LibSodiumX64Path" -Scope Session
    Set-EnvironmentVariable -Name "LIBSODIUM_X64_PATH" -Value "$LibSodiumX64Path" -Scope User

    $PropsFile = "$ThisScriptRoot\templates\libsodium_template.props"
    $Content = Get-Content -Path $PropsFile -Raw
    $NewContent = $Content.Replace("__libsodium_x86_windows_path__","$LibSodiumX86Path").Replace("__libsodium_x64_windows_path__","$LibSodiumX64Path")
    Set-Content "$ThisScriptRoot\libsodium.props" -Value "$NewContent"
    Pop-Location
    Pop-Location
    Push-Location  "$ThisScriptRoot"
    Write-Host "DONE!"

    Write-Host "Include the props files `"$ThisScriptRoot\libsodium.props`" i your project and your gold."
}


