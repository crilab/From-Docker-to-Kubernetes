% From Docker to Kubernetes
% Christian Åberg

# Single-Container Pods

## What is a Pod?
- Definition and purpose of a pod in Kubernetes
- Difference between containers and pods
- Comparison to Docker containers

## Why Use Single-Container Pods?
- Use cases for single-container vs. multi-container pods
- Simplicity and isolation in design

## Creating a Pod with kubectl
- Basic `kubectl run` example (ubuntu)
- Inspecting pod status with `kubectl get pods`
- Viewing logs with `kubectl logs`

## Interacting with a Running Pod
- Executing commands inside a pod (`kubectl exec`)
- Port-forwarding to access services locally (`kubectl port-forward`)

## Understanding Pod Lifecycle
- Phases: Pending, Running, Succeeded, Failed, Unknown
- Pod restarts and termination

## Introduction to Manifests
- What is a Kubernetes manifest?
- YAML syntax overview
- Declarative configuration vs imperative commands

## Creating a Pod with a Manifest
- Writing a simple pod YAML
- Using `kubectl apply -f` to create from a manifest
- Viewing and editing a live manifest (`kubectl edit`)

## Best Practices for Single-Container Pods
- Image versioning
- Resource requests and limits
- Readiness and liveness probes (brief intro)

# ReplicaSets

# Deployments

# Services

# Load Balancers

# Health Checks

# ConfigMaps

# Secrets

# Volumes

# Multi-Container Pods

# ClusterIP

# Network Policies

<!--

- Create the chapter specified by the user.

- Use fluent and pedagogical language throughout.

- Use only the following images in examples:
  - `ubuntu`
  - `nginx`
  - `wordpress`
  - `mysql`

- Assume the user is running Kubernetes locally (e.g., via MicroK8s or Minikube), and adjust network-related explanations accordingly. Clearly point out how behavior differs on real cloud platforms.

 -->
