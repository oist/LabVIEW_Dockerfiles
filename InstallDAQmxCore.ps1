# Download the real daqmx-runtime-core package
# The version would not be necessary if this is executed before adding fake packages with higher version numbers.
$DAQMX_CORE_VERSION="19.5.0.49152-0+f0"
nipkg.exe download --no-dependency-check ni-daqmx-runtime-core=$DAQMX_CORE_VERSION
$DAQMX_CORE_PKG = Get-ChildItem -Include "ni-daqmx-runtime-core_*" -Name;

# Expand the archive to get the data directory
Start-Process -wait 7z -ArgumentList 'x', $DAQMX_CORE_PKG, "-o${pwd}\daqmx-expanded"
# This can be done in one step by piping, but might increase memory usage. Do as simpler steps.
Start-Process -wait 7z -ArgumentList 'x', 'daqmx-expanded\data.tar.gz', "-o${pwd}\data-tar"
Start-Process -wait 7z -ArgumentList 'x', 'data-tar\data.tar', "-o${pwd}\data"
Remove-Item -Recurse -Force data-tar, daqmx-expanded, $DAQMX_CORE_PKG

# From the niDAQmxCorei_mft.cab file, taking the "part selection" for order
# Entries without a number return 0 and succeed.
$DAQMX_MSI_FILES = @(
  "niDAQmxCorei.msi",
  "nimxefi.msi", # 3010 (needs reboot)
  "nimxefi64.msi", # 3010
  "niscxi.msi",
  "niscxi64.msi", # 1603 (fatal error)
  "nicdigi.msi",
  "nicdigi64.msi",
  "nistci.msi",
  "nistci64.msi",
  "nimioi.msi",
  "nimioi64.msi", # 1603
  "nitimingi.msi",
  "nitimingi64.msi", # 1603
  "nifsli.msi",
  "nifsli64.msi",
  "DAQmxSwitchi.msi", # 3010
  "DAQmxSwitch64.msi", # 1603
  "dsai.msi",
  "dsai64.msi", # 1603
  "ni653x.msi",
  "ni653x64.msi" # 1603
)

# Install all of the MSI files. Some will fail with error 1603, but this doesn't prevent using for builds
# (I expect it means that you can't actually run DAQmx code in such a container though...)
$DAQMX_MSI_FILES | ForEach-Object {
  $MSI_REL_PATH = Get-ChildItem -Include $_ -Name -Recurse .
  $MSI_PATH = "${pwd}\${MSI_REL_PATH}"
  $LOG_FILE = $_.ToString() + "_installLog.txt"
  Start-Process "msiexec.exe" -Wait -ArgumentList "/I", "${MSI_PATH}", "/qn", "/norestart", "/L*v", "${LOG_FILE}"
  Get-Content ${LOG_FILE} -Tail 20
}

Remove-Item -Recurse -Force data