#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends mono-devel ca-certificates
rm -rf /var/lib/apt/lists/*
mkdir -p /opt/ca19
mcs -sdk:4 -out:/opt/ca19/SurveyClient.exe /opt/ca19/SurveyClient.cs -r:System.Configuration.dll
cat > /opt/ca19/SurveyClient.exe.config <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <configSections>
    <sectionGroup name="userSettings" type="System.Configuration.UserSettingsGroup, System, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089">
      <section name="SurveyClient.Properties.Settings" type="System.Configuration.ClientSettingsSection, System, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089" allowExeDefinition="MachineToLocalUser" requirePermission="false" />
    </sectionGroup>
  </configSections>
  <userSettings>
    <SurveyClient.Properties.Settings>
      <setting name="ApplicationData" serializeAs="String"><value>configured</value></setting>
    </SurveyClient.Properties.Settings>
  </userSettings>
</configuration>
EOF
chmod 755 /opt/ca19/SurveyClient.exe
