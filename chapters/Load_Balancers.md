
# Load Balancers

In the previous chapter, we explored exposing applications running inside our Kubernetes cluster using `HostPort`. This method directly maps a port on the host machine (our Node) to a port on a specific Pod. While simple for a quick test, we saw its limitations. Relying on `HostPort` can lead to port conflicts if multiple Pods try to use the same host port, and it ties traffic directly to specific Nodes, making scaling and resilience difficult. We need a more robust and flexible way to connect users to our applications.

## Beyond HostPort: The Need for Services

Imagine you have multiple identical copies (Pods) of your web application running for reliability and to handle more traffic. How do you distribute incoming user requests evenly across these Pods? Furthermore, Pods in Kubernetes are ephemeral; they can be created, destroyed, and rescheduled onto different Nodes at any time. Their IP addresses change frequently. Trying to connect directly to constantly changing Pod IPs is impractical.

We need a stable network endpoint – a consistent address and port – that represents our application, regardless of how many Pods are running or where they are located within the cluster. This is precisely the problem Kubernetes Services solve.

## Introducing the Service Resource

Kubernetes provides a dedicated resource object, `Kind: Service`, designed specifically for network abstraction. A Service acts as an internal load balancer and stable endpoint for a set of Pods. It defines a logical set of Pods (usually based on labels) and a policy for accessing them.

