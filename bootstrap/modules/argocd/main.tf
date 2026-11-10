locals {
  namespace  = "argocd"
  in_cluster = "https://kubernetes.default.svc"
}

# First install only. The root chart's "argocd" Application takes over the same
# release (same chart version and values file), so later changes go through Git.
resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = local.namespace
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.chart_version
  values           = [file(var.values_file)]
  wait             = true
  timeout          = 600

  lifecycle {
    ignore_changes = all
  }
}

# Registers the hub with itself so ApplicationSet cluster generators can select it
# and read environment facts from its annotations. Holds no credentials: Argo CD
# reaches in-cluster with its own service account.
resource "kubernetes_secret_v1" "hub_cluster" {
  metadata {
    name        = "cluster-in-cluster"
    namespace   = local.namespace
    labels      = merge(var.cluster_labels, { "argocd.argoproj.io/secret-type" = "cluster" })
    annotations = var.cluster_annotations
  }

  data = {
    name   = "in-cluster"
    server = local.in_cluster
    config = jsonencode({ tlsClientConfig = { insecure = false } })
  }

  depends_on = [helm_release.argocd]
}

resource "helm_release" "root" {
  name       = "argocd-root"
  namespace  = local.namespace
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.apps_chart_version

  values = [yamlencode({
    applications = {
      root = {
        namespace = local.namespace
        project   = "default"
        source = {
          repoURL        = var.repo_url
          targetRevision = var.target_revision
          path           = "platform/argocd/root"
          helm = {
            releaseName = "root"
            valuesObject = merge(var.root_values, {
              repoURL        = var.repo_url
              targetRevision = var.target_revision
            })
          }
        }
        destination = {
          server    = local.in_cluster
          namespace = local.namespace
        }
        syncPolicy = {
          automated = { prune = true, selfHeal = true }
        }
      }
    }
  })]

  depends_on = [kubernetes_secret_v1.hub_cluster]
}
