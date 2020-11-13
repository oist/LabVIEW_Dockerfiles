param (
	$FeedDirectory='.'
)
New-Item -ItemType Directory -Force -Path $FeedDirectory | Out-Null

$fake_package_contents = Join-Path $PSScriptRoot 'PackageContents.tsv' | Import-CSV -Delimiter "`t"
$Maintainer = "Christian Butcher <christian.butcher@oist.jp>"

function PopulateControlFile {
	param (
		$Path,
		$pkg
	)
	# Parenthesis force completion of the command before sending through pipeline
	(Get-Content -Path $Path -Raw) `
		-Replace "<PACKAGENAME>", $pkg.PACKAGENAME `
		-Replace "<VERSION>", $pkg.VERSION `
		-Replace "<DEPENDS_LIST>", $pkg.DEPENDS_LIST `
		-Replace "<PROVIDES_LIST>", $pkg.PROVIDES_LIST `
		-Replace "<MAINTAINER>", $pkg.MAINTAINER `
		| Set-Content -Path $Path
}

$template_path = Join-Path $PSScriptRoot 'template_nipkg'
New-Item -ItemType Directory -Force -Path "C:\temp\fake-nipkgs" | Out-Null

ForEach($pkg in $fake_package_contents)
{
	Add-Member -InputObject $pkg -NotePropertyName MAINTAINER -NotePropertyValue $Maintainer
	$PackagePath = Join-Path "C:\temp\fake-nipkgs" $pkg.PACKAGENAME
	Copy-Item -Recurse $template_path $PackagePath
	$ControlFilePath = Join-Path $PackagePath 'control\control'
	PopulateControlFile -Path $ControlFilePath -pkg $pkg
	nipkg.exe pack $PackagePath $FeedDirectory
}

Remove-Item -Recurse "C:\temp\fake-nipkgs\"
