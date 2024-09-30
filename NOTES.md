WORKING
aws-devcontainer
aws-linux
aws-linux-ephemeral
aws-rdp-vs-key-secret
- RDP works
- SSH doesn't work
- VSCode SSH doesn't work
aws-windows
- SSH works
- VSCode SSH works
- RDP Doesn't work

docker-dev-container
docker-code-server


UNKNOWN
azure-*

TO-OR-MAYBE REMOVE
- docker-dev-container 
    - replaced by devcontainer-docker
    - Rename to docker-dev-container
- deployment-coder-server
    - Similar to pod-with-code-server
        - pod-with-code-server
            - Deploys standalone pod
        - deployment-code-server
            - Deploys deployment w/ 1 replica (i.e. 1 pod)
- do we need go/rust/ruby examples?
  - Nope
- aws-windows (aws-rdp-vs-key-secret more useful as an RDP example)
- remove pod-with-code-server (deployment much more useful for lifecycle-management)
- Remove all *-icon templates
- metabase
- incus
- Remove all novncs
- Remove 
    - pod-optional-code-server 
    - pod-only-code-server 
    - pod-maybe-code-server  
    - pod-share-code-server
- Remove standalone-yaml

What we should keep
- C++/Java/Python
- deployment-coder-server
- Keep all kasm

Questions
- Keep all docker templates or kubernetes-deploy only templates


coderintegration.jfrog.io/docker/coder/coder-demo/coder-demo-golang:latest
coderintegration.jfrog.io/docker/coder/coder-demo/coder-demo-node:latest
coderintegration.jfrog.io/docker/coder/coder-demo/coder-demo-java:latest


docker.io/marktmilligan/rstudio:no-args

envbox-vscode-repo -> pod-vscode-repo -> pod-jfrog-vscode-repo
k8s-jetbrains-repo -> pod-jetbrains-repo -> pod-jfrog-jetbrains-repo
k8s-vscode-repo -> pod-jfrog-oauth

Kubernetes Secret (.dockerconfigjson)
{
  "auths": {
    "https://coderintegration.jfrog.io": {
      "username": "jullian@coder.com",
      "password": "cmVmdGtuOjAxOjE3Mjc0OTg3MjM6dXczWjJ1SkhvWnF0QUdodDE1cnlCNDhITW9R",
      "email": "jullian@coder.com",
      "auth": "anVsbGlhbkBjb2Rlci5jb206Y21WbWRHdHVPakF4T2pFM01qYzBPVGczTWpNNmRYY3pXakoxU2todlduRjBRVWRvZERFMWNubENORGhJVFc5Ug=="
    }
  }
}

kubectl create secret -n coder docker-registry jfrog-secret \
--docker-username=jullian@coder.com \
--docker-password=cmVmdGtuOjAxOjE3Mjc0OTg3MjM6dXczWjJ1SkhvWnF0QUdodDE1cnlCNDhITW9R \
--docker-server=https://coderintegration.jfrog.io