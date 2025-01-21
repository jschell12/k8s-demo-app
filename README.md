# K8s Demo App

Simple web application that displays a simple message and information about Pod, GKE Cluster, GKE Node and Zone serving the request.

The application is also published as a container image [quay.io/stepanstipl/k8s-demo-app][1]

[1]: https://quay.io/repository/stepanstipl/k8s-demo-app

![screenshot](imgs/screenshot.png)

### Deployment

The application exposes health-check `/healthz` endpoint.

### Configuration

Serving port (defaults to `8080`) can be parametrised using the `-listen-addr` flag or `K8S_DEMO_APP_LISTEN_ADDR` environment variable.

Displayed message can be parametrised by setting the `K8S_DEMO_APP_MESSAGE` variable.

---
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
---
## AWS Load Balancer controller

The AWS Load Balancer Controller is required to manage **AWS Elastic Load Balancers (ALBs and NLBs)** for Kubernetes services and ingress resources. It automatically provisions and configures load balancers to route traffic to Kubernetes pods, enabling seamless integration with AWS services. Without it, Kubernetes cannot natively manage AWS-specific load balancers for ingress and service traffic.

### Installation

1. Add the EKS chart repo to helm
    ```sh
    $ helm repo add eks https://aws.github.io/eks-charts
    ```

2. Make sure the CRDs are up-to-date
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
---
## Metrics Server

The Metrics Server is essential for enabling Kubernetes Horizontal Pod Autoscaling (HPA), as it collects and exposes resource usage metrics (CPU and memory) via the Kubernetes Resource Metrics API. HPA relies on this data to scale pod replicas. Without the Metrics Server, the metrics.k8s.io API will not provide data, and HPA will not function.

### Installation

```sh
$ helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
$ helm repo update

$ helm install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set args="{--kubelet-insecure-tls,--kubelet-preferred-address-types=InternalIP}"
```
---
## Load testing

