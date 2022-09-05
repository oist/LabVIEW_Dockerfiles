# This script builds all containers in series.
# The 64-bit version can be built in parallel to save some time, but that makes this script far more complicated.
# If you want to do that, you can simply copy the commands from here and run them in two separate PowerShell terminals.

# Validate that a serial number was provided
# The validate pattern here protects against picking up '-LABVIEW_SERIAL_NUMBER="blah"' via positional parameter
Param(
  [Parameter(Mandatory)]
  [ValidatePattern("^[0-9A-z]*$")]
  [string]
  $LABVIEW_SERIAL_NUMBER,

  [string] $GO_SERVER_URL,
  [switch] $Exclude_GoCD,
  [switch] $NoContext
)

# Include or exclude GoCD from the images
$INCLUDE_GOCD=!$Exclude_GoCD
# Here 'vEthernet (nat)' is the name for the network on which the Windows Docker containers run by default.
# If your GoCD server is on a different host, set this IP address differently.
# The URL should end with the port, and then /go (http://<ip-address-or-hostname>:<port>/go)
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

# Comment out if no context flag is required, or change if you have a different context name
$CONTEXT_FLAG = If ($NoContext) {' '} Else {"-c windows"}

# Build the base image for GoCD
$DOCKERFILE_BASE = If ($INCLUDE_GOCD) {'.\Dockerfile.GoCD_Base'} Else {'.\Dockerfile.BaseNIPM'}
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

# Build the 32-bit LabVIEW image, without cRIO support
# The image build above is automatically used (because of the FROM line in the Dockerfile).
$TARGET_LV32_BASE = If ($INCLUDE_GOCD) {'labview2019_base_gocd'} Else {'labview2019_base'}
$LV32_BASE_TAGNAME = If ($INCLUDE_GOCD) {'labview_2019_daqmx_gocd'} Else {'labview_2019_daqmx'}
$process = (Start-Process -Wait -PassThru docker -NoNewWindow -ArgumentList `
  "$CONTEXT_FLAG",`
  "build",`
  "-t $ORG_TAG_NAME/${LV32_BASE_TAGNAME}:$TAG_VERSION",`
  "-t $ORG_TAG_NAME/${LV32_BASE_TAGNAME}:latest",`
  "-f .\Dockerfile.2019_32bit",`
  "--target $TARGET_LV32_BASE",`
  "--build-arg LABVIEW_SERIAL_NUMBER=$LABVIEW_SERIAL_NUMBER",`
  "--build-arg GO_SERVER_URL=$GO_SERVER_URL",`
  "."
)
If($process.ExitCode -ne '0') {
  Write-Verbose ("Exiting because the 32-bit image build returned a non-zero exit code (" + $process.ExitCode  + ").")
  Exit $process.ExitCode
}

# Build the 32-bit LabVIEW image with cRIO support
# This uses a cached build of the 32-bit image built above, so if parallelizing, still do this in series after the 32-bit build.
$TARGET_LV32_CRIO = If ($INCLUDE_GOCD) {'labview2019_extended_gocd'} Else {'labview2019_extended'}
$LV32_CRIO_TAGNAME = If ($INCLUDE_GOCD) {'labview_2019_daqmx_crio_gocd'} Else {'labview_2019_daqmx_crio'}
$process = (Start-Process -Wait -PassThru docker -NoNewWindow -ArgumentList `
  "$CONTEXT_FLAG",`
  "build",`
  "-t $ORG_TAG_NAME/${LV32_CRIO_TAGNAME}:$TAG_VERSION",`
  "-t $ORG_TAG_NAME/${LV32_CRIO_TAGNAME}:latest",`
  "-f .\Dockerfile.2019_32bit",`
  "--target $TARGET_LV32_CRIO",`
  "--build-arg LABVIEW_SERIAL_NUMBER=$LABVIEW_SERIAL_NUMBER",`
  "--build-arg GO_SERVER_URL=$GO_SERVER_URL",`
  "."
)
If($process.ExitCode -ne '0') {
  Write-Verbose ("Exiting because the cRIO image build returned a non-zero exit code (" + $process.ExitCode  + ").")
  Exit $process.ExitCode
}

# Build the 64-bit LabVIEW image
# This could be done at the same time as the above builds separately to speed up the process
$TARGET_LV64_BASE = If ($INCLUDE_GOCD) {'labview2019_64_gocd'} Else {'labview2019_base_64'}
$LV64_BASE_TAGNAME = If ($INCLUDE_GOCD) {'labview_2019_64_daqmx_gocd'} Else {'labview_2019_64_daqmx'}
$process = (Start-Process -Wait -PassThru docker -NoNewWindow -ArgumentList `
  "$CONTEXT_FLAG",`
  "build",`
  "-t $ORG_TAG_NAME/${LV64_BASE_TAGNAME}:$TAG_VERSION",`
  "-t $ORG_TAG_NAME/${LV64_BASE_TAGNAME}:latest",`
  "-f .\Dockerfile.2019_64bit",`
  "--target $TARGET_LV64_BASE",`
  "--build-arg LABVIEW_SERIAL_NUMBER=$LABVIEW_SERIAL_NUMBER",`
  "--build-arg GO_SERVER_URL=$GO_SERVER_URL",`
  "."
)
If($process.ExitCode -ne '0') {
  Write-Verbose ("Exiting because the 64-bit image build returned a non-zero exit code (" + $process.ExitCode  + ").")
  Exit $process.ExitCode
}