
# Network Policies

In our journey exploring how different parts of an application communicate within Kubernetes, we saw how a ClusterIP Service provides a stable internal address, often accessed via DNS. Think back to accessing a database; your application could find the database service simply by using its name. However, this convenience came with a hidden vulnerability: any component inside the cluster could potentially reach that database service. There was no built-in gatekeeper scrutinizing who was trying to connect. This open-door policy isn't ideal for sensitive components like databases. We need a way to enforce rules about which parts of our system can talk to others. This is precisely where Network Policies come into play.

## From Open Access to Controlled Communication

Imagine your Kubernetes cluster as a busy office building. Initially, every office door (representing a Pod or Service) is unlocked. Anyone inside the building can walk into any office. A ClusterIP Service is like putting a nameplate on a specific office door – it helps people find the right office (like the database department), but it doesn't lock the door.

Network Policies act as the security guards and access control systems for this building. They allow you to define rules stating, for example, "Only employees from the 'WebApp' department are allowed into the 'Database' office, and only through the main door (a specific port)." This introduces much-needed security and segmentation within the cluster itself.

## Kubernetes' Internal Firewall

At its core, a Network Policy selects a group of Pods (using labels, our familiar organisational tool) and defines rules for the network traffic allowed *to* (ingress) or *from* (egress) those Pods. Think of it as an internal firewall specifically designed for Kubernetes.

It's important to note that Network Policies aren't magic; they require a network plugin (also known as a CNI plugin) installed in your cluster that actually understands and enforces these rules. Common examples include Calico, Cilium, and Weave Net. Most managed Kubernetes platforms come with a suitable network plugin pre-installed, so you often don't need to worry about this detail, but it's good to be aware of the underlying requirement.

