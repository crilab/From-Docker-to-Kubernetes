#!/bin/bash -xe

mkdir -p output
docker run \
    -v "./chapters:/chapters:ro" \
    -v "./output:/output" \
    pandoc/latex \
    /chapters/Introduction.md \
    /chapters/Single-Container_Pods.md \
    /chapters/ReplicaSets.md \
    /chapters/Deployments.md \
    /chapters/Host_Ports.md \
    /chapters/Load_Balancers.md \
    /chapters/PersistentVolumeClaims.md \
    /chapters/ConfigMaps.md \
    /chapters/Secrets.md \
    /chapters/ClusterIP.md \
    /chapters/Network_Policies.md \
    --table-of-contents \
    --highlight-style=tango \
    --output /output/From_Docker_to_Kubernetes.html \
    --standalone
