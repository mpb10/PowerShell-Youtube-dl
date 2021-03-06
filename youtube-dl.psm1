<#
.SYNOPSIS 
	A collection of commandlets used to support the PowerShell-Youtube-dl script.
	
.DESCRIPTION 
	This PowerShell module is used to support the PowerShell-Youtube-dl.

.EXAMPLE 
	Import-Module -Force ".\youtube-dl.psm1"
	    Imports the module and allows all of the commandlets to be called elsewhere.
	
.NOTES 
	Requires Windows 7 or higher and PowerShell 5.0 or greater
	Author: mpb10
	Updated: April 27th 2021
	Version: 3.0.4

.LINK 
	https://github.com/mpb10/PowerShell-Youtube-dl
#>



# Function for simulating the 'pause' command of the Windows command line.
function Wait-Script {
    param(
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'If true, do not wait for user input.')]
        [switch]
        $NonInteractive = $false,
        
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Number of seconds to wait.')]
        [int]
        $Seconds = 0
    )

    # Wait for a specified number of seconds.
    Start-Sleep -Seconds $Seconds

    # If the '-NonInteractive' parameter is false, wait for the user to press a key before continuing.
    if ($NonInteractive -eq $false) {
		Write-Host "Press any key to continue ...`n" -ForegroundColor "Gray"
	    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp") | Out-Null
	}
} # End Wait-Script function



# Function for writing messages to a log file.
function Write-Log {
    param (
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'The message to output to the log.')]
        [string]
        $Message,

        [Parameter(
            Mandatory = $true,
            HelpMessage = 'The severity level of the message to log.')]
        [ValidateSet('Info','Warning','Error','Prompt')]
        [string]
        $Severity,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Location of the log file.')]
        [string]
        $FilePath = "$(Get-Location)\powershell-youtube-dl.log",

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Whether to output to the console in addition to the log file.')]
        [switch]
        $Console = $false,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Whether to output only to the console.')]
        [switch]
        $ConsoleOnly = $false
    )

    # Set the severity level formatting based on the user input.
    $SeverityLevel = switch ($Severity) {
        'Info' { 'INFO:   '; break }
        'Warning' { 'WARNING:'; break }
        'Error' { 'ERROR:  '; break }
        'Prompt' { 'PROMPT: '; break }
        default { 'INFO:   '; break }
    }

    # Return the user provided value if the $Severity is 'Prompt'
    if ($Severity -eq 'Prompt') {
        return (Read-Host "$(Get-Date -Format 's') $SeverityLevel $Message").Trim()
    }

    # If the '-Console' parameter is true, tee the output to both the console and log file.
    # If the '-ConsoleOnly' parameter is true, only write the output to the console.
    # Otherwise, only save the output to the log file.
    if ($Console) {
        Tee-Object -Append -FilePath $FilePath -InputObject "$(Get-Date -Format 's') $SeverityLevel $Message"
    }
    elseif ($ConsoleOnly) {
        Write-Host "$(Get-Date -Format 's') $SeverityLevel $Message"
    }
    else {
        Out-File -Append -FilePath $FilePath -InputObject "$(Get-Date -Format 's') $SeverityLevel $Message"
    }
} # End Write-Log function



# Function for creating shortcuts.
function New-Shortcut {
    param (
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'The full path of the shortcut to create.')]
        [string]
        $Path = "$(Get-Location)\newshortcut.lnk",

        [Parameter(
            Mandatory = $true,
            HelpMessage = 'The target path of the shortcut.')]
        [string]
        $TargetPath,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Arguments to pass to the target path when the shortcut is ran.')]
        [string]
        $Arguments,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'The directory from which to run the target path.')]
        [string]
        $StartPath,
        
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Path to the file used as the icon.')]
        [string]
        $IconPath
    )

    $FullTargetPath = Resolve-Path -Path $TargetPath

    # Create the WScript.Shell object, assign it a file path, target path, and other optional settings.
    $WScriptShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WScriptShell.CreateShortcut($Path)
    $Shortcut.TargetPath = $FullTargetPath.Path
    if ($Arguments) {
        $Shortcut.Arguments = $Arguments
    }
    if ($StartPath) {
        $Shortcut.WorkingDirectory = $StartPath
    }
    if ($IconPath) {
        $Shortcut.IconLocation = $IconPath
    }
    $Shortcut.Save()
} # End New-Shortcut function



