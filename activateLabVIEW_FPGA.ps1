param (
  [string]$Version,
  [string]$SerialNumber
)

Write-Host "Activating LabVIEW FPGA package with serial number: " $SerialNumber

Start-Process "C:\Program Files (x86)\National Instruments\Shared\License Manager\Bin\nilmUtil.exe" `
  -ArgumentList "-s", "-activate", "LabVIEW_FPGA_PKG", "-version", $Version, "-serialnumber", $SerialNumber `
  -Wait

Get-Content "C:\ProgramData\National Instruments\License Manager\Licenses\LabVIEW_FPGA_PKG*"