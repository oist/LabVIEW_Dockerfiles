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
	"ni-visa-shared-components"
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
	# Here we search explicitly for version 21.<something>
	$PkgsInfo = .\GetPackageInfo $pkg | Where-Object { $_.version -like '21*' }
	If ( $null -eq $PkgsInfo) {
		echo "Unable to find a source package for the name $pkg"
	} Else {
		$PkgInfo = $PkgsInfo[0]
		# Make up a version like 21.99.<whatever else was in the original version>
		$TargetVersion = $PkgInfo.Version -replace('21\.[0-9]+\.', '21.99.')

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