# Function for downloading files from the internet.
function Get-Download {
    param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'Web URL of the file to download.')]
        [string]
        $Url,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'The full path of where to download the file to.')]
        [string]
        $Path = "$(Get-Location)\downloadfile"
    )

    # Check if the provided '-Path' parameter is a valid file path.
    if (Test-Path -Path $Path -PathType 'Container') {
        return Write-Log -ConsoleOnly -Severity 'Error' -Message "Provided download path cannot be a directory."
    }
    else {
        $TempFile = "$(Split-Path -Path $Path -Parent)\download.tmp"
    }

    # Download the file to a temporary file.
    (New-Object System.Net.WebClient).DownloadFile("$Url", $TempFile)

    # Rename and move the downloaded temporary file to its permanent location.
    if (Test-Path -Path $TempFile) {
        Move-Item -Path $TempFile -Destination $Path -Force
        Write-Log -ConsoleOnly -Severity 'Info' -Message "Downloaded file to '$Path'."
    }
    else {
        return Write-Log -ConsoleOnly -Severity 'Error' -Message "Failed to download file to '$Path'"
    }

    # Remove the temporary file if it still exists.
    if (Test-Path -Path $TempFile) {
        Remove-Item -Path $TempFile
    }
} # End Get-Download function



# Function for downloading the youtube-dl.exe executable file.
function Get-YoutubeDl {
    param(
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Download youtube-dl.exe to this directory.')]
        [string]
        $Path = (Get-Location)
    )

    $Path = Resolve-Path -Path $Path

    # Check if the provided '-Path' parameter is a valid directory.
    if ((Test-Path -Path $Path -PathType 'Container') -eq $false) {
        return Write-Log -ConsoleOnly -Severity 'Error' -Message 'Provided download path either does not exist or is not a directory.'
    }
    else {
        $TempFile = "$Path\youtube-dl.exe"
    }

    # Use the 'Get-Download' function to download the youtube-dl.exe executable file.
    Get-Download -Url 'http://yt-dl.org/downloads/latest/youtube-dl.exe' -Path $TempFile
    if (Test-Path -Path "$Path\youtube-dl.exe") {
        Write-Log -ConsoleOnly -Severity 'Info' -Message "Finished downloading the youtube-dl executable."
    }
    else {
        return Write-Log -ConsoleOnly -Severity 'Error' -Message "Failed to download the youtube-dl executable."
    }
} # End Get-YoutubeDl function



# Function for downloading the ffmpeg executable files.
function Get-Ffmpeg {
    param (
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Download ffmpeg to this directory.')]
        [string]
        $Path = (Get-Location)
    )

    $Path = Resolve-Path -Path $Path

    # Check if the provided '-Path' parameter is a valid directory.
    if (Test-Path -Path $Path -PathType 'Container') {
        $TempFile = "$Path\ffmpeg-download.zip"
    }
    else {
        return Write-Log -ConsoleOnly -Severity 'Error' -Message 'Provided download path either does not exist or is not a directory.'
    }

    # Download the ffmpeg zip file.
    Get-Download -Url 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' -Path $TempFile
    if (-Not (Test-Path -Path $TempFile)) {
        return Write-Log -ConsoleOnly -Severity 'Error' -Message "Failed to download the ffmpeg executables."
    }

    # Extract the ffmpeg executable files from the downloaded zip file.
    Expand-Archive -Path $TempFile -DestinationPath $Path
    Copy-Item -Path "$Path\ffmpeg-*\bin\*" -Destination $Path -Filter "*.exe" -Force
    Remove-Item -Path $TempFile, "$Path\ffmpeg-*" -Recurse
    if ((Test-Path -Path "$Path\ffmpeg.exe") -and (Test-Path -Path "$Path\ffplay.exe") -and (Test-Path -Path "$Path\ffprobe.exe")) {
        Write-Log -ConsoleOnly -Severity 'Info' -Message "Finished downloading the ffmpeg executables."
    }
    else {
        return Write-Log -ConsoleOnly -Severity 'Error' -Message "Failed to download and extract the ffmpeg executables."
    }
} # End Get-Ffmpeg function



