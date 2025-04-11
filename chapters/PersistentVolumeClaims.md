
# PersistentVolumeClaims

So far, our journey from Docker to Kubernetes has focused on running applications. However, many applications need to store data persistently. A container's filesystem is ephemeral – when the container stops, any data written inside it is typically lost. Docker introduced volumes to solve this, allowing us to map host directories or managed volumes into containers. Kubernetes offers a more sophisticated and flexible system for managing persistent storage, centered around the concept of `PersistentVolumeClaims`.

## The Need for Persistent Storage

Imagine running a database or a content management system in a Pod. If the Pod crashes or is rescheduled to another node, we need its data to survive. Simply storing data inside the container isn't sufficient because the container's lifecycle is temporary. We need storage that exists independently of any single Pod and can be attached to Pods as needed. This is where Kubernetes persistent storage concepts come into play.

## Requesting Storage with PersistentVolumeClaims

From an application developer's perspective, the primary object they interact with when needing storage is a `PersistentVolumeClaim` (PVC). Think of a PVC as a *request* for storage. When you create a PVC, you specify *how much* storage you need (e.g., 5 Gigabytes) and *how you need to access it* (e.g., read/write access by a single Pod).

You don't need to worry about the underlying storage infrastructure details like which specific disk or network storage system will be used. You simply declare your requirements in the PVC object.

## Fulfilling the Request with PersistentVolumes

Behind the scenes, a `PersistentVolume` (PV) represents an actual piece of storage in the cluster. This could be a physical disk on a node, a network file share (like NFS), or a cloud provider's storage service (like AWS EBS, Google Persistent Disk, or Azure Disk).

A PV has properties like capacity, access modes, and details about the specific storage technology it uses. The crucial point is that the lifecycle of a PV is independent of any Pod using it.

Kubernetes tries to match a user's `PersistentVolumeClaim` (the request) with an available `PersistentVolume` (the actual storage) that meets the specified requirements (size, access mode). This process is called binding. Once a PVC is bound to a PV, that PV is reserved for that specific PVC.

## Defining Storage Types with StorageClasses

Manually creating PVs for every storage need can be cumbersome, especially in large or dynamic environments like public clouds. This is where `StorageClass` comes in. A `StorageClass` provides a way for administrators to define different "classes" or "types" of storage they offer.

Think of a `StorageClass` like a template or a blueprint for creating PVs. It specifies what provisioner should be used (e.g., the AWS EBS provisioner, the GCE PD provisioner, or the `hostpath-storage` provisioner in our lab setup) and any parameters associated with that type of storage (like disk type: SSD vs. HDD, or replication settings).

When a PVC is created, it can optionally specify a `StorageClass`. If it does, and if dynamic provisioning is enabled for that class, the provisioner associated with the `StorageClass` will automatically create a suitable PV to bind to the PVC. This eliminates the need for cluster administrators to pre-provision PVs manually.

## Roles and Responsibilities

In a typical Kubernetes environment, roles are often distributed:

*   **End-Users/Developers:** Primarily create `PersistentVolumeClaims` to request storage for their applications. They also define how their Pods use these claims.

*   **Cluster Administrators/Cloud Providers:** Manage the underlying storage infrastructure. They typically define `StorageClasses` and may sometimes pre-create `PersistentVolumes`. In cloud environments, the cloud provider manages the storage services and provides the necessary `StorageClass` definitions and provisioners.

## A Practical Example with MicroK8s

Let's make this concrete using our MicroK8s environment with the `hostpath-storage` add-on enabled. This add-on automatically creates a default `StorageClass` that provisions `PersistentVolumes` using directories on the host filesystem of the node where the Pod is scheduled.

First, we define our storage request, the `PersistentVolumeClaim`. Create a file named `my-pvc.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-ubuntu-pvc # Name of our storage request
spec:
  accessModes:
    - ReadWriteOnce # Can be mounted read-write by a single node
  resources:
    requests:
      storage: 1Gi # Request 1 Gibibyte of storage
  # We don't specify a storageClassName, so it will use the default
  # provided by the hostpath-storage add-on in MicroK8s.
```

