# Same checks locally and in CI (.github/workflows/validate.yml).
# Needs: helm, yq, kubeconform, crossplane, kyverno, tofu, trivy, docker.

.PHONY: validate render compositions schemas policies tofu update-snapshots

validate: render compositions schemas policies tofu

render:
	scripts/render.sh

compositions: render
	scripts/test-compositions.sh

schemas: compositions
	scripts/validate-schemas.sh

policies:
	scripts/check-policies.sh

tofu:
	scripts/check-tofu.sh

update-snapshots: render
	UPDATE=1 scripts/test-compositions.sh
