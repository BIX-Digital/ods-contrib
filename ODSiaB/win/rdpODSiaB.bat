@echo off
::=========================================================================
:: Starts an SSM session to a given instance-id and forwards RDP port 3389
:: to localhost.
::
:: Usage:
:: Enter an Instance-ID below and start the script inside a cmd.exe session
::=========================================================================
 
set instanceId="<your_instance_id>"
set localPort=56789

:: Proxy Setting
set no_proxy= 127.0.0.1
set http_proxy=
set https_proxy=
 
echo --- Press Ctrl-C to stop port forwarding! ---

:: Start SSM Session
aws ssm start-session --target %instanceId% --document-name AWS-StartPortForwardingSession --parameters portNumber="3389",localPortNumber=%localPort%