# Function for downloading and installing PowerShell-Youtube-dl script files and executables.
function Install-Script {
    param (
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'The directory to install the ''PowerShell-Youtube-dl'' script and executables to.')]
        [string]
        $Path,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'The branch of the ''PowerShell-Youtube-dl'' GitHub repository to download from.')]
        [string]
        $Branch = 'master',

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Whether to create a local shortcut that is used to run the ''youtube-dl-gui.ps1'' script.')]
        [switch]
        $LocalShortcut = $false,
        
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Whether to create a desktop shortcut that is used to run the ''youtube-dl-gui.ps1'' script.')]
        [switch]
        $DesktopShortcut = $false,
        
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Whether to create a start menu shortcut that is used to run the ''youtube-dl-gui.ps1'' script.')]
        [switch]
        $StartMenuShortcut = $false
    )

	# Ensure that the install directory is present.
	if ((Test-Path -Path $Path -PathType 'Container') -eq $false) {
		New-Item -Type 'Directory' -Path $Path | Out-Null
	}

	# Ensure that the 'bin' directory is present.
	if ((Test-Path -Path "$Path\bin" -PathType 'Container') -eq $false) {
		New-Item -Type 'Directory' -Path "$Path\bin" | Out-Null
	}

	# Ensure that the 'var' directory is present.
	if ((Test-Path -Path "$Path\var" -PathType 'Container') -eq $false) {
		New-Item -Type 'Directory' -Path "$Path\var" | Out-Null
	}

	# Ensure that the 'etc' directory is present.
	if ((Test-Path -Path "$Path\etc" -PathType 'Container') -eq $false) {
		New-Item -Type 'Directory' -Path "$Path\etc" | Out-Null
	}

	# Ensure that 'youtube-dl' is installed.
	if ((Test-Path "$Path\bin\youtube-dl.exe") -eq $False) {
		Write-Log -ConsoleOnly -Severity 'Warning' -Message "The youtube-dl executable was not found at '$Path\bin\youtube-dl.exe'."

		Get-YoutubeDl -Path "$Path\bin"
	}

	# Ensure that 'ffmpeg' is installed.
	if ((Test-Path -Path "$Path\bin\ffmpeg.exe") -eq $false -or (Test-Path -Path "$Path\bin\ffplay.exe") -eq $false -or (Test-Path -Path "$Path\bin\ffprobe.exe") -eq $false) {
		Write-Log -ConsoleOnly -Severity 'Warning' -Message "One or more of the ffmpeg executables were not found in '$Path\bin\'."

		Get-Ffmpeg -Path "$Path\bin"
	}

	# Ensure that the script files are installed.
	if ((Test-Path -Path "$Path\bin\youtube-dl.psm1") -eq $false -or (Test-Path -Path "$Path\bin\youtube-dl-gui.ps1") -eq $false -or (Test-Path -Path "$Path\README.md") -eq $false -or (Test-Path -Path "$Path\LICENSE") -eq $false) {
		Write-Log -ConsoleOnly -Severity 'Warning' -Message "One or more of the PowerShell script files were not found in '$Path\'."

		Get-Download -Url "https://github.com/mpb10/PowerShell-Youtube-dl/raw/$Branch/youtube-dl.psm1" -Path "$Path\bin\youtube-dl.psm1"
		Get-Download -Url "https://github.com/mpb10/PowerShell-Youtube-dl/raw/$Branch/youtube-dl-gui.ps1" -Path "$Path\bin\youtube-dl-gui.ps1"
		Get-Download -Url "https://github.com/mpb10/PowerShell-Youtube-dl/raw/$Branch/README.md" -Path "$Path\README.md"
		Get-Download -Url "https://github.com/mpb10/PowerShell-Youtube-dl/raw/$Branch/LICENSE" -Path "$Path\LICENSE"        
	}

	# Ensure that the 'bin' directory containing the executable files is in the system PATH variable.
	if ($ENV:PATH.Split(';') -notcontains "$Path\bin") {
		Write-Log -ConsoleOnly -Severity 'Warning' -Message "The '$Path\bin' directory was not found in the system PATH variable."

		# Add the bin directory to the system PATH variable.
		if ($ENV:PATH.LastIndexOf(';') -eq ($ENV:PATH.Length - 1)) {
			$ENV:PATH += "$Path\bin"
		}
		else {
			$ENV:PATH += ";$Path\bin"
		}

		# Check that the bin directory was actually added to the system PATH variable.
		if ($ENV:PATH.Split(';') -contains "$Path\bin") {
			Write-Log -ConsoleOnly -Severity 'Info' -Message "Added the '$Path\bin' directory to the system PATH variable."
		} else {
			return Write-Log -ConsoleOnly -Severity 'Error' -Message "Failed to add the '$Path\bin' directory to the system PATH variable."
		}
	}
	
	# If the '-LocalShortcut' parameter is provided, create a shortcut in the same directory as
	# the 'youtube-dl-gui.ps1' script that is used to run it.
    if ($LocalShortcut) {
        if ((Test-Path -Path "$Path\PowerShell-Youtube-dl.lnk") -eq $false) {
            # Create the shortcut.
            New-Shortcut -Path "$Path\PowerShell-Youtube-dl.lnk" -TargetPath (Get-Command powershell.exe).Source -Arguments "-ExecutionPolicy Bypass -File ""$Path\bin\youtube-dl-gui.ps1""" -StartPath "$Path\bin"
            
            # Ensure that the shortcut was created.
            if (Test-Path -Path "$Path\PowerShell-Youtube-dl.lnk") {
                Write-Log -ConsoleOnly -Severity 'Info' -Message "Created a shortcut for running 'youtube-dl-gui.ps1' at: '$Path\PowerShell-Youtube-dl.lnk'"
            }
            else {
                return Write-Log -ConsoleOnly -Severity 'Error' -Message "Failed to create a shortcut at: '$Path\PowerShell-Youtube-dl.lnk'"
            }
        } else {
            # Recreate the shortcut so that its values are up-to-date.
            New-Shortcut -Path "$Path\PowerShell-Youtube-dl.lnk" -TargetPath (Get-Command powershell.exe).Source -Arguments "-ExecutionPolicy Bypass -File ""$Path\bin\youtube-dl-gui.ps1""" -StartPath "$Path\bin"
        }
    }

    # If the '-DesktopShortcut' parameter is provided, create a shortcut on the desktop that is used
    # to run the 'youtube-dl-gui.ps1' script.
    if ($DesktopShortcut) {
        $DesktopPath = [environment]::GetFolderPath('Desktop')

        if ((Test-Path -Path "$DesktopPath\PowerShell-Youtube-dl.lnk") -eq $false) {
            # Create the shortcut.
            New-Shortcut -Path "$DesktopPath\PowerShell-Youtube-dl.lnk" -TargetPath (Get-Command powershell.exe).Source -Arguments "-ExecutionPolicy Bypass -File ""$Path\bin\youtube-dl-gui.ps1""" -StartPath "$Path\bin"
            
            # Ensure that the shortcut was created.
            if (Test-Path -Path "$DesktopPath\PowerShell-Youtube-dl.lnk") {
                Write-Log -ConsoleOnly -Severity 'Info' -Message "Created a shortcut for running 'youtube-dl-gui.ps1' at: '$DesktopPath\PowerShell-Youtube-dl.lnk'"
            }
            else {
                return Write-Log -ConsoleOnly -Severity 'Error' -Message "Failed to create a shortcut at: '$DesktopPath\PowerShell-Youtube-dl.lnk'"
            }
        } else {
            # Recreate the shortcut so that its values are up-to-date.
            New-Shortcut -Path "$DesktopPath\PowerShell-Youtube-dl.lnk" -TargetPath (Get-Command powershell.exe).Source -Arguments "-ExecutionPolicy Bypass -File ""$Path\bin\youtube-dl-gui.ps1""" -StartPath "$Path\bin"
        }
    }

    # If the '-StartMenuShortcut' parameter is provided, create a start menu directory containing a shortcut
    # used to run the 'youtube-dl-gui.ps1' script.
    if ($StartMenuShortcut) {
        $AppDataPath = [Environment]::GetFolderPath('ApplicationData')

        if ((Test-Path -Path "$AppDataPath\Microsoft\Windows\Start Menu\Programs\PowerShell-Youtube-dl\PowerShell-Youtube-dl.lnk") -eq $false) {

            # Ensure the start menu directory exists.
            if ((Test-Path -Path "$AppDataPath\Microsoft\Windows\Start Menu\Programs\PowerShell-Youtube-dl" -PathType 'Container') -eq $false) {
                New-Item -Type 'Directory' -Path "$AppDataPath\Microsoft\Windows\Start Menu\Programs\PowerShell-Youtube-dl" | Out-Null
            }

            # Create the shortcut.
            New-Shortcut -Path "$AppDataPath\Microsoft\Windows\Start Menu\Programs\PowerShell-Youtube-dl\PowerShell-Youtube-dl.lnk" -TargetPath (Get-Command powershell.exe).Source -Arguments "-ExecutionPolicy Bypass -File ""$Path\bin\youtube-dl-gui.ps1""" -StartPath "$Path\bin"
            
            # Ensure that the shortcut was created.
            if (Test-Path -Path "$AppDataPath\Microsoft\Windows\Start Menu\Programs\PowerShell-Youtube-dl\PowerShell-Youtube-dl.lnk") {
                Write-Log -ConsoleOnly -Severity 'Info' -Message "Created a start menu directory and shortcut for running 'youtube-dl-gui.ps1' at: '$AppDataPath\Microsoft\Windows\Start Menu\Programs\PowerShell-Youtube-dl\PowerShell-Youtube-dl.lnk'"
            }
            else {
                return Write-Log -ConsoleOnly -Severity 'Error' -Message "Failed to create a shortcut at: '$AppDataPath\Microsoft\Windows\Start Menu\Programs\PowerShell-Youtube-dl\PowerShell-Youtube-dl.lnk'"
            }
        } else {
            # Recreate the shortcut so that its values are up-to-date.
            New-Shortcut -Path "$AppDataPath\Microsoft\Windows\Start Menu\Programs\PowerShell-Youtube-dl\PowerShell-Youtube-dl.lnk" -TargetPath (Get-Command powershell.exe).Source -Arguments "-ExecutionPolicy Bypass -File ""$Path\bin\youtube-dl-gui.ps1""" -StartPath "$Path\bin"
        }
    }
} # End Install-Script function



