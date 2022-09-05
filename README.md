# LabVIEW Dockerfiles for Build-Time usage (CI/CD systems)

## Introduction

This repository contains Dockerfiles that can be used to build images containing LabVIEW with DAQmx, and optionally cRIO drivers.\
The Dockerfiles can be modified or extended as required to allow the installation of other `nipkg`s, potentially for other drivers or hardware setups.\
Instructions given below in places reference the [GoCD Continuous Delivery system](https://www.gocd.org/), but should be useful generally. Instructions that are specific to GoCD only are provided in [GoCD specific instructions](./readme_content/GoCD_Specific_Instructions.md).

Scripts are written using PowerShell for use on Windows, although should in general be possible to execute using PowerShell Core on non-Windows platforms (untested).\
At present, testing has been done exclusively on a Windows 10 host with HyperV available.

## Host OS Requirements

The key requirement for the host system is that it be able to run Windows Docker containers.\
The simplest way to set this up on a Windows 10 or 11 host is using Docker Desktop for Windows with HyperV isolation, which also requires the availability of HyperV on the host system.\
In this case, a wider range of host OS versions and container base images can be used - the requirement is only that the base image be the same or older than the host OS version.

If HyperV is unavailable or undesirable, containers can be run on Windows using "process isolation", but this has much stricter requirements on the host OS - in particular, the images from which your containers run must be based on the same OS version. Further information about this case can be found here: [Docker on Windows without Hyper-V](https://poweruser.blog/docker-on-windows-10-without-hyper-v-a529897ed1cc).\
This Microsoft documentation page ([Windows container version compatibility](https://docs.microsoft.com/en-us/virtualization/windowscontainers/deploy-containers/version-compatibility?tabs=windows-server-2022%2Cwindows-10-21H1)) lists the possible combinations of Docker Host OS and image OS - each version of Windows Server since 2016 has one matching container base image, but for "Windows Client host OS" (Windows 10, 11), there are fewer options available. Check the linked page for up-to-date information.

If using process isolation without HyperV, you may need to adjust the FROM line in the `Dockerfile.GoCD_Base` dockerfile, in order to match your installed system OS version.\
Available tags can be found on the [DockerHub (Windows base OS images)](https://hub.docker.com/_/microsoft-windows-base-os-images) page.

The rest of this README assumes that you have a functioning Windows Docker engine. To test this, you can run commands like those suggested here: [Get started: Run your first Windows container](https://docs.microsoft.com/en-us/virtualization/windowscontainers/quick-start/run-your-first-container). Note that as of the time of writing this, the first example on that page uses `nanoserver:ltsc2022`, which requires Windows 10 21H1 or newer. If you are using an older Windows build (such as 20H2, or 2004), then you could replace this reference with an older image of nanoserver, for example `mcr.microsoft.com/windows/nanoserver:ltsc2019`.

No NI applications or packages are installed onto the host using these images, so installing NIPM or registering feeds in advance is not required.

### Windows Container internet connectivity
If when attempting to build containers you receive errors about ni.com being inaccessible, it may be that your networking configuration for Docker is not allowing connection to the internet from within the containers. You can check this by running a command like
```
> docker run -it --rm mcr.microsoft.com/windows/servercore:2004 cmd
C:\> ping www.ni.com
```
If you receive a timeout, then either NI.com is down, or your Docker engine is blocking internet access from within the containers (probably more likely).

Adding a static DNS value to your Docker engine configuration might fix this - under the settings page of Docker Desktop (gear icon near top-right on Windows), the "Docker Engine" tab contains a JSON file.
Add `"dns": ["8.8.8.8"]` or similar to allow access using the default (`nat`) network.
See [StackOverflow: Not able to access internet inside docker windows container](https://stackoverflow.com/questions/59766135/not-able-to-access-internet-inside-docker-windows-container) for more details.

Alternatively, you can pass the `--network "Default Switch"` argument to your Docker build commands, but this would require editing the build commands (and, if you use it, the `buildAllContainers.ps1` script).

## Serial Numbers and Activation

To activate LabVIEW, a serial number must be passed as a build argument to the dockerfiles. 

This is shown in the examples in the section describing building the images, but it is important to note that the value passed into the build process will not be hidden - that is, it can be inspected from the image.\
As a result, you should not use this method to activate LabVIEW if you intend to share the Docker images with people who do not have access to your LabVIEW serial number.

The activation method used here passes the serial number in the manner described by this forum post: [LabVIEW Continuous Integration License? (JeKo's post, #19)](https://forums.ni.com/t5/Continuous-Integration/LabVIEW-Continuous-Integration-License/m-p/4173792/highlight/true#M392). 

If instead of using a serial number you have a volume license, you would need to adapt that part of the dockerfile (or the `activateLabVIEW{,_RT}.ps1` files), probably in a style similar to that described here: [Licensing LabVIEW with Docker Images (Felipe Pinheiro's blog)](https://felipekb.com/2021/06/30/licensing-labview-with-docker-images/).

## Building images for GoCD

A script (`buildAllContainers.ps1`) is included in this repository for convenience. Details about the choices made can be found in comments in that file, but some points are also described below.\
To use that script, a parameter called `LABVIEW_SERIAL_NUMBER` should be passed, with a string containing your serial number.\
If you do not provide the flag, you will be prompted when running the script.
Take care not to write <code>&#x2011;LABVIEW_SERIAL_NUMBER="serialnum"</code> (with an equals sign).
```
> .\buildAllContainers.ps1 -LABVIEW_SERIAL_NUMBER "A123B456" -IncludeGoCD -GO_SERVER_URL "http://my-gocd-server.com/go"
```
or
```
> .\buildAllContainers.ps1 # Will prompt before running commands
```

If you do not pass the `-IncludeGoCD` switch, then the images will be built without including the necessary files for use with a GoCD server.
If you pass `-IncludeGoCD`, but do not provide a `-GO_SERVER_URL` string value, your Docker host will be used (this assumes that the Docker host is also the GoCD server).

Additionally, the `buildAllContainers.ps1` script can make use of a specific [Docker context](#docker-engine-contexts) by passing a `-Context` flag with the name of the desired context, for example:
```
> .\buildAllContainers.ps1 -LABVIEW_SERIAL_NUMBER "A123B456" -Context windows
```
This allows you to run the Docker engine in Linux containers mode but still build for the Windows context.

To build a suitable image for use with GoCD, run the following (or similar) commands in the host PowerShell terminal, with Docker installed.\
In this example, a context (`-c`) is not used and the Docker engine must be directly set to use Windows containers.\
The tags used can be changed to suit your organization, and if the tags (`:tagname`) are not added, then `latest` is used by default.\
If the image name for the base image is changed, then the second Dockerfile (`Dockerfile.2019_32bit` in the example below) must be updated in the `FROM` line at the top of the file.

```
> docker build -t oist/gocd_nipm_base:YYMMDD -t oist/gocd_nipm_base:latest -f .\Dockerfile.GoCD_Base .
> docker build -t oist/labview_2019_daqmx_gocd:YYMMDD -t oist/labview_2019_daqmx_gocd:latest -f .\Dockerfile.2019_32bit --target labview2019_base --build-arg LABVIEW_SERIAL_NUMBER="yourserialnumberhere" .
```

The combination of these commands will produce two images, one base (`oist/gocd_nipm_base`) and one for 32-bit LabVIEW 2019 with DAQmx but not cRIO (`oist/labview_2019_daqmx_gocd`).\
The name of the second image will be used to run containers for building code - see [GoCD specific instructions](./readme_content/GoCD_Specific_Instructions.md) for further details.

### Testing the built image
To manually check the behaviour of the built image file, you can instantiate a container from the image using a command like the following:
```
docker run -it --rm oist/labview_2019_daqmx_gocd powershell
```
which will start `powershell` in a new interactive (`-i -t`, or `-it`) instance of the `oist/labview_2019_daqmx_gocd` image, with the container removed (`--rm`) after you exit.\
From that shell, you can run commands like `g-cli`, `LabVIEWCLI.exe` and `git`, or simply navigate the filesystem and check that the layout is as expected.

## Changes to build for other platforms

The Docker images built using the files `Dockerfile.2019_32bit` and `Dockerfile.2019_64bit` use the image produced by the `Dockerfile.GoCD_Base` as their base image.\
This is done to allow use with the [GoCD Continuous Delivery](https://www.gocd.org/) system.\
If you want to use these images with Jenkins or other CI/CD systems/build orchestrators, then you should modify the Dockerfile.GoCD_Base to remove the `OpenJDK` section (unless you need the Java Development Kit for your other platform) and the `go-agent.ps1` script (which handles agent registration and task allocation). Additionally, the `CMD` line should be removed or modified.

The `buildAllContainers.ps1` script will incorporate these changes by simply not passing the `-IncludeGoCD` switch:
```
> .\buildAllContainers.ps1 -LABVIEW_SERIAL_NUMBER "A123B456" # Don't pass -IncludeGoCD
```

## SSH Keys

SSH keys can be mounted into the container from the host, via the C:\Users\ContainerAdministrator\.ssh directory.\
And example of this can be seen in the [GoCD specific instructions](./readme_content/GoCD_Specific_Instructions.md).

## Docker Engine contexts

Docker on Windows supports both Windows and Linux images/containers, and containers from both can be run simultaneously.

One method to allow easier access to these (rather than using the desktop right-click menu of Docker Desktop or similar and "Switch to Windows containers...", "Switch to Linux containers...") is to create `context` entries.

A `context` can be passed to `docker` commands to run them for other or the other system.
For example, if a context named `windows` existed, then the build commands above could be modified to read
```
docker -c windows build -t oist/labview_2019_daqmx_gocd:YYMMDD -t oist/labview_2019_daqmx_gocd:latest -f .\Dockerfile.2019_32bit --target labview2019_base --build-arg LABVIEW_SERIAL_NUMBER="yourserialnumberhere" .
```

This allows building and running Windows containers even when the desktop client (which sets the default context) is set to Linux containers.

To create such a context (and an accompanying linux version), run
```
docker context create windows --description "Windows containers via pipe" --default-stack-orchestrator=swarm --docker "host=npipe:////./pipe/dockerDesktopWindowsEngine"
docker context create linux --description "Linux containers via pipe" --default-stack-orchestrator=swarm --docker "host=npipe:////./pipe/dockerDesktopLinuxEngine"
```

The use of these contexts allows the Docker Desktop client (or equivalent setup) to be left in Linux container mode, and Windows containers/images are accessed by passing `-c windows` for each Docker command.
This is useful for this repository (especially with reference to GoCD) because the handling of paths works differently for Linux and Windows host setups, and bind-mounting a directory for the storage of produced NIPKG files is much easier if the host system is set to use Linux containers ([see details](./readme_content/GoCD_Specific_Instructions.md)).

More information about contexts can be found in [a comment on a Docker roadmap issue](https://github.com/docker/roadmap/issues/79#issuecomment-1002424911) and an article linked in that post ([Docker on Windows without Hyper-V](https://poweruser.blog/docker-on-windows-10-without-hyper-v-a529897ed1cc)).

## Fake Packages

Not all `nipkg`s can be successfully installed in a Docker container.
Some of these packages are required as dependencies of other packages that are critical to building more complicated (or hardware-interacting) LabVIEW code into applications or Packed Project Libraries (PPLs).
However, the packages that cannot be installed are typically those which provide functioning libraries, whereas the packages required to build code using those libraries often seem to install instead LabVIEW APIs or sets of VIs.

For example, when building PPLs for a cRIO target, several cRIO packages are required. These are installed in the Dockerfile.2019_32bit dockerfile, in the "extended" section at the end of the file, and include `ni-labview-2019-rt-module-x86-en` and `ni-compactrio-labview-2019-support-x86`. Running `nipkg info ni-compactrio-labview-2019-support-x86` on a computer with the necessary feed for the Real-Time module available produces an output that includes the line
```
Depends: ni-985x-labview-2019-support-x86 (>= 19.5.0),ni-compactrio-c-series-labview-2019-support-x86 (>= 19.5.0),ni-compactrio-common-labview-2019-support-x86 (>= 19.5.0),ni-compactrio-elvis-labview-2019-support-x86 (>= 19.5.0),ni-compactrio-elvis-rio-cm-labview-2019-support-x86 (>= 19.5.0),ni-compactrio-frc-labview-2019-support-x86 (>= 19.5.0),ni-compactrio-myrio-labview-2019-support-x86 (>= 19.5.0),ni-labview-2019-x86 (>= 19.0.0),ni-metauninstaller (>= 19.0.0),ni-msiproperties (>= 19.0.0),ni-rio-clip-generator (>= 19.5.0),ni-teds-labview-2019-support-x86 (>= 19.0.0)
```
showing a dependency on `ni-compactrio-common-labview-2019-support-x86`, which in turn depends on `ni-compactrio-common`, which depends on `ni-compactrio-runtime`, which then includes dependencies on both `ni-rio-mite` and `ni-usblan`, neither of which will successfully install (but the other mentioned packages will install without issue if these dependencies are satisfied).

To resolve this problem, we create fake packages which assert that they `Provide` those dependencies, and are instead empty and install without issue.
This is the responsibility of the `FakePackageCreator_ByName.ps1` script, which accepts a list of `$fake_packages` (and defaults to a collection that are suitable for the installation of cRIO and DAQmx), and a `$versionPattern`, which can be set to filter which versions of packages should be faked (to simplify reuse of the script with different LabVIEW versions).

The use of this script is shown in the Dockerfiles, which create a new NIPM feed, populate it with these fake packages, and then because their version is set to be larger than the real versions, these are chosen over the real NI packages which cannot be installed when dependency resolution determines they are required.


### DAQmx
DAQmx is a special case... Although `ni-daqmx` can be installed using the above method to create a fake `ni-daqmx-runtime-core` package, if this approach is followed without further action, then the `nilvaiu.dll` file is not installed, and attempts to build code which depends on this library fail (as an aside, they will build for cRIO... but not for Windows).

It may be the case that the creation of an empty and suitably named file would be sufficient to solve this issue, but that has not been tested for this repository.\
Instead, this repository contains a script `InstallDAQmxCore.ps1` which downloads, extracts and then attempts to install the necessary MSIs for the `ni-daqmx-runtime-core` package. This script is somewhat slow-running during the build process, but only needs to complete during the generation of the image (not the use of the containers).\
Some of these MSIs fail to install with error 1603 (which is what prevents the normal installation of this package), but those errors do not appear to cause issue for the compilation of valid LabVIEW code into either applications or PPLs.
Presumably this _would_ prevent running such applications within an Docker container instantiated from an image built using this method.

## NIPM Feeds and Parsing

The feeds used by NIPM to install packages are specified in the respective AddFeeds_2019-{32,64}bit.ps1 scripts.\
These can be modified to use different versions - an attempt has been made to simplify this with variables at the top of those files, but NI don't guarantee the stability or predictability of their Feed URLs, so you should check any changes you make.\
A suitable method to find appropriate Feed URLs is to run `nipkg.exe list-source-feeds my_exact_package_name` on a computer with that package (or more accurately, a suitable feed for that package) installed/provisioned. This command does not allow wildcards in the package name - to find a package name, you can use `nipkg info my_approximate_package_*` or similar (in this case, the value that is required is listed under the "Package" entry).\
Further information can be found on the NI forums, for example at [List of NI Feeds](https://forums.ni.com/t5/NI-Package-Manager-NIPM/List-of-NI-Feeds/td-p/4245796).

More friendly output (especially for further use in PowerShell) can be achieved by running the `GetPackageInfo.ps1` script in this repository.
An example command line to find all installed package names matching a pattern would be
```
> .\GetPackageInfo.ps1 -Installed my-name-with-wildcard* | ForEach-Object {
  $_.Package
}
```
The `-Installed` switch can be removed to search all available packages, for example (with a subset of example output)
```
> .\GetPackageInfo.ps1 ni-labview-2019* | ForEach-Object {
  $_.DisplayName
  $_.Package
  echo ""
}
...
NI LabVIEW 2019 SP1 VI Library
ni-labview-2019-vilib-x86-en

LabVIEW Mathscript RT License 2019
ni-labview-2019-mathscript-module-lic

NI LabVIEW 2019 MathScript RT Module Shared
ni-labview-2019-mathscript-module-shared
...
```

The available properties for the objects returned can be found by running `.\GetPackageInfo.ps1 ni-labview-2019-vilib-x86-en | Get-Member`, which produces a list of the names that can be placed after `$_.` in the ForEach-Object block (including for example `DisplayName`, `Package`, `Version`).
