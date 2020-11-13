param (
	$FeedDirectory='.'
)
New-Item -ItemType Directory -Force -Path $FeedDirectory | Out-Null

$fake_package_contents = Import-CSV -Delimiter "`t" '.\PackageContents.tsv'
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

ForEach($pkg in $fake_package_contents)
{
	Add-Member -InputObject $pkg -NotePropertyName MAINTAINER -NotePropertyValue $Maintainer
	Copy-Item -Recurse '.\template_nipkg\' $pkg.PACKAGENAME
	$PackagePath = Resolve-Path $pkg.PACKAGENAME
	$ControlFilePath = Join-Path $PackagePath 'control\control'
	PopulateControlFile -Path $ControlFilePath -pkg $pkg
	nipkg.exe pack $PackagePath $FeedDirectory
	Remove-Item -Recurse $PackagePath
}