# Function for uninstalling the PowerShell-Youtube-dl script files and directories.
function Uninstall-Script {
    param (
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'The directory where the ''PowerShell-Youtube-dl'' script and executables are currently installed to.')]
        [string]
        $Path,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Whether to remove all files that reside in the ''PowerShell-Youtube-dl'' install directory.')]
        [switch]
        $Force = $false
    )
    $DesktopPath = [environment]::GetFolderPath('Desktop')
    $AppDataPath = [Environment]::GetFolderPath('ApplicationData')

    # Remove the script files, executables, and shortcuts
    $FileList = @(
        "$Path\bin\youtube-dl.exe",
        "$Path\bin\ffmpeg.exe",
        "$Path\bin\ffplay.exe",
        "$Path\bin\ffprobe.exe",
        "$Path\bin\youtube-dl.psm1",
        "$Path\bin\youtube-dl-gui.ps1",
        "$Path\README.md",
        "$Path\LICENSE",
        "$Path\PowerShell-Youtube-dl.lnk",
        "$DesktopPath\PowerShell-Youtube-dl.lnk",
        "$AppDataPath\Microsoft\Windows\Start Menu\Programs\PowerShell-Youtube-dl\PowerShell-Youtube-dl.lnk",
        "$Path\var\cache\*.*"
    )
    foreach ($Item in $FileList) {
        try { 
            Remove-Item -Path $Item -ErrorAction Stop
        } catch [System.Management.Automation.ItemNotFoundException] {
            Write-Log -ConsoleOnly -Severity 'Warning' -Message "$_"
        } catch {
            return Write-Log -ConsoleOnly -Severity 'Error' -Message "$_"
        }
    }

    # Remove the '$Path\var\cache\' directory.
    if (Test-Path -Path "$Path\var\cache") {
        try { 
            Remove-Item -Path "$Path\var\cache" -Recurse -Force -ErrorAction Stop
        } catch [System.Management.Automation.ItemNotFoundException] {
            Write-Log -ConsoleOnly -Severity 'Warning' -Message "$_"
        } catch {
            return Write-Log -ConsoleOnly -Severity 'Error' -Message "$_"
        }
    }

    # Remove the directories that were created by the script only if they are empty.
    $FileListDirectories = @(
        "$AppDataPath\Microsoft\Windows\Start Menu\Programs\PowerShell-Youtube-dl",
        "$Path\bin",
        "$Path\etc",
        "$Path\var",
        "$Path"
    )
    foreach ($Item in $FileListDirectories) {
        if ((Get-ChildItem -Path $Item -Recurse | Measure-Object).Count -eq 0 -or $Force) {
            try { 
                Remove-Item -Path $Item -Recurse -Force -ErrorAction Stop
            } catch [System.Management.Automation.ItemNotFoundException] {
                Write-Log -ConsoleOnly -Severity 'Warning' -Message "$_"
            } catch {
                return Write-Log -ConsoleOnly -Severity 'Error' -Message "$_"
            }
        }
    }

    Write-Log -ConsoleOnly -Severity 'Info' -Message 'Finished uninstalling ''PowerShell-Youtube-dl''.'
} # End Uninstall-Script function



