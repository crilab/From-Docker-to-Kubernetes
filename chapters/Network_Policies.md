
# Network Policies

In the previous chapter, we explored how Services, specifically the ClusterIP type, allow pods within our Kubernetes cluster to discover and communicate with each other reliably using internal DNS names. We saw how an application pod could easily connect to a database pod via the database's Service name. However, this ease of communication comes with a consideration: by default, any pod within the cluster could potentially connect to that database Service, or indeed, any other Service. While convenient during development, this open network model isn't ideal for production environments where security is paramount. We need a way to control *which* pods are allowed to talk to *which* other pods. This is where Network Policies come into play.

## Securing Internal Communication

Think of your Kubernetes cluster as a small town. Services like ClusterIP provide addresses (like `database-service.default.svc.cluster.local`) so different buildings (pods) can find each other. Without any specific rules, anyone in town can walk up to any building's door. Network Policies act like security guards or locked doors for specific buildings. They allow you to define rules stating who is allowed to approach and interact with a particular set of pods.

Network Policies function as a sort of firewall within the Kubernetes cluster network itself. They operate at Layer 3 and 4 (IP address and port), filtering traffic before it even reaches the target pod. It's important to note that Network Policies are implemented by the network plugin installed in your cluster (like Calico, Cilium, or Weave Net). If your cluster's network plugin doesn't support Network Policies, creating these policy resources will have no effect. However, most modern Kubernetes environments utilize plugins that do support them.

By default, if no Network Policies select a particular pod, that pod can receive traffic from anywhere within the cluster and send traffic anywhere. The moment you apply a Network Policy that selects a pod, the rules change: only the traffic explicitly allowed by that policy (and potentially others that also select the pod) will be permitted. Everything else is denied.

## Defining Network Rules

Creating a Network Policy involves defining a few key components:

1.  **Pod Selector:** This specifies which pods the policy applies to, typically using labels. Just like Deployments and Services use labels to manage pods, Network Policies use them to identify the pods they should protect.

2.  **Policy Types:** You can define rules for incoming traffic (`Ingress`), outgoing traffic (`Egress`), or both. An `Ingress` rule controls traffic *to* the selected pods, while an `Egress` rule controls traffic *from* the selected pods.

3.  **Rules:** These specify what traffic is allowed. For an `Ingress` rule, you define which sources are permitted (e.g., pods with specific labels, pods in specific namespaces, or traffic from certain IP address ranges) and often which destination ports on the target pods are accessible.

We will focus on a simple `Ingress` policy to control traffic flowing *into* a set of pods.

## An Example: Filtering Nginx Traffic

Let's illustrate this with a practical scenario. We'll deploy a standard Nginx web server pod and expose it internally using a ClusterIP Service. Then, we'll apply a Network Policy that dictates that these Nginx pods should *only* accept incoming traffic on the standard HTTP port (port 80). Finally, we'll use another pod to test connectivity, proving that traffic to port 80 succeeds while traffic to any other port is blocked.

### Deploying Nginx with a Service

First, we need our Nginx deployment and the ClusterIP service to give it a stable internal DNS name.

Here is the Deployment manifest, `nginx-deployment.yaml`:

```yaml
# nginx-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-nginx-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-server # Label used by Deployment and Service
  template:
    metadata:
      labels:
        app: nginx-server # Label applied to pods
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80 # Nginx listens on port 80
```

And the Service manifest, `nginx-service.yaml`:

```yaml
# nginx-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: my-nginx-service # The internal DNS name will be based on this
spec:
  type: ClusterIP # Internal-only service
  selector:
    app: nginx-server # Selects pods with this label
  ports:
  - protocol: TCP
    port: 80 # Service listens on port 80
    targetPort: 80 # Forwards traffic to container port 80
```

Apply these using `kubectl apply -f nginx-deployment.yaml` and `kubectl apply -f nginx-service.yaml`. Now, any pod in the cluster can theoretically reach Nginx via `my-nginx-service` on port 80.

### Creating the Network Policy

Next, we define the Network Policy to restrict access. Save this as `nginx-netpol.yaml`:

