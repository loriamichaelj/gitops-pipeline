# infrastructure

Cloud resources the hub reconciles, one folder per environment and cloud:
`infrastructure/<env>/<cloud>/*.yaml`, each file an XR (`XBucket`, `XNetwork`) in
namespace `infra-<env>`.

Nothing is checked in here, so nothing is deployed. The earlier sample XRs
(a GCS bucket and a VPC in `dev`/`gcp`) were removed; deleting their folder made
Argo CD delete the Application, and its finalizer deletes the XRs and their cloud
resources. That takes effect once the change reaches `dev` and the hub is running.

To deploy something, add its XR under `infrastructure/<env>/<cloud>/` through a
pull request to `dev`. See `platform/apis/README.md` for the cloud contract.
