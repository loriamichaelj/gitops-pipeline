#!/usr/bin/env bash
# Plan and verify the cloud resources that the XRs under infrastructure/ describe.
# Argo CD and Crossplane make the changes; this only reads.
#
#   infra.sh plan <base-ref>     what a change does: every XR is rendered through its
#                                composition on <base-ref> and on the working tree, and
#                                the managed resources are compared with each other and
#                                with what exists in the cloud
#   infra.sh verify [seconds]    waits until the cloud matches the rendered resources
#
# Needs INFRA_PROJECT_ID, crossplane, docker (composition functions), yq, jq, and
# gcloud credentials that can read buckets and networks. Output is markdown on stdout.
set -euo pipefail

repo=$(git rev-parse --show-toplevel)
tmp=$(mktemp -d)
cleanup() {
  git -C "$repo" worktree remove --force "$tmp/base-src" 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT
: "${INFRA_PROJECT_ID:?set INFRA_PROJECT_ID to the GCP project the hub manages}"

# render <repo-root> <out-dir>: the managed resources each XR produces, kept under
# the XR's own path (infrastructure/<env>/<cloud>/<file>) with the XR itself dropped.
render() {
  local root=$1 out=$2 xp_version functions env_file xr rel cloud kind comp f
  mkdir -p "$out"
  # A ref from before the platform existed has nothing to render.
  [[ -f $root/platform/argocd/root/values.yaml ]] || return 0
  xp_version="v$(yq -r .crossplane.chartVersion "$root/platform/argocd/root/values.yaml")"
  functions=$root/platform/crossplane/functions/functions.yaml
  env_file=$(mktemp)
  # What the hub's cluster Secret provides at runtime (see the gcp EnvironmentConfig).
  cat >"$env_file" <<EOF
apiVersion: apiextensions.crossplane.io/v1beta1
kind: EnvironmentConfig
metadata:
  name: gcp
data:
  projectID: "$INFRA_PROJECT_ID"
EOF
  for xr in "$root"/infrastructure/*/*/*.yaml; do
    [[ -e $xr ]] || break
    rel=${xr#"$root"/infrastructure/}
    cloud=$(cut -d/ -f2 <<<"$rel")
    kind=$(yq -r .kind "$xr")
    comp=""
    for f in "$root"/platform/apis/*/composition-*.yaml; do
      if [[ $(yq -r .spec.compositeTypeRef.kind "$f") == "$kind" &&
        $(yq -r '.metadata.labels.cloud // ""' "$f") == "$cloud" ]]; then
        comp=$f
        break
      fi
    done
    [[ -n $comp ]] || {
      echo "no $cloud composition for $kind ($rel)" >&2
      rm -f "$env_file"
      return 1
    }
    mkdir -p "$out/$(dirname "$rel")"
    crossplane composition render "$xr" "$comp" "$functions" \
      --crossplane-version="$xp_version" --required-resources="$env_file" |
      yq 'select(.apiVersion | contains("platform.gitops-pipeline.io") | not)' >"$out/$rel"
  done
  rm -f "$env_file"
}

# index <dir>: JSON object of the rendered resources that have a cloud identity,
# keyed "<kind>/<external name>".
index() {
  find "$1" -name '*.yaml' -exec yq -o=json -I=0 \
    'select(.metadata.annotations["crossplane.io/external-name"] != null)' {} + |
    jq -s 'map({key: (.kind + "/" + .metadata.annotations["crossplane.io/external-name"]), value: .}) | from_entries'
}

# check_live <resource-json>: print the live state and return
#   0 in sync   1 not found   2 differs   3 cannot tell
# A kind without a check here is "cannot tell", so verify fails until one is added.
check_live() {
  local want=$1 kind name live err delta
  local -a describe
  kind=$(jq -r .kind <<<"$want")
  name=$(jq -r '.metadata.annotations["crossplane.io/external-name"]' <<<"$want")
  case $kind in
    Bucket) describe=(storage buckets describe "gs://$name" --raw) ;;
    Network) describe=(compute networks describe "$name" --project="$INFRA_PROJECT_ID") ;;
    Subnetwork)
      describe=(compute networks subnets describe "$name" --project="$INFRA_PROJECT_ID"
        --region="$(jq -r .spec.forProvider.region <<<"$want")")
      ;;
    *)
      echo "cannot check: infra.sh has no live check for $kind"
      return 3
      ;;
  esac
  err=$(mktemp)
  if ! live=$(gcloud "${describe[@]}" --format=json 2>"$err"); then
    # storage: "not found: 404"; compute: "The resource '...' was not found"
    if grep -qE 'not found: 404|was not found' "$err"; then
      echo "not found"
      rm -f "$err"
      return 1
    fi
    echo "cannot check: $(tr '\n' ' ' <"$err" | cut -c1-160)"
    rm -f "$err"
    return 3
  fi
  rm -f "$err"
  # Each mismatch reads "<field> <live> vs <wanted>".
  delta=$(jq -rn --arg kind "$kind" --arg name "$name" --argjson w "$want" --argjson l "$live" '
    def mismatch(field; have; want):
      if have != want then "\(field) \(have) vs \(want)" else empty end;
    def ranges: [.[]? | "\(.rangeName)=\(.ipCidrRange)"] | sort | join(",")
      | if . == "" then "none" else . end;
    $w.spec.forProvider as $p
    | [ if $kind == "Bucket" then
          mismatch("location"; $l.location | ascii_upcase; $p.location | ascii_upcase),
          mismatch("storageClass"; $l.storageClass; $p.storageClass // "STANDARD"),
          mismatch("versioning"; $l.versioning.enabled // false; $p.versioning.enabled // false)
        elif $kind == "Network" then
          mismatch("autoCreateSubnetworks"; $l.autoCreateSubnetworks // false; $p.autoCreateSubnetworks // false),
          mismatch("routingMode"; $l.routingConfig.routingMode; $p.routingMode // "REGIONAL")
        else
          # The subnet shares its network'"'"'s name (see the network composition).
          mismatch("network"; $l.network | split("/") | last; $name),
          mismatch("ipCidrRange"; $l.ipCidrRange; $p.ipCidrRange),
          mismatch("privateIpGoogleAccess"; $l.privateIpGoogleAccess // false; $p.privateIpGoogleAccess // false),
          mismatch("secondaryIpRanges"; $l.secondaryIpRanges | ranges; $p.secondaryIpRange | ranges)
        end ]
    | join(", ")')
  if [[ -n $delta ]]; then
    echo "differs: $delta"
    return 2
  fi
  echo "in sync"
}

plan() {
  local base_ref=${1:?usage: infra.sh plan <base-ref>} base head key action res live rc change
  git -C "$repo" worktree add --detach -q "$tmp/base-src" "$base_ref"
  render "$tmp/base-src" "$tmp/base"
  render "$repo" "$tmp/head"
  base=$(index "$tmp/base")
  head=$(index "$tmp/head")

  echo "## Infrastructure plan"
  echo
  echo "Compared with \`$base_ref\`. Argo CD and Crossplane make these changes after merge; nothing is applied here."
  echo
  echo "| Resource | Change | In the cloud now |"
  echo "|---|---|---|"
  local rows
  rows=$(jq -nc --argjson b "$base" --argjson h "$head" '
    (($b | keys) + ($h | keys) | unique)[] as $k
    | {key: $k,
       action: (if $b[$k] == null then "add"
                elif $h[$k] == null then
                  (if ($b[$k].spec.managementPolicies // ["*"]) | any(. == "*" or . == "Delete")
                   then "destroy" else "orphan" end)
                elif $b[$k] != $h[$k] then "update"
                else "none" end)}')
  if [[ -z $rows ]]; then
    echo "| none | | |"
  fi
  while IFS= read -r row; do
    [[ -n $row ]] || continue
    key=$(jq -r .key <<<"$row")
    action=$(jq -r .action <<<"$row")
    case $action in
      destroy)
        echo "| \`$key\` | **destroy** (deleted from the cloud) | |"
        continue
        ;;
      orphan)
        echo "| \`$key\` | stops being managed (stays in the cloud) | |"
        continue
        ;;
    esac
    res=$(jq -c --arg k "$key" '.[$k]' <<<"$head")
    rc=0
    live=$(check_live "$res") || rc=$?
    case $action in
      add) if [[ $rc == 1 ]]; then change=create; else change="adopt or create"; fi ;;
      update) change=update ;;
      *) if [[ $rc == 1 ]]; then change="no change (not created yet)"; else change="no change"; fi ;;
    esac
    echo "| \`$key\` | $change | $live |"
  done <<<"$rows"

  if ! (cd "$tmp" && diff -ruN base head) >"$tmp/rendered.diff"; then
    echo
    echo "<details><summary>Rendered managed resources, base to head</summary>"
    echo
    echo '```diff'
    cat "$tmp/rendered.diff"
    echo '```'
    echo
    echo "</details>"
  fi
}

verify() {
  local timeout=${1:-600} head deadline key res live rc pending report
  render "$repo" "$tmp/head"
  head=$(index "$tmp/head")
  deadline=$((SECONDS + timeout))
  while :; do
    pending=0
    report=""
    for key in $(jq -r 'keys[]' <<<"$head"); do
      res=$(jq -c --arg k "$key" '.[$k]' <<<"$head")
      rc=0
      live=$(check_live "$res") || rc=$?
      [[ $rc == 0 ]] || pending=1
      report+="| \`$key\` | $live |"$'\n'
    done
    [[ $pending == 0 ]] && break
    if ((SECONDS >= deadline)); then
      break
    fi
    echo "waiting for the hub to converge..." >&2
    sleep 30
  done

  echo "## Infrastructure apply"
  echo
  echo "| Resource | In the cloud |"
  echo "|---|---|"
  [[ -n $report ]] || report=$'| none | |\n'
  printf '%s' "$report"
  echo
  if [[ $pending == 0 ]]; then
    echo "The cloud matches the rendered resources."
  else
    echo "**The cloud did not converge within ${timeout}s.** Check the hub's Argo CD applications and Crossplane conditions."
    return 1
  fi
}

case ${1:-} in
  plan) shift; plan "$@" ;;
  verify) shift; verify "$@" ;;
  *) echo "usage: infra.sh plan <base-ref> | verify [seconds]" >&2; exit 2 ;;
esac
