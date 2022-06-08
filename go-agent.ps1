# -Force prevents errors if the directory exists. It does not delete contained files.
New-Item -ItemType "directory" -Path ".\config" -Force | Out-Null

# Write connection keys into the autoregister file
Add-Content -Path .\config\autoregister.properties -Value ("agent.auto.register.key="+$env:GO_EA_AUTO_REGISTER_KEY)
Add-Content -Path .\config\autoregister.properties -Value ("agent.auto.register.environments="+$env:GO_EA_AUTO_REGISTER_ENVIRONMENT)
Add-Content -Path .\config\autoregister.properties -Value ("agent.auto.register.elasticAgent.agentId="+$env:GO_EA_AUTO_REGISTER_ELASTIC_AGENT_ID)
Add-Content -Path .\config\autoregister.properties -Value ("agent.auto.register.elasticAgent.pluginId="+$env:GO_EA_AUTO_REGISTER_ELASTIC_PLUGIN_ID)
Get-Content -Path .\config\autoregister.properties

function download_file {
	param (
		[string]$remotePath,
		[string]$localPath
	)
	$url = $env:GO_EA_SERVER_URL+$remotePath
	Invoke-WebRequest $url -OutFile $localPath
}

function get_checksums {
	$url = $env:GO_EA_SERVER_URL+"/admin/latest-agent.status"
	(Invoke-WebRequest $url -UseBasicParsing).Headers
}

# Download files from the server/elastic host/something?
$ProgressPreference = 'SilentlyContinue'
download_file -remotePath '/admin/agent' -localPath 'agent.jar'
download_file -remotePath '/admin/agent-plugins.zip' -localPath 'agent-plugins.zip'
download_file -remotePath '/admin/tfs-impl.jar' -localPath 'tfs-impl.jar'

# Get MD5 values from the server. These might be used for authentication/registration?
$checksums = get_checksums
$agent_md5 = $checksums.'Agent-Content-MD5'
$tfs_md5 = $checksums.'TFS-SDK-Content-MD5'
$plugins_md5 = $checksums.'Agent-Plugins-Content-MD5'
$agent_launcher_md5 = $checksums.'Agent-Launcher-Content-MD5'

echo "Launching the GoCD Agent, and waiting for it to exit?"
$RUN_CMD = "java --% -Dcruise.console.publish.interval=10 -Xms128m -Xmx256m -Djava.security.egd=file:/dev/./urandom -Dagent.plugins.md5=$plugins_md5 -Dagent.binary.md5=$agent_md5 -Dagent.launcher.md5=$agent_launcher_md5 -Dagent.tfs.md5=$tfs_md5 -jar agent.jar -serverUrl $env:GO_EA_SERVER_URL"

Invoke-Expression $RUN_CMD