param (
	$FeedDirectory='.\fake-packages',
	[switch] $Zip,
	[switch] $CleanCreatedFiles,
	[string] $versionPattern = '21*',
	[string[]] $fake_packages = @(
		"ni-cabled-pcie",
		"ni-controllerdriver",
		"ni-ede",
		"ni-pxiplatformservices-runtime",
		"ni-rio-fpga-driver",
		"ni-rio-mite",
		"ni-serial-runtime",
		"ni-usblan",
		"ni-usbvcp",
		"ni-visa-shared-components",
		"ni-daqmx-runtime-core"
	)
)
New-Item -ItemType Directory -Force -Path $FeedDirectory | Out-Null

$Maintainer = "Christian Butcher <christian.butcher@oist.jp>"

function PopulateControlFile {
	param (
		$Path,
		$pkg
	)
	# Parenthesis force completion of the command before sending through pipeline
	(Get-Content -Path $Path -Raw) `
		-Replace "<PACKAGENAME>", $pkg.PackageName `
		-Replace "<VERSION>", $pkg.Version `
		-Replace "<DEPENDS_LIST>", $pkg.Depends_List `
		-Replace "<PROVIDES_LIST>", $pkg.Provides_List `
		-Replace "<MAINTAINER>", $pkg.Maintainer `
		| Set-Content -Path $Path
}

$template_path = Join-Path $PSScriptRoot 'template_nipkg'
New-Item -ItemType Directory -Force -Path "C:\fake-nipkgs" | Out-Null

ForEach($pkg in $fake_packages)
{
	Write-Output "Processing $pkg"
	$PkgsInfo = .\GetPackageInfo -PackageName $pkg
	If ( $null -eq $PkgsInfo) {
		Write-Output "Unable to find a source package for the name $pkg"
	} Else {
		# Here we search explicitly for version 21.<something>
		# Exclude any packages where the maintainer is listed as the maintainer variable,
		# since these are probably fakes created by this script or similar.
		$PkgInfo = $PkgsInfo | Where-Object { $_.Maintainer -notlike $Maintainer -and $_.version -like $versionPattern }
		If ( $null -eq $PkgInfo ) {
			# Couldn't get that version matched, use first result
			$PkgInfo = $PkgsInfo[0]
		}
		If ( $PkgInfo.count -gt 0 ) {
			# If we still have an array, just choose the first.
			# Improve this by choosing the highest version...
			$PkgInfo = $PkgInfo[0]
		}
		# Make up a version by adding 80 to the minor version of the original package.
		$VersionElems = $PkgInfo.Version -split('\.')
		$MinorVersionPlus80 = [int]($VersionElems[1]) + 80
		$VersionElems.Item(1) = [string]$MinorVersionPlus80
		$TargetVersion = $VersionElems -join('.')
		Write-Output "Setting version to $TargetVersion"

		# Create an object with the required keys to create a fake package from the template
		$FakePkgInfo = @{}
		$FakePkgInfo['Maintainer'] = $Maintainer
		$FakePkgInfo['Version'] = $TargetVersion
		$FakePkgInfo['PackageName'] = $PkgInfo.Package
		$FakePkgInfo['Depends_List'] = $PkgInfo.Depends
		$FakePkgInfo['Provides_List'] = $PkgInfo.Provides

		# Create the fake package
		$PackagePath = Join-Path "C:\fake-nipkgs" $FakePkgInfo.PackageName
		Copy-Item -Recurse $template_path $PackagePath
		$ControlFilePath = Join-Path $PackagePath 'control\control'
		PopulateControlFile -Path $ControlFilePath -pkg $FakePkgInfo
		nipkg.exe pack $PackagePath $FeedDirectory
	}
}

Remove-Item -Recurse "C:\fake-nipkgs\"

If($Zip)
{
	$ZipFile = '.\FakePackages.zip'
	Write-Output "Creating zip file $ZipFile"
	Compress-Archive -Path $FeedDirectory\* -DestinationPath $ZipFile -Force -Verbose
}

If($CleanCreatedFiles)
{
	Remove-Item -Recurse $FeedDirectory
}
