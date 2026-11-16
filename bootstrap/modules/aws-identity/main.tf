locals {
  issuer_host_path = trimprefix(var.issuer_url, "https://")
}

data "aws_caller_identity" "this" {}

# Trusts tokens signed by the hub cluster. AWS reads the signing keys from the issuer
# URL, so the issuer must serve its discovery document and JWKS publicly.
resource "aws_iam_openid_connect_provider" "hub" {
  url            = var.issuer_url
  client_id_list = [var.audience]
}

# Only the matching Kubernetes service account, with the expected audience, may
# assume each role.
data "aws_iam_policy_document" "trust" {
  for_each = var.workloads

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.hub.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.issuer_host_path}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${each.key}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.issuer_host_path}:aud"
      values   = [var.audience]
    }
  }
}

resource "aws_iam_role" "workload" {
  for_each = var.workloads

  name               = each.value.role_name
  description        = "Crossplane ${each.key} on the gitops-pipeline hub"
  assume_role_policy = data.aws_iam_policy_document.trust[each.key].json
}

locals {
  policy_attachments = merge([
    for ksa, w in var.workloads : {
      for arn in w.policy_arns : "${ksa}/${arn}" => { ksa = ksa, arn = arn }
    }
  ]...)
}

resource "aws_iam_role_policy_attachment" "workload" {
  for_each = local.policy_attachments

  role       = aws_iam_role.workload[each.value.ksa].name
  policy_arn = each.value.arn
}
