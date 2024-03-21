$GroupDict = @{
    "AD Group Name" = "Application Display Name"
}

$Addresses = @{
    "City" = "Full Address" 
}

$AddressBlock = @"
   
"@

$menu = @"
    Information                      Actions
    -----------------------------------------------------------                     
    (1) Computer Name                (6) Unlock Account
    (2) User ID                      (7) Reset Password
    (3) Member Of List - User        (8) Add a group - User
    (4) Member Of List - Computer    (9) Add a group - Computer
    (5) Address

    ----------
    (0) Back
    (A) Quit
"@

function infoChoice 
{
    while ($true) 
    {
        Write-Host "`n`n`n`n`nSelected User: $($DisplayName)" -ForegroundColor black -BackgroundColor yellow
        Write-Host "Selected Device: $($SelectedComputer)" -ForegroundColor black -BackgroundColor yellow
        Write-Host "Locked Out: $($LockedOutStatus)`n" -ForegroundColor black -BackgroundColor yellow
        $menu
        $choice = Read-Host "`nEnter your Choice"
        
        switch ($choice) 
        {
            1 {ComputerName}
            2 {DisplayUserID}
            3 {GetUserMembers}
            4 {GetComputerMembers}
            5 {GetAddress}
            6 {UnlockAccount}
            7 {ResetPassword}
            8 {AddGroupUser}
            9 {AddGroupComputer}
            0 {Clear-Host; main}
            a {Clear-Host; exit}
            Default {"Out of range."}
        }
    }
}

function main 
{
        begin 
        {
            Clear-Host
            $global:currentUserFirstName = Get-ADUser -Identity $env:username | Select -ExpandProperty GivenName
            $currentUserLastName = Get-ADUser -Identity $env:username | Select -ExpandProperty Surname
            $global:currentUser = $currentUserFirstName, $currentUserLastName -join ' '
            $time = Get-Date -Format tt
            $global:TimePeriod
            $SelectedUser = $global:SelectedUser
            $count = 0
            $dict = @{}

            if ($time -eq "AM") 
            {
                $TimePeriod = "Morning"
            }
            elseif ($time -eq "PM") 
            {
                $TimePeriod = "Afternoon"
            }
        }

        process 
        {    while ($true) 
            {
                $userName = Read-Host "Enter display name"
                Write-Host `n 
        
                if ($userName -like '* *') 
                {
                    #If input contains a space, splits the input at the space and swaps first and last name
                    $First, $Last = $userName.split(' ')
                    $userName = "$($Last), $($First)"
                }

                $search = Get-ADUser -Filter "enabled -eq 'true' -and Name -like '*$userName*'" -Properties samAccountName | select -ExpandProperty Name
                $UserCount = ($search | Measure-Object).Count
                if ($UserCount -le 50)
                {
                    break
                }
                else 
                {
                    Write-Host "Try again.`n"
                }
            }
        
            if ($UserCount -gt 1) 
            {
                foreach ($name in $search) 
                {
                    $count++
                    Write-Host "$($count) - $($name)"
                    $dict.add($count, $name)
                }
            
                Write-Host `n 
                $input = Read-Host "Select"
            
                if ($input -le $UserCount) 
                {
                    $input = [int]$input
                    $SelectedUser = $dict.Get_Item($input)
                }
                else 
                {
                    Write-Host "Out of range. Try again.`n";main
                }
            }
            elseif ($UserCount -eq 0) 
            {
                Write-Host "No results found. Try again.`n";main
            }
            else 
            {
                $SelectedUser = $search
            }
        }

        end 
        {
            $LastName,$FirstName = $SelectedUser.split(' ')
            $global:FirstName
            $LastName = $LastName.replace(",", "")
            $global:DisplayName = $FirstName, $LastName -join " "
            $global:UserID = Get-ADUser -Filter 'Name -like $SelectedUser' -Properties samAccountName | select -ExpandProperty samAccountName
            $global:LockedOutStatus = Get-ADUser -Identity $UserID -Properties * | Select-Object -ExpandProperty LockedOut
            GetComputerName
            infoChoice
        }
    }

function AddGroup 
{
    while ($true) 
    {  
        $GroupSearch = Read-Host "Search for a group"
        $userGroupResults = Get-ADGroup -Filter "SamAccountName -like '*$GroupSearch*'" –Properties * | select-object -ExpandProperty sAMAccountName
        $userGroupDict = @{}
        $userGroupCount = ($userGroupResults | Measure-Object).Count
        $userGroupLoopCount = 0
        if ($userGroupCount -gt 100) 
        {
            Write-Host "Found more than 100 results. Please refine your search`n"
        }
        elseif ($userGroupCount -lt 100) 
        {
            if ($userGroupCount -gt 1) 
            {
                foreach ($userGroup in $userGroupResults) 
                {
                    $userGroupLoopCount++
                    Write-Host "$($userGroupLoopCount) - $($userGroup)"
                    $userGroupDict.add($userGroupLoopCount, $userGroup)
                }

                $input = Read-Host "Select"

                if ($input -le $userGroupCount) 
                {
                    $input = [int]$input
                    $SelectedGroup = $userGroupDict.Get_Item($input)
                }
                else 
                {
                    Write-Host "Out of range."
                }  
            }
            else 
            {
                $SelectedGroup = $userGroupResults
            }

            $OptionalDialogue = ""
            
            if ($SelectedGroup.EndsWith("SA") -or $SelectedGroup.EndsWith("UA")) 
            {
                $OptionalDialogue = "You will need to install this program from Software Centre."
            }
            if ($SelectedGroup.EndsWith("SR")) 
            {
                $OptionalDialogue = "This program will install automatically."
            }
            
            Write-Host "`nAdd $($DisplayUserOrComputer) to $($SelectedGroup)?"
            $Choice = Read-Host "Y/N"
            
            if ($Choice -eq "y") 
            {
                Add-ADGroupMember -Identity $SelectedGroup -Members $UserOrComputer
                Write-Host "`nAdded $($DisplayUserOrComputer) to $($SelectedGroup)."
                Set-Clipboard -Value "Added $($DisplayUserOrComputer) to $($SelectedGroup)."
                Write-Host "`nWorknote copied to clipboard.`n"
                Read-Host "Press enter to copy customer note"
                $GroupDisplayName = $GroupDict.Get_Item($SelectedGroup)
                $Greeting = "Good $($TimePeriod) $($FirstName),`n`nYou have now been given access to $($GroupDisplayName).`n$($OptionalDialogue) Please allow up to 30 minutes to sync.`n`nKind Regards,`n$($currentUser)"            
                Set-Clipboard -Value $Greeting
                Write-Host "`nCustomer note copied to clipboard."
                break
                
            }
            elseif ($Choice -eq "n") 
            {
                Write-Host "No change has been made."
                break
            }
        }
    }
}

