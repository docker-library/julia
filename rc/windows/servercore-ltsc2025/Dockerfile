#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM mcr.microsoft.com/windows/servercore:ltsc2025

# $ProgressPreference: https://github.com/PowerShell/PowerShell/issues/2138#issuecomment-251261324
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ENV JULIA_VERSION 1.14.0-alpha2
ENV JULIA_URL https://julialang-s3.julialang.org/bin/winnt/x64/1.14/julia-1.14.0-alpha2-win64.exe
ENV JULIA_SHA256 68f49717241692c0c7022d4e3fa567af4659e723e0c5b04d24668a98f30aa46c

RUN Write-Host ('Downloading {0} ...' -f $env:JULIA_URL); \
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; \
	Invoke-WebRequest -Uri $env:JULIA_URL -OutFile 'julia.exe'; \
	\
	Write-Host ('Verifying sha256 ({0}) ...' -f $env:JULIA_SHA256); \
	if ((Get-FileHash julia.exe -Algorithm sha256).Hash -ne $env:JULIA_SHA256) { \
		Write-Host 'FAILED!'; \
		exit 1; \
	}; \
	\
	Write-Host 'Installing ...'; \
	Start-Process -Wait -NoNewWindow \
		-FilePath '.\julia.exe' \
		-ArgumentList @( \
			'/SILENT', \
			'/DIR=C:\julia' \
		); \
	\
	Write-Host 'Removing ...'; \
	Remove-Item julia.exe -Force; \
	\
	Write-Host 'Updating PATH ...'; \
	$env:PATH = 'C:\julia\bin;' + $env:PATH; \
	[Environment]::SetEnvironmentVariable('PATH', $env:PATH, [EnvironmentVariableTarget]::Machine); \
	\
	Write-Host 'Verifying install ("julia --version") ...'; \
	julia --version; \
	\
	Write-Host 'Complete.'

CMD ["julia"]
