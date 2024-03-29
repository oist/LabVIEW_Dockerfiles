param (
	[string]$PackageName,
	[switch]$Installed
)

$operation = If ($Installed) { "info-installed" } Else { "info" }

$data = (nipkg $operation $PackageName | Out-String) -split '(\r?\n){4,}' | Where-Object { $_ -match '\S' } | ForEach-Object {
	# convert the resulting data into Hashtables and cast to PsCustomObject
	# Need at least 2 CRLF because some strings are multiline (e.g. see the FPGA module package)
	$lines = ($_ -split '(\r?\n){2,}' ) | Where-Object { $_ -match '\S' }
	$hash = @{}
	foreach ($line in $lines) {
		$name, $value = ($line -split ':', 2).Trim()
		 # now just overwrite the property if already present without error or add a new one.
		$hash[$name] = $value
	}
	[PsCustomObject] $hash
}

# next, complete the objects in the data array to all have the same properties
$properties = $data | ForEach-Object {($_.PSObject.Properties).Name} | Sort-Object -Unique
# update the items in the collection to contain all properties
$result = foreach($item in $data) {
    $item | Select-Object $properties
}

$result