function GetComputerName 
{ 
    #Gets list of devices from SCCM
    $global:devices = ""

    #Gets number of devices
    $global:ComputerCount = ($devices | Measure-Object).Count


    if ($ComputerCount -gt 1) 
    {
        Write-Host "Found multiple devices for this user:"
        $compcount = 0
        $compdict = @{} 
        foreach ($device in $devices) {
        $compcount++
        Write-Host "$($compcount) - $($device)"
        $compdict.add($compcount, $device)
    }
        
        Write-Host `n
        
        while ($true) 
        {
            $computerChoice = Read-Host "Select"
            $computerChoice = [int]$computerChoice

            if ($computerChoice -le $ComputerCount) 
            {
                $global:SelectedComputer = $compdict.Get_Item($computerChoice)
                $global:computerSearchable = $SelectedComputer, "$" -join '' 
                break
            }
            else 
            {
                Write-Host "Out of range.`n"
            }
        }
    }

    elseif ($ComputerCount -eq 1) 
    {
        $global:SelectedComputer = $devices
        $global:computerSearchable = $SelectedComputer, "$" -join ''
    }
    else
    {
        Write-Host "No computer found for this user."
        $global:SelectedComputer = "None"
    }
}

function ComputerName 
{
    if ($SelectedComputer -eq "None")
    {
        Write-Host "`nNo device selected."       
    }
    elseif ($SelectedComputer -ne "None")
    {
        Write-Host "Computer Name: $($SelectedComputer)" -ForegroundColor white -BackgroundColor black
        Set-Clipboard -Value $SelectedComputer
        Write-Host "`nCopied to clipboard"
    }
}

function DisplayUserID 
{
    Write-Host "User ID: $($UserID)" -ForegroundColor white -BackgroundColor black
    Set-Clipboard -Value $UserID
    Write-Host "`nCopied to clipboard"
}

function GetUserMembers 
{
    Write-Host "Finding member list for $($DisplayName)`n"
    $memberList = Get-ADPrincipalGroupMembership $UserID | Select-Object -ExpandProperty name
    
    foreach ($member in $memberList) 
    {
        Write-Host "$($member)" -ForegroundColor white -BackgroundColor black
    }
    
    Set-Clipboard -Value $memberList
    Write-Host "`nCopied to clipboard`n"
}
    
function GetComputerMembers 
{
    if ($SelectedComputer -eq "None")
    {
         Write-Host "`nNo device selected."       
    }
    elseif ($SelectedComputer -ne "None")
    {
        Write-Host "Finding member list for $($SelectedComputer)`n"
        $memberList = Get-ADPrincipalGroupMembership $computerSearchable | Select-Object -ExpandProperty name
        
        foreach ($member in $memberList) 
        {
            Write-Host "$($member)" -ForegroundColor white -BackgroundColor black
        }

        Set-Clipboard -Value $memberList
        Write-Host "`nCopied to clipboard"
    }
}

function UnlockAccount 
{
     Unlock-ADAccount -Identity $UserID
     Write-Host "$($DisplayName)'s account has now been unlocked."
}

function ResetPassword 
{
    Write-Host "Change password?"
    $ChangePasswordChoice = Read-Host "Y/N"
    
    if ($ChangePasswordChoice -eq "y") 
    {
        #Company specific password naming convention has been removed
        Set-ADAccountPassword -Identity $UserID -NewPassword (ConvertTo-SecureString -AsPlainText "PASSWORD" -Force)
        Set-Aduser -ChangePasswordAtLogon $true
        Write-Host "$($DisplayName)'s password has now been changed to PASSWORD"
    }
    elseif ($ChangePasswordChoice -eq "n") 
    {
        Write-Host "No change has been made."
    }
}

function AddGroupUser 
{
    $Global:DisplayUserOrComputer = $DisplayName
    $Global:UserOrComputer = $UserID
    AddGroup
}

function AddGroupComputer 
{
    if ($SelectedComputer -eq "None")
    {
         Write-Host "`nNo device selected."       
    }
    elseif ($SelectedComputer -ne "None")
    {
        $Global:DisplayUserOrComputer = $SelectedComputer
        $Global:UserOrComputer = $SelectedComputer, "$" -join ''
        AddGroup
    } 
}

function GetAddress
{
    $City = Get-ADUser -Identity $UserID -Properties office | Select-Object -ExpandProperty office 
    $Global:Address = $Addresses.Get_Item($City)
    $Address    
}

main