```yaml
# nginx-netpol.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-http-to-nginx
spec:
  podSelector:
    matchLabels:
      app: nginx-server # Apply this policy ONLY to pods with this label
  policyTypes:
  - Ingress # This policy defines rules for INCOMING traffic
  ingress:
  - from: [] # Allow traffic from ANY source (pod/namespace) within the cluster...
    ports:
    - protocol: TCP
      port: 80 # ... ONLY if it's targeting TCP port 80
```

Let's break this down:

*   `podSelector`: Selects the pods managed by our `my-nginx-deployment` because they share the `app: nginx-server` label.

*   `policyTypes`: Specifies that this policy concerns `Ingress` (incoming) traffic.

*   `ingress`: Defines the allowed incoming rules.

    *   `from: []`: An empty `from` usually means allowing traffic from all sources within the cluster *that match the port rule*. If we wanted to restrict based on source pod labels or namespaces, we would specify selectors here.

    *   `ports`: Specifies that only traffic destined for TCP port 80 is allowed.

Apply this policy: `kubectl apply -f nginx-netpol.yaml`. Now, the firewall rule is active for our Nginx pod(s).

### Testing Access

To test our policy, we need another pod from which we can initiate network connections. A simple Ubuntu pod is perfect for this. We can launch one temporarily:

```bash
kubectl run ubuntu-client --image=ubuntu:latest -- sleep infinity
```

This command creates a pod named `ubuntu-client` that will run indefinitely. Now, let's get a shell inside this pod:

```bash
kubectl exec -it ubuntu-client -- bash
```

Inside the pod's shell, we first need to install tools for making web requests (`curl`) and basic network testing (`telnet`, part of `inetutils-tools`).

```bash
# Inside the ubuntu-client pod's shell
apt-get update && apt-get install -y curl inetutils-telnet
```

#### Verifying Allowed Traffic

Now, try accessing the Nginx service on the allowed port (80):

```bash
# Inside the ubuntu-client pod's shell
curl my-nginx-service
```

You should see the default Nginx "Welcome to nginx!" HTML page. This connection works because it targets port 80, matching the rule defined in our `NetworkPolicy`.

#### Verifying Denied Traffic

Let's try accessing the Nginx service on a different port, for example, port 443 (HTTPS) or any other arbitrary port like 81. Since Nginx isn't configured for HTTPS and isn't listening on port 81, we wouldn't expect a successful *application-level* connection anyway. However, the Network Policy should block the connection attempt *before* it even reaches the Nginx pod. We can use `telnet` which tries to establish a basic TCP connection.

```bash
# Inside the ubuntu-client pod's shell

# Try port 443
telnet my-nginx-service 443

# Try port 81
telnet my-nginx-service 81
```

In both cases, the `telnet` command will likely hang for a while and eventually time out. You won't see a "Connected to..." message. This demonstrates that the Network Policy is actively blocking traffic to any port other than 80 on the pods labeled `app: nginx-server`.

Once you're done testing, you can exit the pod's shell (`exit`) and delete the temporary client pod: `kubectl delete pod ubuntu-client`.

## The Power of Selectors

This example highlights the fundamental mechanism of Network Policies: using label selectors (`podSelector`) to target specific pods and defining rules (`ingress`, `egress`, `ports`, `from`) to dictate allowed traffic patterns. While we used a simple port-based rule and allowed traffic from any source, you can create much more granular policies. You could, for instance, create a policy allowing only pods with a specific label (e.g., `role: frontend`) to access pods labeled `role: backend`, or restrict access based on namespaces, effectively segmenting your cluster network.

## Conclusion

Network Policies are an essential tool for securing your Kubernetes applications. By moving beyond the default allow-all internal network model, you can implement the principle of least privilege at the network level. They allow you to define precise rules about which components can communicate, significantly reducing the potential attack surface within your cluster. While our example focused on a basic ingress rule, understanding this foundation opens the door to creating sophisticated network segmentation and security postures tailored to your application's specific needs. They transform the cluster from an open town square into a city with secure buildings and controlled access points.