This PVC asks for 1GiB of storage that can be mounted by a single node at a time.

Next, we define a Pod that uses this claim. Create a file named `my-ubuntu-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ubuntu-with-volume
spec:
  volumes:
    - name: my-persistent-storage # An arbitrary name for the volume within this Pod
      persistentVolumeClaim:
        claimName: my-ubuntu-pvc # Must match the name of the PVC we created
  containers:
    - name: ubuntu-container
      image: ubuntu
      command: ["/bin/bash", "-c", "sleep infinity"]
      volumeMounts:
        - mountPath: "/mnt/my-volume" # The path inside the container
          name: my-persistent-storage # Must match the volume name defined above
```

This Pod definition does two crucial things related to storage:

1.  Under `spec.volumes`, it declares a volume named `my-persistent-storage` and specifies that this volume should be sourced from the PVC named `my-ubuntu-pvc`.

2.  Under `spec.containers.volumeMounts`, it tells the `ubuntu-container` to mount the volume named `my-persistent-storage` at the path `/mnt/my-volume` inside the container.

Now, apply these configurations to your MicroK8s cluster:

```bash
microk8s kubectl apply -f my-pvc.yaml
microk8s kubectl apply -f my-ubuntu-pod.yaml
```

Kubernetes will process the PVC. Because we're using `hostpath-storage` and didn't specify a class, the default `StorageClass` will likely be used. A `PersistentVolume` backed by a directory on your MicroK8s node will be automatically created and bound to `my-ubuntu-pvc`. Then, the Pod will be scheduled, and the directory representing the PV will be mounted into the container at `/mnt/my-volume`. Any data written to `/mnt/my-volume` inside the Pod will persist in that directory on the host node, even if the Pod is deleted and recreated (as long as the PVC exists).

## The HostPath Caveat

It is essential to understand that the `hostpath-storage` provisioner used in this MicroK8s lab setup is **not suitable for production environments**, especially multi-node clusters. It ties the storage directly to a specific node's filesystem. If the node fails, the data becomes inaccessible. Furthermore, if the Pod gets rescheduled to a *different* node, it will lose access to its original data, as the host path exists only on the first node. Production environments require more robust storage solutions like network storage (NFS, Ceph) or cloud provider block storage.

## Adapting for Cloud Environments

How would this example change in a public cloud environment like AWS, GCP, or Azure? The Pod definition (`my-ubuntu-pod.yaml`) would remain exactly the same! The beauty of the PVC abstraction is that the application doesn't need to know the specifics of the underlying storage.

The primary change would be in the `PersistentVolumeClaim` definition (`my-pvc.yaml`). Instead of relying on the default `hostpath-storage` class, you would explicitly specify a `StorageClass` provided by your cloud provider.

For instance, if your cloud provider offered a class named `cloud-standard-ssd`, your PVC definition might look like this:

```yaml
# my-cloud-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-ubuntu-pvc # Name can remain the same
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: cloud-standard-ssd # Specify the cloud provider's StorageClass
```

By simply changing the `storageClassName` (or adding it if you previously relied on the default), your application can leverage robust, production-grade cloud storage without altering the application's Pod specification. The cloud provider's storage provisioner, associated with the `cloud-standard-ssd` `StorageClass`, would handle the dynamic creation of the appropriate cloud disk (like an AWS EBS volume or Google Persistent Disk) and make it available as a PV for your PVC.

## Summary

Kubernetes provides a powerful abstraction layer for managing persistent storage. Users request storage via `PersistentVolumeClaims` (PVCs), specifying their needs. These requests are fulfilled by `PersistentVolumes` (PVs), which represent actual storage resources. `StorageClasses` enable administrators to define types of storage and allow for dynamic provisioning of PVs, decoupling applications from the underlying storage infrastructure. This system allows applications to request and use persistent storage consistently, whether running on a local development cluster like MicroK8s or a large-scale production environment in a public cloud.
