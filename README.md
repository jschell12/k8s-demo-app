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

# Install metrics server

```sh
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

helm install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set args="{--kubelet-insecure-tls,--kubelet-preferred-address-types=InternalIP}"
```

## Load testing

```sh
$ kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://k8s-demo-app-chart-k8s-demo-app; done"
```