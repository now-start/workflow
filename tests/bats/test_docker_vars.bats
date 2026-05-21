#!/usr/bin/env bats
# reusable-java-docker.yaml 의 IMAGE_NAME / POINTER_TAG 도출 로직 테스트

resolve_vars() {
  local MODULE="$1"
  local ENVIRONMENT="$2"
  local REGISTRY_ORG="$3"
  local REPO_NAME="test-repo"

  local SERVICE_NAME="${MODULE:-$REPO_NAME}"
  local IMAGE_NAME="$REGISTRY_ORG/$SERVICE_NAME"
  local POINTER_TAG
  POINTER_TAG="$( [ "$ENVIRONMENT" = "dev" ] && echo "dev" || echo "latest" )"

  echo "$IMAGE_NAME $POINTER_TAG"
}

# ── POINTER_TAG ──────────────────────────────────────────────────────────────

@test "environment=dev → POINTER_TAG=dev" {
  run resolve_vars "myservice" "dev" "ghcr.io/now-start"
  [[ "$output" == *" dev" ]]
}

@test "environment=prd → POINTER_TAG=latest" {
  run resolve_vars "myservice" "prd" "ghcr.io/now-start"
  [[ "$output" == *" latest" ]]
}

@test "environment='' (empty) → POINTER_TAG=latest" {
  run resolve_vars "myservice" "" "ghcr.io/now-start"
  [[ "$output" == *" latest" ]]
}

# ── SERVICE_NAME / IMAGE_NAME ────────────────────────────────────────────────

@test "module=config → IMAGE_NAME ends with /config" {
  run resolve_vars "config" "prd" "ghcr.io/now-start"
  [[ "$output" == "ghcr.io/now-start/config "* ]]
}

@test "module='' (single repo) → IMAGE_NAME uses repo name" {
  run resolve_vars "" "prd" "ghcr.io/now-start"
  [[ "$output" == "ghcr.io/now-start/test-repo "* ]]
}

@test "custom registry-org is reflected in IMAGE_NAME" {
  run resolve_vars "svc" "prd" "registry.example.com/myorg"
  [[ "$output" == "registry.example.com/myorg/svc "* ]]
}

# ── REGISTRY_HOST 추출 ────────────────────────────────────────────────────────

@test "REGISTRY_HOST extracted from IMAGE_NAME using %%/*" {
  export IMAGE_NAME="ghcr.io/now-start/config"
  run bash -c 'echo "${IMAGE_NAME%%/*}"'
  [ "$output" = "ghcr.io" ]
}
