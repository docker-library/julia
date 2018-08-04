FROM microsoft/windowsservercore:1709

# $ProgressPreference: https://github.com/PowerShell/PowerShell/issues/2138#issuecomment-251261324
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ENV JULIA_VERSION 0.7.0-rc2
ENV JULIA_SHA256 c29fbff932934672c85161b2e18b33a4021359577f815d4badc81b1c9f49fa9e

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
