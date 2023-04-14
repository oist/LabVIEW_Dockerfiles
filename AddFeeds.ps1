# This script adds feeds to nipkg for a specific build set
# Defaults focus on LabVIEW 2021, 32-bit.

[CmdletBinding(PositionalBinding=$false)]
Param(
	[ValidateSet("2019", "2021")]
	[string] $year = "2021",

	[switch] $x64
)

$bitness = If ($x64) { "" } Else { "-x86" }
$lvVersion = If ($year -eq "2019") { "19.1" } Else { "21.0" }
$moduleVersionNum = If ($year -eq "2019") { "19.0" } Else { "21.0" }
$svVersion = If ($year -eq "2019") { "19.0" } Else { "21.5" }
$crioVersion = If ($year -eq "2019") { "19.5" } Else { "21.0" }
$visaVersion = If ($year -eq "2019") { "19.5" } Else { "21.0" }
$daqmxVersion = If ($year -eq "2019") { "19.5" } Else { "21.0" }
$pkg_root = "https://download.ni.com/support/nipkg/products"

# Feeds are added for 64-bit rt/fpga, but won't be installed by the Dockerfile
$lv_modules = "rt-module", "fpga-module", "vi-analyzer-toolkit", "aspt-toolkit", "cdsim-module", "mathscript-module"

# The "core" modules don't include core in the URL
nipkg.exe feed-add --name="""ni-labview-$year-core$bitness-en-$year-released""" --system $("$pkg_root/ni-l/ni-labview-$year$bitness/$lvVersion/released")
nipkg.exe feed-add --name="""ni-labview-$year-core$bitness-en-$year-released-critical""" --system $("$pkg_root/ni-l/ni-labview-$year$bitness/$lvVersion/released-critical")

# The other ni-l/ni-labview-... packages have a shared pattern
ForEach($module in $lv_modules)
{
	nipkg.exe feed-add --name="""ni-labview-$year-$module$bitness-en-$year-released""" --system $("$pkg_root/ni-l/ni-labview-$year-$module$bitness/$moduleVersionNum/released")
	nipkg.exe feed-add --name="""ni-labview-$year-$module$bitness-en-$year-released-critical""" --system $("$pkg_root/ni-l/ni-labview-$year-$module$bitness/$moduleVersionNum/released-critical")
}

# Drivers have one package for 32+64 bit, so no need to add differing URLs.
$feeds = @(
	[pscustomobject]@{name = "ni-daqmx-$(${daqmxVersion}.replace(".", "-"))-released"; url = "$($pkg_root)/ni-d/ni-daqmx/$daqmxVersion/released"}
	[pscustomobject]@{name = "ni-compactrio-$(${crioVersion}.replace(".", "-"))-released"; url = "$($pkg_root)/ni-c/ni-compactrio/$crioVersion/released"}
	[pscustomobject]@{name = "ni-visa-$(${visaVersion}.replace(".", "-"))-released"; url = "$($pkg_root)/ni-v/ni-visa/$visaVersion/released"}
	[pscustomobject]@{name = "ni-sv-toolkit-$year$bitness-$year-released"; url = "$($pkg_root)/ni-s/ni-sv-toolkit-$year$bitness/$svVersion/released"}
)

ForEach($pair in $feeds)
{
	nipkg.exe feed-add --name="""$($pair.name)""" --system $($pair.url)
	nipkg.exe feed-add --name="""$($pair.name)-critical""" --system $($pair.url + "-critical")
}
