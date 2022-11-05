#
# Elevate To Admin For Modifying in Default Location
#
if (!
    # current role
    (New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    # is admin?
    )).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
) {
    # elevate script and exit current non-elevated runtime
    Start-Process `
        -FilePath 'powershell' `
        -ArgumentList (
            # flatten to single array
            '-File', $MyInvocation.MyCommand.Source, $args `
            | %{ $_ }
        ) `
        -Verb RunAs
    exit
}


# Default Installation Location
$RsLocation = 'C:\Program Files (x86)\Rockwell Software\RSLogix 500 English\'
$RsName = 'Rs500.exe'


# Should Be byte Sequence in Version 12.00.00 and 10.00.00
# Dont Know About Others
[byte[]]$SearchParam = 255,37,255,0,0,0,133,192,116,20,198,69,252,2,141,141


# Test Default Install Path And If found Ask To Continue
Function Test-Location(){
    Clear-Host

    # Test If Mod Already Exists
    If (Test-Path $RsLocation'Rs500_mod.exe'){
        $Continue = Read-Host -Prompt 'Rs500_mod.exe Found! Remove?(y)'
        If ($Continue.Contains('y')){
           Remove-Item $RsLocation'Rs500_mod.exe'
           If (Test-Path $RsLocation'Rs500_mod.exe'){
                Read-Host -Prompt 'Delete Failed. Press Enter To Exit'
           } else {
                Write-Host 'Rs500_mod.exe Removed Successfully.'
                Read-Host -Prompt 'Press Enter To Exit'
           }
        } else {
            Read-Host -Prompt 'Modification Already Exists. Press Enter To Exit'
        }
        exit
    }

    # Test If Location Is Correct
    If (Test-Path $RsLocation$RsName){
        $Continue = Read-Host -Prompt 'Rs500.exe Found! Backup And Continue?(y)'
        
        If ($Continue.Contains('y')){
            If (Test-Path $RsLocation$RsName'.psbak'){
                $overite = Read-Host -Prompt 'Backup Already Exists! Overite?(y)'
                If ($overite.Contains('y')){
                    Write-Host 'Backup Overite Selected...'
                    Copy-Item $RsLocation$RsName -Destination $RsLocation$RsName'.psbak'
                    Test-Backup
                }
            } Else{
                Copy-Item $RsLocation$RsName -Destination $RsLocation$RsName'.psbak'
                Test-Backup
            }
            Read-To-Byte
        } else {
            exit
        }
    } 

    # If Not Found Ask For New Location
    else {
        Write-Host 'Rs500.exe Not Found In The Default Install Location'
        $sel = Read-Host -Prompt 'Select New Location?(y)'
        If ($sel.Contains('y')){
        Add-Type -AssemblyName System.Windows.Forms
        $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ InitialDirectory = [Environment]::GetFolderPath('Desktop')
                                                                                   Filter = 'Executables (*.exe)|*.exe'
                                                                                   Title = 'Select Rs500.exe'
                                                                                 }
        $null = $FileBrowser.ShowDialog()
        
        # Overite Default Param
        $RsLocation = $FileBrowser.FileName.Replace($FileBrowser.SafeFileName,'')

        # Recurse Restart With New Params
        Test-Location
        } else {
        Read-Host -Prompt 'Modification Aborted Press Enter To Exit'
        exit
        }
    }
}


# Test If Backup Succeeded
Function Test-Backup(){
    If (Test-Path $RsLocation$RsName'.psbak') {
        $BackupComplete = $True
        Write-Host 'Backup Done!'
    } 
    else {
        Read-Host -Prompt "Backup Failed. Press Enter To Close"
        Exit
    }
}


# Read The EXE to $bytes
Function Read-To-Byte(){
    Write-Host 'Reading Rs500.exe...'
    $FileBytes  = [System.IO.File]::ReadAllBytes($RsLocation+$RsName)
    Write-Host 'Done!'
    Find-Offset
}

# Finds Offset Location Of The Search Parameter In The EXE File
Function Find-Offset(){
    Write-Host 'Searching Rs500.exe For Modability...'
    $ByteOffset = Find-Bytes $FileBytes $SearchParam
    If ([string]::IsNullOrEmpty($ByteOffset)){
        Write-Host 'Rs500.exe Version Is Not Currently Supported'
        Read-Host -Prompt "Please Let Me Know Your Version Number. Press Enter To Close"
        exit
    }
    else {
        $Continue = Read-Host -Prompt 'Rs500.exe Version Is Supported Continue?(y)'
        If ($Continue.Contains('y')){
            Modify-Bytes
        } else {
           exit
        }
    }
}

# Modifies The Byte Array
Function Modify-Bytes(){
    Write-Host 'Modifying Byte Code...'
    $FileBytes[$ByteOffset+8] = 144
    $FileBytes[$ByteOffset+9] = 144
    Write-Host 'Bytes Modified!'
    Save-Modification
}

# Saves The Byte Array To New EXE
Function Save-Modification(){
    Write-Host 'Saving Modification under Rs500_mod.exe...'
    
    [System.IO.File]::WriteAllBytes($RsLocation+"Rs500_mod.exe", $FileBytes)

    If (Test-Path $RsLocation'Rs500_mod.exe'){
        Write-Host 'Rs500_mod.exe Save Completed!'
    } 

    Exit-Message
}

# Exit Messge
Function Exit-Message(){
    Write-Host '..........'
    Write-Host 'If no Errors Are Showing... Enjoy!'
    Read-Host -Prompt 'Press Enter To Close'
}


# Find Bytes In Byte Array
Function Find-Bytes([byte[]]$Bytes, [byte[]]$Search, [int]$Start, [Switch]$All) {
    For ($Index = $Start; $Index -le $Bytes.Length - $Search.Length ; $Index++) {
        For ($i = 0; $i -lt $Search.Length -and $Bytes[$Index + $i] -eq $Search[$i]; $i++) {}
        If ($i -ge $Search.Length) { 
            $Index
            If (!$All) { Return }
        } 
    }
}


# Program Start
Test-Location