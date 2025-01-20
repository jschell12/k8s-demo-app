# K8s Demo App

Simple web application that displays a simple message and information about Pod, GKE Cluster, GKE Node and Zone serving the request.

The application is also published as a container image [quay.io/stepanstipl/k8s-demo-app][1]

[1]: https://quay.io/repository/stepanstipl/k8s-demo-app

![screenshot](imgs/screenshot.png)

## Deployment

See `deploy.yaml` for simple deployment example.

The application exposes health-check `/healthz` endpoint.

## Configuration

Serving port (defaults to `8080`) can be parametrised using the `-listen-addr` flag or `K8S_DEMO_APP_LISTEN_ADDR` environment variable.

Displayed message can be parametrised by setting the `K8S_DEMO_APP_MESSAGE` variable.

## Setup Infrastructure with Terraform

This will set up a node group for the pod(s) to run on. It will also create the necessary IAM role and policy for the AWS Load Balancer Controller to create resources.

> NOTE: The below commands assume the AWS credentials have been added to the `~/.aws/credentials` file under the header `[angi]`

1. ```sh
   $ terraform init
   ```

2. ```sh
   $ AWS_PROFILE=angi terraform plan
   ``` 

3. ```sh
   $ AWS_PROFILE=angi terraform apply
   ```

## Installing AWS Load Balancer controller

### Prerequisites

You must apply the terraform configuration as it also creates the necessary IAM role and policy for the controller to create ALB resources

#### Steps

1. Add the EKS chart repo to helm
    ```sh
    $ helm repo add eks https://aws.github.io/eks-charts
    ```

2.  Make sure the CRDs are up-to-date
    ```sh
    $ kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"
    ```

3. Install the helm chart if using IAM roles for service accounts. NOTE you need to specify both of the chart values serviceAccount.create=false and serviceAccount.name=aws-load-balancer-controller

    ```sh 
    $ helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=eks-joshua-schell --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller
    ```

4. Install the helm chart if not using IAM roles for service accounts

    ```sh
    $ helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=eks-joshua-schell
    ```

## Install metrics server

```sh
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

helm install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set args="{--kubelet-insecure-tls,--kubelet-preferred-address-types=InternalIP}"
```

## Load testing

```sh
$ for i in {1..100000000}; do wget -q -O- http://k8s-demo-app-chart-k8s-demo-app & done
```

## Github Actions

#### **Workflow Name**
**Deploy Main Branch**

---

#### **Triggers**
- **`workflow_dispatch`**: Manually triggered, requiring a `version` input to specify the Docker image and release version (e.g., `v1.0.0`).

---

#### **Jobs**

1. **`deploy` Job**
   - **Environment**: `dev`.
   - **Runs-on**: `ubuntu-latest`.
   - **Steps**:
     1. **Checkout Repository**:
        - Checks out the repository to fetch source code.
     2. **AWS Credentials Configuration**:
        - Configures AWS credentials using secrets for interaction with AWS services.
     3. **Docker Login**:
        - Logs in to GitHub Container Registry (GHCR) using the `GITHUB_TOKEN`.
     4. **Build Docker Image**:
        - Builds a Docker image tagged with the provided `version` and `latest`.
     5. **Push Docker Image**:
        - Pushes the `version`-tagged and `latest` Docker images to GHCR.
     6. **Setup Kubernetes and Helm**:
        - Installs and configures `kubectl` and `helm`.
     7. **Deploy Helm Chart**:
        - Deploys or upgrades the `k8s-demo-app` Helm chart in the `default` namespace using the Docker image tag (`version`).
        - Uses `--force` and `--wait` to ensure the deployment is applied immediately and waits for the resources to become ready.
     8. **Error Handling**:
        - Allows the job to proceed even if this step fails (`continue-on-error: true`).

---

2. **`rollback` Job**
   - **Triggered**: Only runs if the `deploy` job fails (`if: failure()`).
   - **Needs**: Depends on the `deploy` job.
   - **Runs-on**: `ubuntu-latest`.
   - **Steps**:
     1. **Checkout Repository**:
        - Fetches source code.
     2. **AWS Credentials Configuration**:
        - Reuses AWS credentials setup for interaction with AWS services.
     3. **Setup Kubernetes and Helm**:
        - Installs and configures `kubectl` and `helm`.
     4. **Helm Rollback**:
        - Rolls back the `k8s-demo-app` release in the `default` namespace to the previous revision (`1`).

---

#### **Key Features**
- **Error Handling**:
  - The `deploy` job allows failures and triggers the `rollback` job to revert to the previous Helm chart release.
- **Environment-Specific Deployment**:
  - Targets the `dev` environment, configurable via Helm and Kubernetes.
- **Manual Trigger**:
  - Allows users to provide a specific `version` for releases.
- **Docker and Helm Integration**:
  - Builds and pushes Docker images to GHCR and deploys the application using Helm.

---

#### **Result**
- On a successful `deploy`:
  - Updates the `k8s-demo-app` Helm release with the latest Docker image.
- On a `deploy` failure:
  - Automatically rolls back to the previous Helm release.

---

### **Triggering the Workflow**

1. Run the workflow manually by providing a version (e.g., `v1.0.0`) in the GitHub Actions UI.
2. If the `deploy` step fails, the `rollback` job will execute automatically.
3. We can also "manually" rollback but just providing a previous version.

---

### **Testing the Rollback**

To test the rollback:
1. Introduce an intentional error in the Helm chart or deployment.
2. Trigger the workflow.
3. Verify that the rollback occurs automatically after the failure.

