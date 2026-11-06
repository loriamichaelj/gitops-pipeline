output "kubeconfig" {
  description = "export KUBECONFIG=<this> to use the hub with kubectl."
  value       = abspath(module.kind.kubeconfig_path)
}

output "context" {
  value = module.kind.context
}

output "argocd_ui" {
  description = "Run the port-forward, then open https://localhost:8080 (user admin)."
  value       = "kubectl --kubeconfig ${abspath(module.kind.kubeconfig_path)} -n argocd port-forward svc/argocd-server 8080:443"
}

output "argocd_admin_password" {
  value = "kubectl --kubeconfig ${abspath(module.kind.kubeconfig_path)} -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}