function Get-Video {
    param (
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'The URL of the video to download.')]
        [string]
        $Url,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Download the video to this directory.')]
        [string]
        $Path = (Get-Location),

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Additional youtube-dl options to pass to the download command.')]
        [string]
        $YoutubeDlOptions = "-o ""$Path\%(title)s.%(ext)s"" --console-title --ignore-errors --cache-dir ""$Path"" --no-mtime --no-playlist",

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'The path to the directory containing the youtube-dl and ffmpeg executable files.')]
        [string]
        $ExecutablePath
    )

    if (Test-Path -Path $Path) {
        $Path = Resolve-Path -Path $Path
    }
    $Url = "'$($Url.Trim())'"
    $YoutubeDlOptions = $YoutubeDlOptions.Trim()
    
    if ($ExecutablePath.Length -gt 0) {
        $ExecutablePath = $ExecutablePath.Trim()
        $DownloadCommand = "$ExecutablePath\youtube-dl $YoutubeDlOptions $Url"
    } else {
        $DownloadCommand = "youtube-dl $YoutubeDlOptions $Url"
    }

    # Check if the provided '-Path' parameter is a valid directory.
    if ((Test-Path -Path $Path -PathType 'Container') -eq $false) {
        return Write-Log -ConsoleOnly -Severity 'Error' -Message 'Provided path either does not exist or is not a directory.'
    }

    # Check whether the 'youtube-dl' command is in the system's PATH variable
    if ($null -eq (Get-Command "youtube-dl" -ErrorAction SilentlyContinue)) 
    { 
        return Write-Log -ConsoleOnly -Severity 'Error' -Message "Failed to find 'youtube-dl' in the system PATH variable."
    }

    # Check whether the 'ffmpeg' command is in the system's PATH variable
    if ($null -eq (Get-Command "ffmpeg" -ErrorAction SilentlyContinue)) 
    { 
        return Write-Log -ConsoleOnly -Severity 'Error' -Message "Failed to find 'ffmpeg' in the system PATH variable."
    }

    Write-Log -ConsoleOnly -Severity 'Info' -Message "Downloading video from URL $Url to '$Path' using youtube-dl options of '$YoutubeDlOptions'."
    Invoke-Expression $DownloadCommand
} # End Get-Video function



