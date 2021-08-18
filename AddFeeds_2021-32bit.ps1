# This script adds feeds to nipkg for a specific build set
# Here we focus on LabVIEW 2021, 32-bit.

$year = "2021"
$pkg_root = "https://download.ni.com/support/nipkg/products"

$lv_modules = "rt-module", "fpga-module", "vi-analyzer-toolkit", "aspt-toolkit", "cdsim-module", "mathscript-module"

# The "core" modules don't include core in the URL
nipkg.exe feed-add --name="""ni-labview-$year-core-x86-en-$year-released""" --system $("$pkg_root/ni-l/ni-labview-$year-x86/21.0/released")
nipkg.exe feed-add --name="""ni-labview-$year-core-x86-en-$year-released-critical""" --system $("$pkg_root/ni-l/ni-labview-$year-x86/21.0/released-critical")

# The other ni-l/ni-labview-... packages have a shared pattern
ForEach($module in $lv_modules)
{
	nipkg.exe feed-add --name="""ni-labview-$year-$module-x86-en-$year-released""" --system $("$pkg_root/ni-l/ni-labview-$year-$module-x86/21.0/released")
	nipkg.exe feed-add --name="""ni-labview-$year-$module-x86-en-$year-released-critical""" --system $("$pkg_root/ni-l/ni-labview-$year-$module-x86/21.0/released-critical")
}

$feeds = @(
	[pscustomobject]@{name = "ni-daqmx-21-0-released"; url = "$($pkg_root)/ni-d/ni-daqmx/21.0/released"}
	[pscustomobject]@{name = "ni-visa-21-0-released"; url = "$($pkg_root)/ni-v/ni-visa/21.0/released"}
	[pscustomobject]@{name = "ni-compactrio-21-0-released"; url = "$($pkg_root)/ni-c/ni-compactrio/21.0/released"}
)

ForEach($pair in $feeds)
{
	nipkg.exe feed-add --name="""$($pair.name)""" --system $($pair.url)
	nipkg.exe feed-add --name="""$($pair.name)-critical""" --system $($pair.url + "-critical")
}
