# This script builds all containers in series.
# The 64-bit version can be built in parallel to save some time, but that makes this script far more complicated.
# If you want to do that, you can simply copy the commands from here and run them in two separate PowerShell terminals.

# Validate that a serial number was provided
# The validate pattern here protects against picking up '-LABVIEW_SERIAL_NUMBER="blah"' via positional parameter
[CmdletBinding(PositionalBinding=$false)]
Param(
  [Parameter(Mandatory)]
  [ValidatePattern("^[0-9A-z]*$")]
  [string]
  $LABVIEW_SERIAL_NUMBER,

  # [ValidateSet("2019", "2021")]
  # [string] $year,

  [string] $Context,

  # Include or exclude GoCD from the images (default is excluded)
  [switch] $IncludeGoCD,
  [switch] $SkipGoCDConnection, # See below
  [string] $GO_SERVER_URL
)

# SkipGoCDConnection is intended for use when a GoCD server is not available at image build-time,
# but the images should still contain the go-agent and JVM to run it.
# In this case, the tags generated match those expected for use with GoCD, but the .jar files are
# not downloaded. In this case, the elastic agents (containers from these images) will need to download
# the JAR files and agent-plugins.zip file on every start. This makes the agents seem slower to start.
# The GoCD Server used to download these files does not need to be the same as the one that will be used
# for CI/CD, but should be the same version and have the same installed plugins to avoid needing to
# update on every call.

# Here 'vEthernet (nat)' is the name for the network on which the Windows Docker containers run by default.
# If your GoCD server is on a different host, set this IP address differently.
# The URL should end with the port, and then /go (http://<ip-address-or-hostname>:<port>/go)
# If you do not pass -IncludeGoCD, then this is calculated but ignored
If (! $GO_SERVER_URL) {
  Write-Verbose "Using Get-NetIPAddress to determine host IP address to use for GoCD Server"
  $GO_SERVER_URL='http://' + (Get-NetIPAddress -InterfaceAlias "vEthernet (nat)" -AddressFamily "IPv4").IPAddress+':8153/go'
  Write-Verbose "Setting GO_SERVER_URL = '$GO_SERVER_URL'"
}

# Set up variables for the tag names. 
# A 'latest' tag is also added (this is convenient for 'auto-updating' on the build system without changes to configuration),
# but if you don't want a latest tag, you can remove that part from each build line
$ORG_TAG_NAME='oist'
$TAG_VERSION=(Get-Date -Format 'yyMMdd')

$CONTEXT_FLAG = If ($Context) {"-c $Context"} Else {" "}

# Build the base image for GoCD
$DOCKERFILE_BASE = If ($IncludeGoCD) {'.\Dockerfile.GoCD_Base'} Else {'.\Dockerfile.BaseNIPM'}
$process = (Start-Process -Wait -PassThru docker -NoNewWindow -ArgumentList `
  "$CONTEXT_FLAG",`
  "build",`
  "-t $ORG_TAG_NAME/nipm_base:$TAG_VERSION",`
  "-t $ORG_TAG_NAME/nipm_base:latest",`
  "-f $DOCKERFILE_BASE",`
  "."
)
If($process.ExitCode -ne '0') {
  Write-Verbose ("Exiting because the base image build returned a non-zero exit code (" + $process.ExitCode  + ").")
  Exit $process.ExitCode
}

$TARGET_SUFFIX = If ($IncludeGoCD -and !$SkipGoCDConnection) { "_gocd" } Else { "" }
$TAG_SUFFIX = If ($IncludeGoCD) { "_gocd" } Else { "" }

Function createBuildConfig {
  Param(
    [Parameter(Mandatory=$true)]
    [string] $year
  )
  Process {
    return @(
      [pscustomobject]@{
        PSTypeName = "BuildConfig";
        description = "32-bit ${year}";
        bitness = "-x86";
        target = "labview_base${TARGET_SUFFIX}";
        tagname = "labview_${year}_daqmx${TAG_SUFFIX}"
      }
      [pscustomobject]@{
        PSTypeName = "BuildConfig";
        description = "64-bit ${year}";
        bitness = "";
        target = "labview_base${TARGET_SUFFIX}";
        tagname = "labview_${year}_64_daqmx${TAG_SUFFIX}"
      }
      [pscustomobject]@{
        PSTypeName = "BuildConfig";
        description = "${year} cRIO";
        bitness = "-x86";
        target = "labview_extended${TARGET_SUFFIX}";
        tagname = "labview_${year}_daqmx_crio${TAG_SUFFIX}"
      }
    )
  }
}

$configs = @(
  [pscustomobject]@{year = "2019"; imageConfigs = createBuildConfig("2019") }
  [pscustomobject]@{year = "2021"; imageConfigs = createBuildConfig("2021") }
)

# Years are in parallel - images within a target year are in series
$configs | ForEach-Object -Parallel {
  ForEach ($config in $_.imageConfigs) {
    $tagname = "$using:ORG_TAG_NAME/$($config.tagname)"
    Write-Host ("Building the $($config.description) image (tagname: $tagname)")
    $process = (Start-Process -Wait -PassThru docker  -ArgumentList `
      "$using:CONTEXT_FLAG",`
      "build",`
      "-t ${tagname}:$using:TAG_VERSION",`
      "-t ${tagname}:latest",`
      "-f .\Dockerfile.general",`
      "--target $($config.target)",`
      "--build-arg LABVIEW_SERIAL_NUMBER=$using:LABVIEW_SERIAL_NUMBER",`
      "--build-arg GO_SERVER_URL=$using:GO_SERVER_URL",`
      "--build-arg year=$($_.year)",`
      "--build-arg bitness=`"$($config.bitness)`"",`
      "."
    )
    If($process.ExitCode -ne '0') {
      Write-Error ("Exiting because the $($config.description) image build returned a non-zero exit code (" + $process.ExitCode  + ").")
      Exit $process.ExitCode
    } Else {
      Write-Host ("Finished building the $($config.description) image (tagname: $tagname)")
    }
  }
}
