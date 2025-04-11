
# Secrets

In the previous chapter, we explored ConfigMaps as a way to manage application configuration separately from our container images. ConfigMaps are excellent for non-sensitive data like application settings or feature flags. But what about sensitive information like database passwords, API keys, or authentication tokens? Storing these directly in ConfigMaps or, even worse, within container images, isn't secure. This is where Kubernetes provides another specialized object: Secrets.

## What Are Secrets?

Think of Secrets as the sibling to ConfigMaps, but designed specifically for confidential data. While ConfigMaps store configuration in plain text, Secrets store their data in a slightly obfuscated way (base64 encoded by default) and are handled with more care by the Kubernetes system.

The primary goal of using Secrets is to decouple sensitive information from your Pod definitions and container images. This makes your applications more secure and easier to manage, as you can update credentials without rebuilding images or changing deployment manifests extensively. Just like ConfigMaps, Secrets allow you to inject this sensitive data into your running containers when needed.

## Creating a Secret

Bringing sensitive data into your Kubernetes cluster involves creating a Secret object. You can do this in several ways, but a common method for simple key-value pairs is using the `kubectl` command-line tool.

Let's create a Secret named `my-api-credentials` containing a fictional API key. We'll use the `kubectl create secret generic` command. This command takes the Secret name and the data you want to store using the `--from-literal` flag.

```bash
kubectl create secret generic my-api-credentials \
  --from-literal=API_KEY='s0m3v3rys3cr3tK3y!'
```

When you run this command, Kubernetes creates a Secret object named `my-api-credentials`. Inside this Secret, there's a data entry with the key `API_KEY` and its corresponding value. Importantly, Kubernetes automatically base64 encodes the value `'s0m3v3rys3cr3tK3y!'` before storing it. You won't see the plain text if you inspect the Secret object directly using `kubectl get secret my-api-credentials -o yaml`, but rather the encoded version.

## Using Secrets in Pods

Just creating a Secret doesn't automatically make it available to your applications. Similar to ConfigMaps, you need to explicitly tell Kubernetes how to expose the Secret's data to your Pods. The two main ways to achieve this are by mounting the Secret data as environment variables or as files within the container's filesystem.

### Secrets as Environment Variables

One straightforward way to consume Secret data is to expose it as environment variables directly within your container. This is particularly useful for applications designed to read credentials or keys from the environment.

Let's create a simple Pod definition that uses the `ubuntu` image and injects the `API_KEY` from our `my-api-credentials` Secret as an environment variable.

```yaml
# pod-with-secret-env.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-env-demo-pod
spec:
  containers:
  - name: ubuntu-container
    image: ubuntu
    command: ["sleep", "3600"]
    env:
    - name: MY_APPLICATION_API_KEY # The env var name inside the container
      valueFrom:
        secretKeyRef:
          name: my-api-credentials # The Secret to use
          key: API_KEY             # The key within the Secret
  restartPolicy: Never
```

In this YAML:

1.  We define an environment variable named `MY_APPLICATION_API_KEY` for the container.

2.  Instead of providing a direct `value`, we use `valueFrom`.

3.  `secretKeyRef` tells Kubernetes to fetch the value from a Secret.

4.  `name: my-api-credentials` specifies which Secret to use.

5.  `key: API_KEY` specifies which key within that Secret holds the value we want.

You can create this Pod using `kubectl apply -f pod-with-secret-env.yaml`. Once the Pod is running, you could exec into it (`kubectl exec -it secret-env-demo-pod -- bash`) and run `printenv | grep MY_APPLICATION_API_KEY` to see that the environment variable is set with the secret value.

### Secrets as Files

Alternatively, you can mount Secrets as files into a volume within your container. This approach mirrors how ConfigMaps can be mounted as files and is often preferred when:

*   An application expects credentials or tokens to be read from specific file paths.

*   You need to mount multiple pieces of sensitive data from a Secret into a single directory.

*   The sensitive data represents a full configuration file itself (like a `.kubeconfig` or an SSL certificate).

The mechanism involves defining a volume in the Pod spec that references the Secret and then mounting that volume into the desired path within the container definition. The keys within the Secret become filenames in the mounted directory, and the corresponding values become the file contents.

## A Note on Security

It is crucial to understand that Kubernetes Secrets are, by default, only base64 encoded, **not encrypted**. Base64 encoding is easily reversible and should not be considered a strong security measure on its own. Anyone with access to the raw Secret object within Kubernetes (via the API or `etcd` datastore) can easily decode the values.

The real security benefits of Secrets come from:

1.  **Separation:** Keeping sensitive data out of application code and images.

2.  **Access Control:** Using Kubernetes Role-Based Access Control (RBAC) to restrict who can read or manage Secret objects.

3.  **System Handling:** Kubernetes can manage the lifecycle and distribution of Secrets more securely than manual methods.

4.  **Integration:** Potential for integration with external secret management systems or enabling encryption-at-rest for the underlying `etcd` datastore.

So, while Secrets provide a dedicated and managed way to handle sensitive information, remember that the default encoding offers minimal protection. Always rely on proper access controls (RBAC) as your primary defense within Kubernetes.

With ConfigMaps for general configuration and Secrets for sensitive data, you now have the essential tools to manage your application's external parameters effectively within Kubernetes.
