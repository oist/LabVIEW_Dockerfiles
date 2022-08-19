# This script adds feeds to nipkg for a specific build set
# Here we focus on LabVIEW 2019, SP1, 32-bit.

$daqmx_version = "19-5"
$daqmx_urlvers = "19.5"
$pkg_root = "https://download.ni.com/support/nipkg/products"
$pkg_root_l = "https://download.ni.com/support/nipkg/products/ni-l"

$feeds = @(
	[pscustomobject]@{name = "ni-labview-2019-core-en-2019 SP1-released"; url = "$($pkg_root_l)/ni-labview-2019/19.1/released"}
	[pscustomobject]@{name = "ni-labview-2019-core-en-2019 SP1-released-critical"; url = "$($pkg_root_l)/ni-labview-2019/19.1/released-critical"}
	[pscustomobject]@{name = "ni-labview-2019-fpga-module-en-2019-released"; url = "$($pkg_root_l)/ni-labview-2019-fpga-module/19.0/released"}
	[pscustomobject]@{name = "ni-labview-2019-vi-analyzer-toolkit-2019-released"; url = "$($pkg_root_l)/ni-labview-2019-vi-analyzer-toolkit/19.0/released"}
	[pscustomobject]@{name = "ni-labview-2019-aspt-toolkit-2019-released"; url = "$($pkg_root_l)/ni-labview-2019-aspt-toolkit/19.0/released"}
	[pscustomobject]@{name = "ni-sv-toolkit-2019-2019-released"; url = "$($pkg_root)/ni-s/ni-sv-toolkit-2019/19.0/released"}
	[pscustomobject]@{name = "ni-sv-toolkit-2019-2019-released-critical"; url = "$($pkg_root)/ni-s/ni-sv-toolkit-2019/19.0/released-critical"}
	[pscustomobject]@{name = "ni-compactrio-19-5-released"; url = "$($pkg_root)/ni-c/ni-compactrio/19.5/released"}
	[pscustomobject]@{name = "ni-daqmx-$($daqmx_version)-released"; url = "$($pkg_root)/ni-d/ni-daqmx/$($daqmx_urlvers)/released"}
	[pscustomobject]@{name = "ni-visa-19-5-released"; url = "$($pkg_root)/ni-v/ni-visa/19.5/released"}
	[pscustomobject]@{name = "ni-labview-command-line-interface-x86-Latest-released"; url = "$($pkg_root_l)/ni-labview-command-line-interface-x86/4.0/released"}
)
   

#	[pscustomobject]@{name = ""; url = ""}

ForEach($pair in $feeds)
{
	$cmd = "nipkg.exe feed-add --name='$($pair.name)' --system $($pair.url)"
	Write-Output $cmd
	Invoke-Expression -Command $cmd
}