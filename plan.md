% From Docker to Kubernetes
% Christian Åberg

# Single-Container Pods

Assume the user has a basic understanding of Docker and is now looking to learn Kubernetes.

Start by explaining the fundamentals of Pods in Kubernetes and how they compare to Docker containers.

Then, explain how to manage Pods (using the Ubuntu image) through imperative commands.

Next, transition to the declarative approach using YAML manifests.

Conclude by reflecting on when it’s better to use imperative commands versus declarative configuration.

# ReplicaSets

<previous_chapter>User learned how to manage pods (using ubuntu image) through imperative and declerative commands</previous_chapter>

Start by explaining the fundamentals of ReplicaSets in Kubernetes and what they do.

Explain how ReplicaSets help with maintaining high availability for example webservers (image nginx) but point out LoadBalancer will be covered in later chapters.

You decide how to go further in the chapter (but make sure the user gets al least one example of how to create one)...

# Deployments

IN THE PREVIOUS CHAPTER, the user created a ReplicaSet of NGINX instances and manually deleted pods to observe how the ReplicaSet automatically recreated them.

This chapter introduces Deployments and explains how they differ from ReplicaSets. It builds upon the concepts covered in the previous chapter.

# Host Ports

In previous chapters, the reader has been introduced to ReplicaSet and Deployment of NGINX (DockerHub image), but these have not yet been exposed to the network.

This chapter introduces hostPorts as the first mechanism to expose pods to a network.

The reader is expected to use microk8s for labs, so hostPort will be accessible via http://localhost.

Highlight limitations and point out thats why introduce LoadBalancer in the next chapter.

You must decide how to structure this chapter.

# Load Balancers

In the previous chapter, the reader learned how to expose deployments (NGINX from DockerHub) via HostPort. That chapter concluded by highlighting HostPort limitations, leading into this one.

This chapter introduces the concept of `Kind: Service`, noting that there are several types, with a focus on `LoadBalancer`.

Assume the reader is using a local MicroK8s setup with MetalLB enabled (IP range: 127.0.0.2–127.0.0.200).

Create a new deployment before creating the LoadBalancer.

Add a section explaining how public clouds handle the LoadBalancer service differently from the microk8s setup.

You must decide how to structure this chapter.

# PersistentVolumeClaims

Provide a basic explanation of:
- StorageClass
- PersistentVolume
- PersistentVolumeClaim

Indicate which resources are created by end-users and which are managed by public cloud platforms.

Assume the user is running MicroK8s with the hostpath-storage add-on. Explain how to create a pod (using the Ubuntu image from Docker Hub) with a volume mounted at a generic path like:

/mnt/my-volume

Also note that hostpath-storage is not suitable for production environments. Provide an example of how the lab can be adapted for a public cloud platform.

You must decide how to structure this chapter.

# ConfigMaps

In previous chapter the user was introduced to PVC.

This chapter will introduce ConfigMaps as an alternative to volumes for storing configuration data.

Provide an example where you create a ConfigMap with some example text and mount it to a specific path on a Ubuntu (Docker Hub) deployment.

You must decide how to structure this chapter.

# Secrets

In the previous chapter the user was introduced to ConfigMaps.

This chapter introduces Secrets as an alternative for storing sesetive data.

Provide an example where you create a Secret with some example text and attach is as an environment variable (Ubuntu from Docker Hub). But also point out they (like ConfigMaps) can be attached like files.

You must decide how to structure this chapter.

# ClusterIP

In previous chapters, the user set up NGINX (Docker Hub) and exposed it externally using LoadBalancer. We have not yet touched on Inter-Pod Communication.

In this chapter, introduce ClusterIP.

Provide a basic lab where you create a mysql (Docker Hub) that you expose with ClusterIP. Then create a Ubuntu pod (Docker Hub), install mysql-client and verify the connection.

You must decide how to structure this chapter.

# Network Policies

In the previous chapter, the reader was introduced to ClusterIP as means of communicate with a database using DNS, but the communication was unfiltered.

Introduce the reader to network policies.

Provide an example where you set up nginx (Docker Hub) with a ClusterIP. Apply a minimalistic filter that only allows HTTP. Then create an ubuntu pod (Docker Hub) to verify the connection. Then change the port to see the connection is declined.

You must decide how to structure this chapter.

<!--

% From Docker to Kubernetes
% Christian Åberg

Create the chapter (Heading 1) specified by the user.

Maintain a fluent, pedagogical tone.

Plan a clear heading structure to eliminate the need for bullet points or numbered lists.

Maintain a fluent, pedagogical tone with oversimplifications to keep the text clean.

 -->
