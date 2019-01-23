FROM microsoft/windowsservercore:ltsc2016

# $ProgressPreference: https://github.com/PowerShell/PowerShell/issues/2138#issuecomment-251261324
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ENV JULIA_VERSION 1.1.0
ENV JULIA_SHA256 15bc552e43f5d83d20e439b6026a95f2fd8d57c32249c602dc836ce2798f4a33

RUN $url = ('https://julialang-s3.julialang.org/bin/winnt/x64/{1}/julia-{0}-win64.exe' -f $env:JULIA_VERSION, ($env:JULIA_VERSION.Split('.')[0..1] -Join '.')); \
        Write-Host ('Downloading {0} ...' -f $url); \
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; \
        Invoke-WebRequest -Uri $url -OutFile 'julia.exe'; \
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
                        '/S', \
                        '/D=C:\julia' \
                ); \
        \
        Write-Host 'Updating PATH ...'; \
        $env:PATH = 'C:\julia\bin;' + $env:PATH; \
        [Environment]::SetEnvironmentVariable('PATH', $env:PATH, [EnvironmentVariableTarget]::Machine); \
        \
        Write-Host 'Verifying install ("julia --version") ...'; \
        julia --version; \
        \
        Write-Host 'Removing ...'; \
        Remove-Item julia.exe -Force; \
        \
        Write-Host 'Complete.'

CMD ["julia"]
