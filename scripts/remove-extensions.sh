#!/usr/bin/env bash
for ext in \
cweijan.epub-reader \
fill-labs.dependi \
gitpod.gitpod-flex \
golang.go \
hashicorp.terraform \
mechatroner.rainbow-csv \
ms-azure-load-testing.microsoft-testing \
ms-azuretools.azure-dev \
ms-azuretools.vscode-azure-github-copilot \
ms-azuretools.vscode-azure-mcp-server \
ms-azuretools.vscode-azureappservice \
ms-azuretools.vscode-azurefunctions \
ms-azuretools.vscode-azureresourcegroups \
ms-azuretools.vscode-azurestaticwebapps \
ms-azuretools.vscode-azurestorage \
ms-azuretools.vscode-azureterraform \
ms-azuretools.vscode-azurevirtualmachines \
ms-azuretools.vscode-bicep \
ms-azuretools.vscode-containers \
ms-azuretools.vscode-cosmosdb \
ms-dotnettools.csdevkit \
ms-vscode-remote.remote-containers \
ms-vscode-remote.remote-ssh \
ms-vscode-remote.remote-ssh-edit \
ms-vscode-remote.remote-wsl \
ms-vscode-remote.vscode-remote-extensionpack \
ms-vscode.azure-repos \
ms-vscode.cmake-tools \
ms-vscode.cpptools \
ms-vscode.cpptools-extension-pack \
ms-vscode.cpptools-themes \
ms-vscode.live-server \
ms-vscode.remote-explorer \
ms-vscode.remote-repositories \
ms-vscode.remote-server \
ms-vscode.vscode-node-azure-pack \
ms-vscode.vscode-speech \
ms-windows-ai-studio.windows-ai-studio \
redhat.java \
redhat.vscode-yaml \
rosshamish.kuskus-kusto-syntax-highlighting \
svelte.svelte-vscode \
teamsdevapp.vscode-ai-foundry \
vscjava.vscode-gradle \
vscjava.vscode-java-debug \
vscjava.vscode-java-dependency \
vscjava.vscode-java-pack \
vscjava.vscode-java-test \
vscjava.vscode-maven
do
  if code --list-extensions | grep -q "^$ext$"; then
    code --uninstall-extension "$ext"
  fi
done