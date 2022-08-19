param (
  [string]$Version,
  [string]$SerialNumber
)

Start-Process "C:\Program Files (x86)\National Instruments\Shared\License Manager\Bin\nilmUtil.exe" `
  -ArgumentList "-s", "-activate", "LabVIEW_RealTime_PKG", "-version", $Version, "-serialnumber", $SerialNumber `
  -Wait

Get-Content "C:\ProgramData\National Instruments\License Manager\Licenses\LabVIEW_RealTime_PKG*"