function Get-Audio {
    param (
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'The URL of the video to download audio from.')]
        [string]
        $Url,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Download the video''s audio to this directory.')]
        [string]
        $Path = (Get-Location),

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Additional youtube-dl options to pass to the download command.')]
        [string]
        $YoutubeDlOptions = "-o ""$Path\%(title)s.%(ext)s"" --console-title --ignore-errors --cache-dir ""$Path"" --no-mtime --no-playlist",

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'The path to the directory containing the youtube-dl and ffmpeg executable files.')]
        [string]
        $ExecutablePath
    )

    if (Test-Path -Path $Path) {
        $Path = Resolve-Path -Path $Path
    }
    $Url = "'$($Url.Trim())'"
    $YoutubeDlOptions = $YoutubeDlOptions.Trim()

    if ($ExecutablePath.Length -gt 0) {
        $ExecutablePath = $ExecutablePath.Trim()
        $DownloadCommand = "$ExecutablePath\youtube-dl $YoutubeDlOptions $Url"
    } else {
        $DownloadCommand = "youtube-dl $YoutubeDlOptions $Url"
    }

    # Check if the provided '-Path' parameter is a valid directory.
    if ((Test-Path -Path $Path -PathType 'Container') -eq $false) {
        return Write-Log -ConsoleOnly -Severity 'Error' -Message 'Provided path either does not exist or is not a directory.'
    }

    # Check whether the 'youtube-dl' command is in the system's PATH variable
    if ($null -eq (Get-Command "youtube-dl" -ErrorAction SilentlyContinue)) 
    { 
        return Write-Log -ConsoleOnly -Severity 'Error' -Message "Failed to find 'youtube-dl' in the system PATH variable."
    }

    # Check whether the 'ffmpeg' command is in the system's PATH variable
    if ($null -eq (Get-Command "ffmpeg" -ErrorAction SilentlyContinue)) 
    { 
        return Write-Log -ConsoleOnly -Severity 'Error' -Message "Failed to find 'ffmpeg' in the system PATH variable."
    }

    Write-Log -ConsoleOnly -Severity 'Info' -Message "Downloading audio from URL of $Url to '$Path' using youtube-dl options of '$YoutubeDlOptions'."
    Invoke-Expression $DownloadCommand
} # End Get-Audio function



