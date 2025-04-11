
# Single-Container Pods

In the Docker world, the fundamental unit you interact with is the container. You build images, and you run containers from those images. Kubernetes introduces a slightly different concept as its most basic building block: the **Pod**.

## Understanding the Pod

Think of a Pod as a wrapper around one or more containers. It's the smallest and simplest unit that you create or deploy in Kubernetes. While a Docker container runs a single process (or sometimes more, though often discouraged), a Kubernetes Pod provides a unique environment for its container(s).

Crucially, all containers within the *same* Pod share the same network namespace. This means they share an IP address and port space – they can communicate with each other using `localhost`. They can also share storage volumes. Imagine a Pod as a tiny, dedicated virtual machine or host specifically designed to run a group of tightly coupled containers that need to work closely together.

For now, we'll focus on the most common scenario: a Pod running just a single container. In this simple case, the Pod acts primarily as that wrapper, providing the runtime environment managed by Kubernetes. You don't directly manage containers in Kubernetes; you manage Pods that *contain* the containers.

## Imperative Pod Management

Just like you can run Docker containers directly from the command line, you can create Kubernetes Pods using imperative commands with `kubectl`, the Kubernetes command-line tool. This is often useful for quick tests, debugging, or learning.

Let's create a simple Pod running the familiar `ubuntu` image. We need to give the container something to do so it doesn't exit immediately; `sleep infinity` is a common trick for this.

```bash
kubectl run my-ubuntu-pod --image=ubuntu -- sleep infinity
```

This command tells Kubernetes: `run` a new object, name it `my-ubuntu-pod`, use the `ubuntu` image for its primary container, and run the command `sleep infinity` inside that container.

Kubernetes receives this instruction and works to make it happen. You can check the status:

```bash
kubectl get pods
```

This will list the Pods in your current Kubernetes context, and you should see `my-ubuntu-pod` likely in a `Running` state after a short while.

To get more details about the Pod, similar to `docker inspect`, you can use `describe`:

```bash
kubectl describe pod my-ubuntu-pod
```

This provides a wealth of information, including the Pod's IP address, the container image used, any events related to its lifecycle (like pulling the image or starting the container), and more.

Need to run a command inside the running container, like `docker exec`? Use `kubectl exec`:

```bash
# Get an interactive shell inside the Pod's container
kubectl exec -it my-ubuntu-pod -- bash
```

Once you're inside, you're in the Ubuntu container environment running within the Pod. Type `exit` to leave the shell.

Finally, to remove the Pod, similar to `docker rm`:

```bash
kubectl delete pod my-ubuntu-pod
```

Kubernetes will then terminate the container and remove the Pod resource.

## Declarative Configuration with YAML

Imperative commands are great for immediacy, but they don't scale well. How do you track what you've deployed? How do you easily recreate the exact same setup? How do you collaborate with others on configuration? This is where the declarative approach shines.

In Kubernetes, the standard practice is to define the desired state of your resources in YAML files. You tell Kubernetes *what* you want, and Kubernetes figures out *how* to achieve it. This configuration can be stored in version control (like Git), reviewed, and applied consistently.

Let's define the same Ubuntu Pod using a YAML manifest. Create a file named `ubuntu-pod.yaml`:

```yaml
# ubuntu-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-ubuntu-pod-yaml # Using a different name to avoid conflict
spec:
  containers:
  - name: ubuntu-container # A name for the container within the Pod
    image: ubuntu
    command: ["sleep"]
    args: ["infinity"]
```

Let's break this down:

*   `apiVersion: v1`: Specifies the Kubernetes API version to use for creating this object. Core objects like Pods often use `v1`.

*   `kind: Pod`: Specifies the type of Kubernetes object we want to create.

*   `metadata`: Contains data that helps uniquely identify the object, like its `name`.

*   `spec`: This is the most important part – it defines the *desired state* of the Pod.

*   `containers`: A list of containers to run within the Pod (here, just one).

    *   `name`: A name for the container itself (useful within the Pod's definition).

    *   `image`: The Docker image to use.

    *   `command` and `args`: Specify the command to run in the container, overriding the image's default.

Instead of `kubectl run`, you use `kubectl apply` to create (or update) resources from a file:

```bash
kubectl apply -f ubuntu-pod.yaml
```

Kubernetes reads the file, understands you want a Pod named `my-ubuntu-pod-yaml` configured as specified, and creates it. You can verify with `kubectl get pods`.

If you wanted to change something (perhaps the image, though direct Pod updates are often discouraged in favour of higher-level objects we'll see later), you would modify the YAML file and run `kubectl apply -f ubuntu-pod.yaml` again. Kubernetes would compare the new desired state in the file with the current state and make the necessary changes.

To delete the Pod defined in the file, you can use:

```bash
kubectl delete -f ubuntu-pod.yaml
```

## Choosing Your Approach: Imperative vs. Declarative

When should you use `kubectl run` versus `kubectl apply`?

*   **Imperative (`run`, `delete pod ...`)**: Best for learning, quick experiments, debugging sessions (`kubectl exec`), and simple, one-off tasks. It's fast and direct.

*   **Declarative (`apply -f`, `delete -f`)**: The preferred method for managing applications in development, testing, and production. It enables:

    *   **Version Control:** Store your configurations in Git.

    *   **Repeatability:** Easily recreate environments.

    *   **Auditing:** Track changes to configurations.

    *   **Collaboration:** Teams can work on shared configuration files.

    *   **Complexity:** Manage intricate setups that would be unwieldy with command-line flags.

While you might start with imperative commands to explore, you should aim to use declarative YAML manifests for anything intended to persist or be reproduced.

Pods are the fundamental execution unit in Kubernetes, wrapping your containers. While you can manage them directly, especially using declarative YAML, you'll soon discover higher-level Kubernetes objects like Deployments and Services that manage Pods for you, providing essential features like scaling and self-healing. But understanding the Pod is the crucial first step.
