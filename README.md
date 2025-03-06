# GCE Instance Cloning GitLab CI/CD Pipeline

## Overview
This GitLab pipeline automates the cloning of a GCE (Google Compute Engine) instance in GCP. It:
- Creates an image from the source instance's boot disk (if it doesn't already exist).
- Creates a snapshot of the source instance's data disk (if it doesn't already exist).
- Uses Helm to generate Kubernetes manifests for the cloned instance.
- Pushes the changes to a Git repository that contains Crossplane definitions.
- Deploys the cloned instance using ArgoCD for continuous delivery.
- Waits for the new instance to become available.
- Cleans up temporary GCP resources (image and snapshot).

## Prerequisites
Before running this pipeline, ensure you have:
1. A GitLab runner with appropriate permissions.
2. A Google Cloud service account with permissions to manage GCE instances, disks, and snapshots.
3. The following GitLab CI/CD variables configured:
   - `GCLOUD_SA`: Base64-encoded GCP service account key.
   - `GITSSH_KEY`: Base64-encoded SSH key for Git access.
   - `GITUSER`: Git username.
   - `GITMAIL`: Git email.
   - `REPO`: Git repository URL containing Crossplane definitions.
   - `BRANCH`: Git branch to push changes to.

## Configuration Variables

### Required Variables
| Variable         | Description |
|-----------------|-------------|
| `DST_INSTANCE`  | Destination GCE instance name (without `-instance` at the end). |
| `SRC_INSTANCE`  | Source GCE instance name (without `-instance` at the end). |
| `PROJECT`       | GCP project where the cloned instance will be created. |
| `GCP_PROJECT`   | The GCP project where the source instance is located. |
| `GCP_ZONE`      | GCP zone where the source instance resides. |
| `SUBNETWORK`    | GCP subnetwork for the new instance. |
| `DATA_DISK_SIZE` | 3296    | Size of the data disk (in GB). |
| `BOOT_DISK_SIZE` | 20      | Size of the boot disk (in GB). |
| `DATA_DISK_TYPE` | pd-balanced | Type of the data disk. |
| `BOOT_DISK_TYPE` | pd-balanced | Type of the boot disk. |
| `MACHINE_TYPE`   | n2d-standard-8 | Machine type for the instance. |
| `PREEMPTIBLE`    | false   | Whether the instance is preemptible. |

## Pipeline Stages
1. **Setup Environment**: Installs required tools (gcloud, Helm, Git, SSH).
2. **Create Image & Snapshot**: Creates an image from the source instance's boot disk and a snapshot of its data disk if they do not already exist.
3. **Git Operations**: Sets up SSH keys, clones the repository, and checks out the target branch.
4. **Generate Helm Manifests**: Creates Kubernetes Helm manifests for the cloned instance.
5. **Push Changes to Git**: Commits and pushes the new instance definition to the Crossplane repository.
6. **ArgoCD Deployment**: ArgoCD automatically syncs the new Crossplane definition and provisions the instance in GCP.
7. **Wait for Instance Creation**: Monitors the cloned instance until it becomes available.
8. **Cleanup**: Deletes temporary images and snapshots.

## Running the Pipeline
To trigger the pipeline, push changes to the `production` branch in GitLab or run it manually from the GitLab CI/CD interface.

## Notes
- Ensure that the `GITSSH_KEY` is correctly set up in GitLab as a base64-encoded private key.
- Modify variables as needed for your GCP environment.
- The pipeline only runs on the `production` branch.
- ArgoCD must be set up to monitor the repository for automatic deployment.

## Troubleshooting
- Check GitLab CI/CD logs for errors related to GCP API calls, Git operations, or Helm template generation.
- Ensure the service account has the necessary IAM roles to manage instances and disks.
- Verify that the source instance and disks exist in the specified `GCP_PROJECT` and `GCP_ZONE`.
- Ensure ArgoCD is correctly configured and syncing changes from the repository.



### **Potential AI Improvement Suggestions:**

#### **1. Optimize Image and Snapshot Creation**
You're checking for existing images and snapshots before creating them, which is great. However, these checks could be optimized by explicitly checking for errors instead of relying on `gcloud` returning an error.

✅ **Suggested Improvement:**
```bash
if ! gcloud compute images describe "$SRC_IMG" --quiet 2>/dev/null; then
  echo "Creating image $SRC_IMG";
  gcloud compute images create "$SRC_IMG" --source-disk "$SRC_DISK" --source-disk-zone "$GCP_ZONE" --family "$IMG_FAMILY" --description "Boot Image from $SRC_DISK" --force;
else
  echo "Image $SRC_IMG already exists. Skipping image creation.";
fi
```
This prevents unnecessary logs from being printed.

#### **2. Improve Git Operations**
Right now, you're cloning the entire repository, but you only need a specific folder for Crossplane definitions. If the repository is large, this can slow down the process.

✅ **Suggested Improvement:**
Use a **shallow clone** to speed up the process:
```bash
git clone --depth=1 --branch=$BRANCH $REPO
```
This will only fetch the latest commit for the specified branch, reducing network usage.

---

#### **3. Fix SSH Key Permissions Issue**
You’re setting up SSH keys like this:
```bash
mkdir /root/.ssh
echo "$GITSSH_KEY" | base64 -d > /root/.ssh/id_rsa
chmod 600 /root/.ssh/id_rsa
```
However, SSH may fail if the `.ssh` folder itself does not have the right permissions.

✅ **Suggested Improvement:**
```bash
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "$GITSSH_KEY" | base64 -d > /root/.ssh/id_rsa
chmod 600 /root/.ssh/id_rsa
```
This prevents potential SSH permission errors.

---

#### **4. Improve ArgoCD Sync Timing**
Your pipeline relies on ArgoCD to deploy the new Crossplane resources, but it doesn’t explicitly check whether the sync has completed. 

✅ **Suggested Improvement:** 
After pushing to Git, you can add:
```bash
echo "Waiting for ArgoCD to sync changes..."
argocd app sync my-crossplane-app
argocd app wait my-crossplane-app --health
```
Replace `my-crossplane-app` with your actual ArgoCD application name.

---

#### **5. Add Retry Logic for GCP Commands**
Some GCP commands might fail due to temporary issues, such as API rate limits. Adding retries can make the pipeline more resilient.

✅ **Suggested Improvement:**
Wrap critical GCP commands in a retry loop:
```bash
for i in {1..5}; do
  gcloud compute disks snapshot "$DATA_DISK" --zone "$GCP_ZONE" --snapshot-names "$DATA_SNAPSHOT" --storage-location "$STORAGE_LOCATION" && break
  echo "Snapshot creation failed, retrying in 10s..."
  sleep 10
done
```
This will retry up to 5 times before failing.

---