Kubernetes offers several types of Services, each suited for different use cases. You might encounter `ClusterIP` (for internal-only access), `NodePort` (exposing on each Node's IP), and `ExternalName` (mapping to an external DNS name). For making our applications accessible from *outside* the cluster, especially in a way that mimics production environments, the `LoadBalancer` type is often the preferred choice. We will focus on this type here.

## Setting Up a Sample Application

Before we can expose anything, we need an application running. Let's create a new, simple Deployment. Instead of NGINX this time, we'll use the standard Apache HTTP Server (`httpd`) image, which also serves a basic web page on port 80.

Save the following YAML definition to a file named `apache-deployment.yaml`:

```yaml
# apache-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: apache-webserver
spec:
  replicas: 2 # Start with two instances
  selector:
    matchLabels:
      app: apache # Pods managed by this deployment must have this label
  template:
    metadata:
      labels:
        app: apache # Apply this label to the Pods
    spec:
      containers:
      - name: httpd-container
        image: httpd:latest # Use the official Apache image
        ports:
        - containerPort: 80 # The Apache server listens on port 80 inside the container
```

Notice the `labels` section under `template.metadata`. We've tagged our Pods with `app: apache`. This label is crucial because it's how our Service will identify which Pods belong to it. The `selector.matchLabels` in the Deployment ensures it manages Pods with this label, and we'll use the same label in our Service definition.

Apply this Deployment to your cluster:

```bash
kubectl apply -f apache-deployment.yaml
```

You can verify that two Pods are running:

```bash
kubectl get pods -l app=apache
```

## Creating a LoadBalancer Service

Now, let's create a Service of type `LoadBalancer` to expose our `apache-webserver` Deployment externally.

Save the following YAML definition to a file named `apache-service.yaml`:

```yaml
# apache-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: apache-loadbalancer
spec:
  selector:
    app: apache # Find Pods with this label
  ports:
    - protocol: TCP
      port: 8080    # The port the Service will be exposed on externally
      targetPort: 80 # The port the container is listening on (inside the Pod)
  type: LoadBalancer # Request an external load balancer
```

Let's break down the `spec` section:

*   `selector`: This tells the Service which Pods to send traffic to. It looks for Pods that have the label `app: apache`, perfectly matching the Pods created by our Deployment.

*   `ports`: This defines the port mapping.

    *   `port: 8080`: This is the port that the Service itself will listen on. Users outside the cluster will connect to the LoadBalancer's IP address on this port.

    *   `targetPort: 80`: This specifies the port on the Pods (defined in our Deployment's `containerPort`) where the traffic should be forwarded. So, traffic hitting the Service on port 8080 gets sent to a selected Pod on port 80.

*   `type: LoadBalancer`: This is the key instruction. We are asking Kubernetes to provision an external load balancer for this Service.

Apply this Service definition:

```bash
kubectl apply -f apache-service.yaml
```

## How the LoadBalancer Works Locally

Because you are running MicroK8s with the MetalLB addon enabled, requesting a `LoadBalancer` Service triggers MetalLB. MetalLB acts as a network load balancer implementation for bare-metal or local Kubernetes clusters that don't have a native cloud provider load balancer.

When you created the `apache-loadbalancer` Service, MetalLB automatically assigned it an IP address from the pool you configured (127.0.0.2–127.0.0.200 in this case). This IP address acts as the stable external endpoint for your Apache application.

To find this external IP address, use the `kubectl get service` command:

```bash
kubectl get service apache-loadbalancer
# Or simply: kubectl get svc apache-loadbalancer
```

You should see output similar to this:

```
NAME                  TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
apache-loadbalancer   LoadBalancer   10.152.183.13   127.0.0.X     8080:3XXXX/TCP   1m
```

Look at the `EXTERNAL-IP` column. This is the IP address assigned by MetalLB (it will be one from your configured range, like 127.0.0.2, 127.0.0.3, etc.). The `PORT(S)` column shows the mapping: `8080` (the external `port`) maps to some internal `NodePort` (which Kubernetes manages automatically when using `LoadBalancer` type) which then routes to the `targetPort` (80) on the Pods.

Now, you can access your Apache web server from your host machine using the assigned `EXTERNAL-IP` and the service `port` (8080):

Open your web browser and navigate to `http://<EXTERNAL-IP>:8080` (replace `<EXTERNAL-IP>` with the actual IP address shown by `kubectl get service`). You should see the default Apache "It works!" page.

Alternatively, you can use `curl` from your terminal:

```bash
curl http://<EXTERNAL-IP>:8080
```

Traffic flows like this: Your request goes to `http://<EXTERNAL-IP>:8080`. MetalLB intercepts this traffic and directs it to the internal Kubernetes Service (`apache-loadbalancer`). The Service, using mechanisms like kube-proxy, selects one of the healthy Pods labeled `app: apache` and forwards the request to port 80 on that Pod.

## Scaling Your Application Seamlessly

Our Deployment currently runs two replicas (`replicas: 2`). What happens if we scale it up? Let's increase the number of Apache Pods to four:

```bash
kubectl scale deployment apache-webserver --replicas=4
```

Wait a few moments for the new Pods to start (`kubectl get pods -l app=apache`). The crucial point is that you don't need to change the `apache-loadbalancer` Service at all!

Because the Service uses the `selector` (`app: apache`), it automatically discovers the new Pods as soon as they are ready, because they inherit the correct label from the Deployment's template. The LoadBalancer will now distribute incoming requests across all four running Pods, improving capacity and resilience without any manual network reconfiguration. This dynamic discovery and load balancing is a core benefit of using Services.

## Load Balancers in the Cloud

It's important to understand how `type: LoadBalancer` behaves differently when you run Kubernetes on a public cloud provider like AWS, Google Cloud (GCP), or Azure.

In those environments, when you create a Service of `type: LoadBalancer`, the cloud provider's specific Kubernetes integration kicks in. Instead of MetalLB assigning an IP from a local range, the cloud provider automatically provisions one of its *native* load balancer resources (e.g., an AWS Elastic Load Balancer, a Google Cloud Load Balancer, or an Azure Load Balancer).

This cloud load balancer is configured to route traffic into your Kubernetes cluster, targeting the appropriate Pods via the Service definition. Crucially, the `EXTERNAL-IP` assigned in a cloud environment is typically a *publicly routable* IP address, making your application accessible over the internet (subject to firewall rules).

So, while the Kubernetes Service definition (`apache-service.yaml`) remains the same, the underlying *implementation* of the load balancer differs significantly between a local MetalLB setup (using local IPs) and a managed cloud environment (using cloud-native load balancers with public IPs).

## Summary: Service Simplicity

We've seen that Kubernetes Services provide a vital abstraction layer for network access. By using a Service of `type: LoadBalancer`, we created a stable external endpoint for our Apache deployment. MetalLB handled the IP address assignment in our local MicroK8s setup, allowing access via a `127.0.0.x` address.

Compared to `HostPort`, the `LoadBalancer` Service offers significant advantages:

*   **No Port Conflicts:** The Service manages its own external port, independent of Node ports.

*   **Scalability:** It automatically discovers and balances traffic across all matching Pods, even as the Deployment scales up or down.

*   **Resilience:** If a Pod or even a Node fails, the Service routes traffic to the remaining healthy Pods.

*   **Cloud Integration:** It provides a standard way to request external load balancers, seamlessly integrating with cloud provider infrastructure when deployed there.

Services, particularly the `LoadBalancer` type, are the standard and much more robust way to expose your applications running in Kubernetes compared to the limitations of `HostPort`. They handle the complexities of Pod IPs and scaling, providing a simple and stable access point for users.