# Function for retrieving an array of Youtube playlist URLs.
function Get-Playlist {
    param (
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Path to the file containing a list of playlist URLs to download.')]
        [string]
        $Path,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Array object containing a list of playlist URLs to download.')]
        [array]
        $UrlList = @()
    )
    
    # If the '-UrlList' parameter was provided, check if it's a valid array.
    if ($UrlList.Length -gt 0 -and $UrlList -isnot [array]) {
        return Write-Log -ConsoleOnly -Severity 'Error' -Message 'Provided ''-UrlList'' parameter value is not an array or is empty.'
        return @()
    } 
    
    # If the '-Path' parameter was provided, check if it's a valid file and add its contents to the '$UrlList' variable.
    if ($Path.Length -gt 0) {
        $Path = Resolve-Path -Path $Path

        if ((Test-Path -Path $Path -PathType 'Leaf') -eq $false) {
            return Write-Log -ConsoleOnly -Severity 'Error' -Message 'Provided path either does not exist or is not a file.'
            return @()
        }
        else {
            $UrlList += (Get-Content -Path $Path | Where-Object { $_.Trim() -ne '' -and $_.Trim() -notmatch '^#.*' })
        }
    }

    # Return an array of playlist URL string objects.
    Write-Log -ConsoleOnly -Severity 'Info' -Message "Returning $($UrlList.Length) playlist URLs."
    return $UrlList
} # End Get-Playlist function



