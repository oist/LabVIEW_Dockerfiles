param (
	$FeedDirectory='.\fake-packages',
	[switch] $Zip,
	[switch] $CleanCreatedFiles
)
New-Item -ItemType Directory -Force -Path $FeedDirectory | Out-Null

$fake_packages = @(
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
New-Item -ItemType Directory -Force -Path "C:\temp\fake-nipkgs" | Out-Null

ForEach($pkg in $fake_packages)
{
	$PkgsInfo = .\GetPackageInfo $pkg
	If ( $null -eq $PkgsInfo) {
		echo "Unable to find a source package for the name $pkg"
	} Else {
		# Here we search explicitly for version 21.<something>
		$PkgInfo = $PkgsInfo | Where-Object { $_.version -like '21*' }
		If ( $null -eq $PkgInfo ) {
			# Couldn't get that version matched, use first result
			$PkgInfo = $PkgsInfo[0]
		}
		# Make up a version by adding 80 to the minor version of the original package.
		$VersionElems = $PkgInfo.Version -split('\.')
		$MinorVersionPlus80 = [int]($VersionElems[1]) + 80
		$VersionElems.Item(1) = [string]$MinorVersionPlus80
		$TargetVersion = $VersionElems -join('.')

		# Create an object with the required keys to create a fake package from the template
		$FakePkgInfo = @{}
		$FakePkgInfo['Maintainer'] = $Maintainer
		$FakePkgInfo['Version'] = $TargetVersion
		$FakePkgInfo['PackageName'] = $PkgInfo.Package
		$FakePkgInfo['Depends_List'] = $PkgInfo.Depends
		$FakePkgInfo['Provides_List'] = $PkgInfo.Provides

		# Create the fake package
		$PackagePath = Join-Path "C:\temp\fake-nipkgs" $FakePkgInfo.PackageName
		Copy-Item -Recurse $template_path $PackagePath
		$ControlFilePath = Join-Path $PackagePath 'control\control'
		PopulateControlFile -Path $ControlFilePath -pkg $FakePkgInfo
		nipkg.exe pack $PackagePath $FeedDirectory
	}
}

Remove-Item -Recurse "C:\temp\fake-nipkgs\"

If($Zip)
{
	$ZipFile = '.\FakePackages.zip'
	Echo "Creating zip file $ZipFile"
	Compress-Archive -Path $FeedDirectory\* -DestinationPath $ZipFile -Force
}

If($CleanCreatedFiles)
{
	Remove-Item -Recurse $FeedDirectory
}