Network Policies operate on a "default deny" principle once applied to a Pod for a specific traffic direction (ingress or egress). If you create *any* Network Policy that selects a Pod for ingress traffic, then *only* the ingress traffic explicitly allowed by *at least one* policy will be permitted. All other incoming traffic is blocked by default. The same logic applies independently to egress traffic. If no policy selects a Pod, its traffic remains unaffected (usually meaning all traffic is allowed, depending on the network plugin's default).

## Example: Securing a MySQL Database

Let's make this concrete. We'll set up a MySQL database inside our cluster, expose it using a ClusterIP Service, and then create a Network Policy to ensure only specific application Pods can access it on the standard MySQL port.

### Setting Up the MySQL Pod

First, we need a Deployment to run our MySQL container. We'll use the official MySQL image from Docker Hub. Crucially, we assign a label (`app: mysql`) to the Pods created by this Deployment. This label is how we'll identify these Pods later in our Service and Network Policy.

```yaml
# mysql-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql # Selects Pods managed by this Deployment
  template:
    metadata:
      labels:
        app: mysql # The label applied to the Pods
    spec:
      containers:
      - name: mysql
        image: mysql:8.0 # Using MySQL 8.0 image
        env:
        - name: MYSQL_ALLOW_EMPTY_PASSWORD # For simplicity in example ONLY!
          value: "yes"                   # DO NOT use in production!
        ports:
        - containerPort: 3306 # Standard MySQL port
```

We apply this manifest:

```bash
kubectl apply -f mysql-deployment.yaml
```

This command creates the Deployment, which in turn starts a Pod running the MySQL container. Remember, using `MYSQL_ALLOW_EMPTY_PASSWORD` is insecure and only suitable for a quick demonstration like this.

### Creating the Internal Endpoint

Next, we create a ClusterIP Service to give our MySQL Pod a stable internal IP address and DNS name. The Service uses a selector (`app: mysql`) to find the Pod(s) it should route traffic to – in this case, the MySQL Pod we just created.

```yaml
# mysql-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-service # The DNS name will be based on this
spec:
  type: ClusterIP # Internal-only IP
  selector:
    app: mysql # Routes traffic to Pods with this label
  ports:
  - protocol: TCP
    port: 3306       # Port the Service listens on
    targetPort: 3306 # Port on the Pod to forward traffic to
```

We apply this manifest:

```bash
kubectl apply -f mysql-service.yaml
```

Now, other Pods within the cluster can theoretically reach MySQL using the DNS name `mysql-service` (or `mysql-service.namespace.svc.cluster.local` for a fully qualified name). However, we haven't restricted *who* can connect yet. Any Pod could try connecting to `mysql-service` on port 3306.

### Implementing the Access Rule

Here comes the Network Policy. We want to achieve the following:

1.  Apply the policy specifically to our MySQL Pods (those labelled `app: mysql`).

2.  Define rules only for incoming (Ingress) traffic.

3.  Allow traffic *only* from Pods that have a specific label, let's say `app: myapp`.

4.  Allow this traffic *only* on TCP port 3306.

```yaml
# mysql-network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: mysql-access-policy
spec:
  podSelector:
    matchLabels:
      app: mysql # Apply this policy TO Pods with this label
  policyTypes:
  - Ingress # This policy defines rules for INCOMING traffic
  ingress:
  - from: # Allow traffic FROM...
    - podSelector:
        matchLabels:
          app: myapp # ...Pods with the label 'app=myapp'
    ports: # ...ON these ports
    - protocol: TCP
      port: 3306 # Allow traffic only on port 3306
```

Let's break down the `spec`:

*   `podSelector`: Selects the Pods this policy governs – our MySQL Pods.

*   `policyTypes`: Specifies that this policy deals with `Ingress` rules. If we also wanted to control outgoing traffic *from* the MySQL Pod, we'd add `Egress`.

*   `ingress`: This section defines the allowed incoming traffic rules.

*   `from`: Specifies the allowed sources. Here, we use another `podSelector` to allow traffic only from Pods labelled `app: myapp`.

*   `ports`: Specifies the allowed destination ports and protocols on the target Pod (`app: mysql`). Here, only TCP traffic on port 3306 is permitted.

We apply this final manifest:

```bash
kubectl apply -f mysql-network-policy.yaml
```

With this policy in place, the "default deny" behaviour kicks in for ingress traffic to the `app: mysql` Pods. Only Pods carrying the `app: myapp` label can successfully establish a TCP connection to port 3306 on the MySQL Pod. Any connection attempt from a Pod without that label, or to a different port on the MySQL Pod, will be blocked by the network plugin enforcing the policy.

## How It All Connects

Let's trace the communication flow now:

1.  A Pod labelled `app: myapp` wants to connect to the database.

2.  It uses the DNS name `mysql-service`. Kubernetes DNS resolves this to the ClusterIP of the Service.

3.  The Service, using its selector `app: mysql`, identifies the target MySQL Pod's actual IP address.

4.  Traffic is routed towards the MySQL Pod's IP on port 3306.

5.  *Before* the connection reaches the MySQL Pod, the Network Policy `mysql-access-policy` intercepts it.

6.  The policy checks: Does the source Pod have the label `app: myapp`? Is the destination port 3306/TCP?

7.  If both conditions are true, the connection is allowed.

8.  If the source Pod has a different label, or no label, or if the connection targets a different port, the policy denies the connection.

A Pod *without* the `app: myapp` label trying the same connection would be blocked at step 7.

## The Power of Selectors

Notice how labels and selectors are central to this entire process. The Deployment uses labels to manage its Pods, the Service uses labels to find the right Pods to send traffic to, and the Network Policy uses labels both to select the Pods it protects and to specify which other Pods are allowed to connect. This label-based approach provides incredible flexibility for defining intricate communication rules within your cluster.

By implementing Network Policies, you move from an open internal network to a controlled environment where communication pathways are explicitly defined, significantly enhancing the security posture of your Kubernetes applications. It's a fundamental tool for building secure, multi-component systems in Kubernetes.
