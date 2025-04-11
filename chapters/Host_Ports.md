
# Host Ports

So far, we've successfully deployed applications like NGINX within our Kubernetes cluster using Deployments and ReplicaSets. We know the cluster is managing our desired number of application instances, or pods. However, these pods are currently running in isolation, accessible only within the cluster's internal network. If you tried to access the NGINX welcome page from your web browser, you wouldn't be able to reach it. We need a way to bridge the gap between the outside world (even if that's just your local machine) and the pods running inside Kubernetes.

## Making Our Application Accessible

The fundamental goal is to direct network traffic from outside the cluster to a specific port on one or more of our running pods. Kubernetes offers several ways to achieve this, each with its own characteristics and use cases. We'll start with one of the simplest, yet most limited, methods: using a `hostPort`.

## Introducing Host Ports

Think back to how you might expose a port when running a single Docker container. You often used the `-p` flag, like `docker run -p 8080:80 nginx`. This command maps port 8080 on your host machine (the machine running Docker) to port 80 inside the NGINX container.

A `hostPort` in Kubernetes works in a very similar way. It directly maps a specific port number on the *Kubernetes Node* (the virtual or physical machine where the pod is actually scheduled and running) to a specific port on the pod itself.

## Configuring Host Ports in a Deployment

Let's modify our NGINX Deployment definition to use a `hostPort`. The change happens within the `spec.template.spec.containers` section, specifically under the `ports` definition for our NGINX container.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment-hostport
spec:
  replicas: 1 # Start with one replica for simplicity
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80 # The port NGINX listens on inside the pod
          hostPort: 8080   # The port we want to open on the Node's IP address
```

In this updated YAML, we've added the `hostPort: 8080` line alongside `containerPort: 80`. This tells Kubernetes: "If you schedule a pod from this template onto a Node, please map port 8080 on that Node's network interface directly to port 80 inside the NGINX container within that pod."

## Accessing the Application via Host Port

If you're using `microk8s`, your local machine *is* the Kubernetes Node. This makes testing `hostPort` very convenient.

First, apply this updated Deployment manifest:
```bash
kubectl apply -f your-nginx-deployment-hostport.yaml
```
*(Replace `your-nginx-deployment-hostport.yaml` with the actual filename)*

Once the pod is running, Kubernetes will configure the networking on the Node (your machine) to forward traffic arriving on port 8080 to the pod's port 80. You should now be able to open your web browser and navigate to `http://localhost:8080` or use `curl`:

```bash
curl http://localhost:8080
```

You should see the default NGINX welcome page! The `hostPort` successfully exposed our application.

## The Drawbacks of Host Ports

While `hostPort` provides a quick way to access a pod, it comes with significant limitations, making it unsuitable for most production scenarios.

The most immediate problem is **port conflicts**. A `hostPort` claims a specific port number *on the Node*. What happens if you try to schedule a *second* NGINX pod using the same `hostPort: 8080` onto the *same Node*? Kubernetes cannot map port 8080 on the Node to two different pods simultaneously. The second pod will fail to schedule correctly on that Node because the required host port is already in use. This severely limits scalability, as you can only run one pod instance per Node for any given `hostPort`.

Furthermore, in a multi-node cluster, you would need to know the specific IP address of the Node where your pod happened to be scheduled to access it. Accessing via `localhost` only works in single-node setups like `microk8s`. This doesn't provide a stable or predictable way to access your application if pods can move between nodes or if you scale up.

Finally, `hostPort` offers no load balancing. If you had multiple replicas running on different nodes (each potentially needing a *different* `hostPort` if they used the same port number, or different port numbers if they used the same `hostPort`), you would have no built-in mechanism to distribute traffic evenly among them.

## Moving Towards Better Solutions

Host ports offer a basic, direct mapping similar to Docker's port publishing. They are simple to understand and configure, and useful for specific niche cases or quick local testing, especially with single-node clusters like `microk8s`.

However, the limitations – particularly port conflicts and the lack of scalability and load balancing – make them impractical for real-world, scalable applications. We need a more sophisticated mechanism provided by Kubernetes itself. This is where Kubernetes Services come in. In the next chapter, we'll explore Services, starting with the `LoadBalancer` type, which addresses these shortcomings and provides a much more robust way to expose our applications.
