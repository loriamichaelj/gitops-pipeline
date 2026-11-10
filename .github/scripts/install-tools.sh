#!/usr/bin/env bash
# Install pinned, checksum-verified CLI tools on a linux/amd64 runner.
# Usage: install-tools.sh helm yq kubeconform ...
set -euo pipefail

bin=/usr/local/bin
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# name|version|url|sha256|path inside the archive ("-" for a bare binary)
tools=(
  "helm|4.3.0|https://get.helm.sh/helm-v4.3.0-linux-amd64.tar.gz|86584a54def73570558f66f5111cc53dfed56689637ae32c1201205d494f54fb|linux-amd64/helm"
  "yq|4.54.1|https://github.com/mikefarah/yq/releases/download/v4.54.1/yq_linux_amd64|8e34fc298390875de416e6a4afcb8cabeceb25d9aa8506c1a2f9353cf702ea5f|-"
  "kubeconform|0.8.0|https://github.com/yannh/kubeconform/releases/download/v0.8.0/kubeconform-linux-amd64.tar.gz|9bc2bffbf71f261128533edaf912153948b7ff238f9a531ae6d34466ec287883|kubeconform"
  "kyverno|1.19.2|https://github.com/kyverno/kyverno/releases/download/v1.19.2/kyverno-cli_v1.19.2_linux_x86_64.tar.gz|357eaf1df8bc24ddd5a73979fadeaae6a032e8710f11af264229756e4956bf4a|kyverno"
  "tofu|1.13.2|https://github.com/opentofu/opentofu/releases/download/v1.13.2/tofu_1.13.2_linux_amd64.tar.gz|ac05d9952662c7db28dd57e93f0a68018837bfdf9342384ec0987977c16a9645|tofu"
  "trivy|0.75.0|https://github.com/aquasecurity/trivy/releases/download/v0.75.0/trivy_0.75.0_Linux-64bit.tar.gz|c6e65abddb348e25f10549df887045629cf28cc72453cd1c63acb717316b3f3f|trivy"
)

for want in "$@"; do
  found=0
  for entry in "${tools[@]}"; do
    IFS='|' read -r name version url sha path <<<"$entry"
    [[ $name == "$want" ]] || continue
    found=1
    file="$tmp/$(basename "$url")"
    curl -sSfL -o "$file" "$url"
    echo "$sha  $file" | sha256sum -c --quiet -
    if [[ $path == - ]]; then
      sudo install -m 0755 "$file" "$bin/$name"
    else
      tar -xzf "$file" -C "$tmp" "$path"
      sudo install -m 0755 "$tmp/$path" "$bin/$name"
    fi
    echo "installed $name $version"
  done
  [[ $found == 1 ]] || { echo "unknown tool: $want" >&2; exit 1; }
done
