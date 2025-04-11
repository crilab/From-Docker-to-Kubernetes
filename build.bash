#!/bin/bash -xe

mkdir -p output
docker run \
    -v "./chapters:/chapters:ro" \
    -v "./output:/output" \
    pandoc/latex \
    /chapters/Introduction.md \
    --table-of-contents \
    --highlight-style=tango \
    --output /output/From_Kubernetes_to_Docker.html \
    --standalone
