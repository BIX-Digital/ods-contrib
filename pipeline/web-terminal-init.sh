#!/bin/bash
set -eu

SOPS_VERSION=3.7.1
AGE_VERSION=1.0.0
HELM_PLUGIN_DIFF_VERSION=3.3.2
HELM_PLUGIN_SECRETS_VERSION=3.10.0

# Extend PATH to user-writable location
mkdir -p bin
export PATH=/home/user/bin:$PATH
 
# Install Helm plugins
helm plugin install https://github.com/databus23/helm-diff --version v${HELM_PLUGIN_DIFF_VERSION}
helm plugin install https://github.com/jkroepke/helm-secrets --version v${HELM_PLUGIN_SECRETS_VERSION}
 
# Install sops
curl -LO https://github.com/mozilla/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux
chmod +x sops-v${SOPS_VERSION}.linux
mv sops-v${SOPS_VERSION}.linux bin/sops
 
# Install age
curl -LO https://github.com/FiloSottile/age/releases/download/v${AGE_VERSION}/age-v${AGE_VERSION}-linux-amd64.tar.gz
tar -xzvf age-v${AGE_VERSION}-linux-amd64.tar.gz
chmod +x age/age age/age-keygen
mv age/age bin/age
mv age/age-keygen bin/age-keygen
rm  age-v${AGE_VERSION}-linux-amd64.tar.gz
 
# Setup age key
mkdir -p /home/user/.config/sops/age
namespace=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
if oc -n ${namespace} get secrets/helm-secrets-age-key &> /dev/null; then
  oc -n ${namespace} get secrets/helm-secrets-age-key -o jsonpath='{.data.key\.txt}' | base64 --decode > /home/user/.config/sops/age/keys.txt
else
  echo 'No secret helm-secrets-age-key found, setup age key manually.'
fi

echo "Done with setup. Now run:"
echo 'export PATH=/home/user/bin:$PATH'