```sh
$ $ for i in {1..100000000}; do wget -q -O- http://k8s-default-k8sdemoa-8627f872eb-391973712.us-west-1.elb.amazonaws.com & done
```
![Screenshot 2025-01-20 at 7 27 37 PM](https://github.com/user-attachments/assets/c19adf14-bcab-44dd-9372-4ad284957029)
![Screenshot 2025-01-20 at 7 28 13 PM](https://github.com/user-attachments/assets/57c6e537-b36e-4d75-925c-e0252fc4920d)

---
## Github Actions

### **Deploy Main Branch**

This GitHub Action automates the deployment and rollback of the main branch. It allows manual triggering with a specific Docker image version and provides error handling to automatically rollback in case of deployment failures.

#### **Key Jobs**

1. **`deploy_main`**
   - **Triggered by `workflow_dispatch` (manual trigger).**
   - **Purpose**: Deploy resources for the main branch.
   - **Inputs**: Requires a `version` input to tag the Docker image and Helm deployment.
   - **Steps**:
     - **Checkout Code**:
       - Fetches the repository code.
     - **AWS Configuration**:
       - Configures AWS credentials for interacting with Kubernetes in AWS.
     - **Docker Login**:
       - Authenticates with GitHub Container Registry (GHCR) using `GITHUB_TOKEN`.
     - **Build and Push Docker Image**:
       - Builds a Docker image tagged with the provided `version` and `latest`.
       - Pushes the images to GHCR.
     - **Set Up Kubernetes and Helm**:
       - Installs and configures `kubectl` and `helm` for deployment.
     - **Deploy Helm Chart**:
       - Deploys or upgrades the `k8s-demo-app` Helm chart in the `default` namespace.
       - Configures the chart to use the latest Docker image and waits for the deployment to complete.
       - **Error Handling**: Uses `continue-on-error: true` to allow the job to proceed to the rollback step if deployment fails.

2. **`rollback_main`**
   - **Triggered if `deploy_main` fails (`if: failure()`).**
   - **Purpose**: Rollback to the last successful Helm release.
   - **Steps**:
     - **Checkout Code**:
       - Fetches the repository code for Helm rollback operations.
     - **AWS Configuration**:
       - Reuses AWS credentials for Kubernetes interaction.
     - **Set Up Kubernetes and Helm**:
       - Installs and configures `kubectl` and `helm` for rollback.
     - **Rollback Helm Chart**:
       - Executes a rollback of the `k8s-demo-app` Helm release to the previous revision (`1`) in the `default` namespace.

#### **Key Features**
- **Manual Trigger**:
  - Allows users to deploy the main branch by specifying a version (e.g., `v1.0.0`).
- **Error Handling and Rollback**:
  - Automatically rolls back the Helm release if the deployment fails.
- **Environment-Specific Deployment**:
  - Targets the `default` namespace in the Kubernetes `dev` environment.
- **Versioned and Latest Docker Images**:
  - Builds and tags Docker images with both the specified version and `latest`.

#### **Use Cases**
1. **Main Branch Deployment**:
   - Deploys the `k8s-demo-app` to the `default` namespace for production or staging purposes.
2. **Error Recovery**:
   - Automatically reverts the deployment to a stable state in case of issues.

#### **Triggering the Workflow**

1. Run the workflow manually by providing a version (e.g., `v1.0.0`) in the GitHub Actions UI.
2. If the `deploy` step fails, the `rollback` job will execute automatically.
3. We can also "manually" rollback but just providing a previous version.

#### **Testing the Rollback**

To test the rollback:
1. Introduce an intentional error in the Helm chart or deployment.
2. Trigger the workflow.
3. Verify that the rollback occurs automatically after the failure.


### **Deploy Feature Branch**

This GitHub Action is designed to automate the deployment and cleanup of Kubernetes resources for feature branches in a repository. It triggers on:
1. **Push to a `feature/*` branch**: Deploys resources for the feature branch.
2. **Delete a `feature/*` branch**: Cleans up the deployed resources.

#### **Key Jobs**

1. **`deploy_feature`**
   - **Triggered on `push` to `feature/*` branches.**
   - **Purpose**: Deploy resources for a feature branch.
   - **Steps**:
     - **Checkout Code**: Fetches the repository code.
     - **Extract Branch Name**: Determines the branch name for resource isolation.
     - **AWS Configuration**: Configures AWS credentials for Kubernetes interaction.
     - **Docker Login**: Authenticates with GitHub Container Registry (GHCR).
     - **Build and Push Docker Image**: Builds a Docker image tagged with the branch name and pushes it to GHCR.
     - **Set Up Kubernetes and Helm**: Installs and configures `kubectl` and `helm`.
     - **Create Namespace**: Creates a temporary Kubernetes namespace named after the branch.
     - **Deploy Helm Chart**: Deploys the application into the branch-specific namespace using Helm.

2. **`cleanup_feature`**
   - **Triggered on `delete` of a `feature/*` branch.**
   - **Purpose**: Clean up resources associated with the deleted branch.
   - **Steps**:
     - **Checkout Code**: Fetches the repository code.
     - **Extract Deleted Branch Name**: Determines the branch name for identifying the namespace and resources to delete.
     - **AWS Configuration**: Configures AWS credentials for Kubernetes interaction.
     - **Set Up Kubernetes and Helm**: Installs and configures `kubectl` and `helm`.
     - **Delete Helm Release**: Uninstalls the Helm release associated with the branch.
     - **Delete Namespace**: Deletes the branch-specific Kubernetes namespace and all resources within it.

#### **Key Features**
- **Temporary Namespace for Isolation**:
  - Each feature branch deployment is isolated in its own Kubernetes namespace named after the branch.
- **Automatic Cleanup**:
  - Deletes all resources and the namespace when the branch is deleted.
- **Branch-Specific Docker Images**:
  - Builds and tags Docker images with the branch name for deployment.

#### **Use Cases**
1. **Feature Development**:
   - Automatically deploys a feature branch for testing in an isolated environment.
2. **Cleanup on Branch Deletion**:
   - Ensures no leftover resources remain when a feature branch is removed.