function Get-VideoPlaylist {
    param (
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Path to the file containing a list of playlist URLs to download.')]
        [string]
        $PlaylistFilePath,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Array object containing a list of playlist URLs to download.')]
        [array]
        $UrlList = @(),

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Download the video to this directory.')]
        [string]
        $Path = (Get-Location),

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Additional youtube-dl options to pass to the download command.')]
        [string]
        $YoutubeDlOptions = "-o ""$Path\%(title)s.%(ext)s"" --console-title --ignore-errors --cache-dir ""$Path"" --no-mtime --yes-playlist",

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'The path to the directory containing the youtube-dl and ffmpeg executable files.')]
        [string]
        $ExecutablePath
    )

    # Ensure that one of the 'Get-Playlist' options was provided to the command and then run it.
    $GetPlaylistOptions = ''
    if (Test-Path Variable:PlaylistFilePath) {
        $GetPlaylistOptions = "-Path $PlaylistFilePath"
    } elseif (Test-Path Variable:UrlList) {
        $GetPlaylistOptions = "-UrlList $UrlList"
    } else {
        return Write-Log -ConsoleOnly -Severity 'Error' -Message 'Neither ''-UrlList'' or ''-PlaylistFilePath'' parameters were provided.'
    }
    $PlaylistUrls = Get-Playlist $GetPlaylistOptions
    
    # Ensure that the '$YoutubeDlOptions parameter contains the '--yes-playlist' youtube-dl option.
    if ($YoutubeDlOptions -notcontains 'yes-playlist') {
        $YoutubeDlOptions = $YoutubeDlOptions + ' --yes-playlist'
    }

    # Download each playlist URL.
    foreach ($UrlItem in $PlaylistUrls ) {
        if (Test-Path Variable:ExecutablePath) {
            Get-Video -Path $Path -Url $UrlItem -YoutubeDlOptions $YoutubeDlOptions -ExecutablePath $ExecutablePath
        } else {
            Get-Video -Path $Path -Url $UrlItem -YoutubeDlOptions $YoutubeDlOptions
        }
    }

    Write-Log -ConsoleOnly -Severity 'Info' -Message "Downloaded videos from $($PlaylistUrls.Count) playlists to '$Path'."
}



function Get-AudioPlaylist {
    param (
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Path to the file containing a list of playlist URLs to download.')]
        [string]
        $PlaylistFilePath,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Array object containing a list of playlist URLs to download.')]
        [array]
        $UrlList = @(),

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Download the video''s audio to this directory.')]
        [string]
        $Path = (Get-Location),

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Additional youtube-dl options to pass to the download command.')]
        [string]
        $YoutubeDlOptions = "-o ""$Path\%(title)s.%(ext)s"" --console-title --ignore-errors --cache-dir ""$Path"" --no-mtime --yes-playlist",
        
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'The path to the directory containing the youtube-dl and ffmpeg executable files.')]
        [string]
        $ExecutablePath
    )

    # Ensure that one of the 'Get-Playlist' options was provided to the command and then run it.
    $GetPlaylistOptions = ''
    if (Test-Path Variable:PlaylistFilePath) {
        $GetPlaylistOptions = "-Path $PlaylistFilePath"
    } elseif (Test-Path Variable:UrlList) {
        $GetPlaylistOptions = "-UrlList $UrlList"
    } else {
        return Write-Log -ConsoleOnly -Severity 'Error' -Message 'Neither ''-UrlList'' or ''-PlaylistFilePath'' parameters were provided.'
    }
    $PlaylistUrls = Get-Playlist $GetPlaylistOptions
    
    # Ensure that the '$YoutubeDlOptions parameter contains the '--yes-playlist' youtube-dl option.
    if ($YoutubeDlOptions -notcontains 'yes-playlist') {
        $YoutubeDlOptions = $YoutubeDlOptions + ' --yes-playlist'
    }

    # Download each playlist URL.
    foreach ($UrlItem in $PlaylistUrls ) {
        if (Test-Path Variable:ExecutablePath) {
            Get-Audio -Path $Path -Url $UrlItem -YoutubeDlOptions $YoutubeDlOptions -ExecutablePath $ExecutablePath
        } else {
            Get-Audio -Path $Path -Url $UrlItem -YoutubeDlOptions $YoutubeDlOptions
        }
    }

    Write-Log -ConsoleOnly -Severity 'Info' -Message "Downloaded video audio from $($PlaylistUrls.Count) playlists to '$Path'."
}
