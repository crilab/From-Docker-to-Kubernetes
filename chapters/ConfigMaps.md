
# ConfigMaps

In our previous exploration, we saw how PersistentVolumeClaims (PVCs) allow our Pods to request and use persistent storage for application data – information that needs to survive even if the Pod itself is restarted or replaced. However, not all data fits this description. Often, applications need configuration settings: things like database connection strings, API endpoints, logging levels, or feature flags. While you *could* bake these into your container image or store them in a persistent volume, Kubernetes offers a more elegant and flexible solution specifically for configuration data: ConfigMaps.

## Configuration Beyond Volumes

Think of Persistent Volumes and Claims as the durable hard drives for your application's stateful data. ConfigMaps, on the other hand, are more like handy text files or environment variables containing settings that tell your application *how* to run. Storing configuration separately from your application code (the container image) is a best practice. It allows you to change settings without rebuilding the image, and you can use the same image in different environments (like development, staging, and production) simply by providing different ConfigMaps.

ConfigMaps are Kubernetes objects designed specifically to hold non-sensitive configuration data in key-value pairs. The values can be simple strings or the contents of entire configuration files.

## Defining Configuration Data

Creating a ConfigMap is straightforward using a YAML manifest. You define the `kind` as `ConfigMap`, give it a `name`, and then specify the configuration data under the `data` field. Each entry under `data` is a key-value pair. The key will often represent a filename or a variable name, and the value holds the actual configuration string.

Let's create a simple ConfigMap containing a couple of configuration settings.

```yaml
# my-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-app-config # Name of our ConfigMap
data:
  # Key: app.properties (will become filename)
  app.properties: |
    greeting=Hello Kubernetes!
    log_level=debug
  # Another key-value pair
  extra.setting: "enabled"
```

Here, we've defined a ConfigMap named `my-app-config`. It contains two key-value pairs under `data`. The first key is `app.properties`, and its value is a multi-line string representing the content of a typical properties file. The second key is `extra.setting` with a simple string value.

## Injecting Configuration into Pods

Once a ConfigMap is created in your cluster, you need a way for your Pods to access this data. The most common method is to mount the ConfigMap data as files into the container's filesystem. Kubernetes cleverly handles this by making each key in the ConfigMap's `data` section appear as a file within a specified directory inside the container. The filename matches the key, and the file content matches the value associated with that key.

Another way (which we won't detail here) is to expose ConfigMap entries as environment variables directly within the container. Mounting as files is often preferred for configuration files, as it keeps the application code standard – it just reads files from expected locations.

## Example: Mounting Configuration as a File

Let's put this into practice. We'll use the `my-app-config` ConfigMap we defined above and mount its contents into a simple Ubuntu container.

First, apply the ConfigMap definition to your cluster:

```bash
kubectl apply -f my-configmap.yaml
```

Next, define a Deployment that uses the `ubuntu` image and mounts our ConfigMap.

```yaml
# ubuntu-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ubuntu-config-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ubuntu-test
  template:
    metadata:
      labels:
        app: ubuntu-test
    spec:
      containers:
      - name: ubuntu-container
        image: ubuntu
        command: ["sleep", "3600"]
        # Define where to mount the volume inside the container
        volumeMounts:
        - name: config-volume # Must match the volume name below
          mountPath: /etc/myconfig # Directory inside the container
      # Define the volume based on our ConfigMap
      volumes:
      - name: config-volume # Name for the volume within this Pod
        configMap:
          # Specify the name of the ConfigMap to use
          name: my-app-config
```

Let's break down the key parts of the Deployment YAML related to the ConfigMap:

1.  **`volumes`**: We define a volume named `config-volume`. Instead of using a `persistentVolumeClaim`, we specify `configMap` and provide the `name` of the ConfigMap we created (`my-app-config`).

2.  **`volumeMounts`**: Inside the container definition, we specify a `volumeMount`. We give it the `name` `config-volume` (linking it to the volume definition) and set the `mountPath` to `/etc/myconfig`. This tells Kubernetes to make the contents of the `config-volume` (which comes from our ConfigMap) available inside the container at the `/etc/myconfig` directory.

Now, apply the Deployment manifest:

```bash
kubectl apply -f ubuntu-deployment.yaml
```

Once the Pod is running, let's verify that our configuration files are present. First, find the name of the Pod created by the Deployment:

```bash
kubectl get pods -l app=ubuntu-test
```

Copy the Pod name (it will look something like `ubuntu-config-test-xxxxxxxxxx-yyyyy`). Now, execute a command inside that Pod to list the contents of the mount directory and view one of the files:

```bash
# Replace <your-pod-name> with the actual name
POD_NAME=$(kubectl get pods -l app=ubuntu-test -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD_NAME -- ls /etc/myconfig
kubectl exec $POD_NAME -- cat /etc/myconfig/app.properties
```

You should see `app.properties` and `extra.setting` listed by the `ls` command. The `cat` command should output:

```
greeting=Hello Kubernetes!
log_level=debug
```

Success! Kubernetes took the keys (`app.properties`, `extra.setting`) from our `my-app-config` ConfigMap and mounted them as files with corresponding content inside the specified directory (`/etc/myconfig`) within our Ubuntu container.

## When to Use ConfigMaps

ConfigMaps are the go-to solution for managing non-sensitive application configuration in Kubernetes. They allow you to:

*   Keep configuration separate from container images.

*   Update configuration without rebuilding or redeploying your application image (though Pods usually need restarting to pick up changes mounted as files).

*   Maintain consistent application images across different environments by simply applying environment-specific ConfigMaps.

Remember that ConfigMaps are intended for configuration data, not sensitive information like passwords or API keys. For secrets, Kubernetes provides a similar but distinct object called, unsurprisingly, `Secret`, which we will explore later. For application data that needs to persist and might be large, PersistentVolumeClaims remain the appropriate choice. ConfigMaps excel at handling those crucial settings that tailor your application's behaviour.
