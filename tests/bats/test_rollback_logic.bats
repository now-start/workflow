#!/usr/bin/env bats
# reusable-rollback.yaml 의 롤백 대상 릴리스 선택 로직 테스트
# rollback verify guard (승격 후 잡 실행 시 스킵) 테스트 포함

# rollback 릴리스 선택 로직을 셸 함수로 재현
# 입력: "tagName\tisPrerelease" TSV 라인 목록, module 이름
select_last_stable() {
  local MODULE="$1"
  local RELEASE_LINES="$2"

  local CANDIDATE_RELEASES=()
  while IFS=$'\t' read -r TAG IS_PRERELEASE; do
    [ -n "$TAG" ] || continue
    if [ -n "$MODULE" ]; then
      local TAG_MODULE
      TAG_MODULE=$(echo "$TAG" | sed -nE 's/^(.+)-[0-9]+\.[0-9]+\.[0-9]+[^ ]*$/\1/p')
      [ "$TAG_MODULE" = "$MODULE" ] || continue
    fi
    CANDIDATE_RELEASES+=("$TAG|$IS_PRERELEASE")
  done <<< "$RELEASE_LINES"

  if [ ${#CANDIDATE_RELEASES[@]} -eq 0 ]; then
    echo "ERROR: no releases"
    return 1
  fi

  local LATEST_INFO="${CANDIDATE_RELEASES[0]}"
  local LATEST_TAG LATEST_IS_PRERELEASE
  IFS='|' read -r LATEST_TAG LATEST_IS_PRERELEASE <<< "$LATEST_INFO"

  local LAST_RELEASE="" STABLE_SEEN=0
  for RELEASE_INFO in "${CANDIDATE_RELEASES[@]}"; do
    local TAG IS_PRERELEASE
    IFS='|' read -r TAG IS_PRERELEASE <<< "$RELEASE_INFO"
    [ "$IS_PRERELEASE" = "false" ] || continue

    if [ "$LATEST_IS_PRERELEASE" = "true" ]; then
      LAST_RELEASE="$TAG"
      break
    fi

    STABLE_SEEN=$((STABLE_SEEN + 1))
    if [ "$STABLE_SEEN" -eq 2 ]; then
      LAST_RELEASE="$TAG"
      break
    fi
  done

  if [ -z "$LAST_RELEASE" ]; then
    echo "ERROR: no stable release"
    return 1
  fi

  echo "$LAST_RELEASE"
}

# ── 단일 레포 ────────────────────────────────────────────────────────────────

@test "latest=prerelease → rolls back to first stable" {
  local RELEASES
  RELEASES="$(printf '3.0.0\ttrue\n2.0.0\tfalse\n1.0.0\tfalse')"
  run select_last_stable "" "$RELEASES"
  [ "$status" -eq 0 ]
  [ "$output" = "2.0.0" ]
}

@test "latest=stable → rolls back to previous stable (second in list)" {
  local RELEASES
  RELEASES="$(printf '2.0.0\tfalse\n1.0.0\tfalse')"
  run select_last_stable "" "$RELEASES"
  [ "$status" -eq 0 ]
  [ "$output" = "1.0.0" ]
}

@test "latest=prerelease, only one stable → rolls back to that stable" {
  local RELEASES
  RELEASES="$(printf '2.0.0\ttrue\n1.0.0\tfalse')"
  run select_last_stable "" "$RELEASES"
  [ "$status" -eq 0 ]
  [ "$output" = "1.0.0" ]
}

@test "latest=prerelease, no stables → error" {
  local RELEASES
  RELEASES="$(printf '2.0.0\ttrue\n1.0.0\ttrue')"
  run select_last_stable "" "$RELEASES"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no stable release"* ]]
}

@test "empty release list → error" {
  run select_last_stable "" ""
  [ "$status" -ne 0 ]
  [[ "$output" == *"no releases"* ]]
}

# ── 모노레포 (module 필터) ────────────────────────────────────────────────────

@test "monorepo: filters by module, ignores other modules" {
  local RELEASES
  RELEASES="$(printf 'gateway-3.0.0\ttrue\nconfig-2.0.0\tfalse\ngateway-2.0.0\tfalse\nconfig-1.0.0\tfalse\ngateway-1.0.0\tfalse')"
  run select_last_stable "gateway" "$RELEASES"
  [ "$status" -eq 0 ]
  [ "$output" = "gateway-2.0.0" ]
}

@test "monorepo: config module only sees config releases" {
  local RELEASES
  RELEASES="$(printf 'config-2.0.0\ttrue\ngateway-5.0.0\tfalse\nconfig-1.0.0\tfalse')"
  run select_last_stable "config" "$RELEASES"
  [ "$status" -eq 0 ]
  [ "$output" = "config-1.0.0" ]
}

@test "monorepo: no stable release for module → error" {
  local RELEASES
  RELEASES="$(printf 'config-2.0.0\ttrue\ngateway-1.0.0\tfalse')"
  run select_last_stable "config" "$RELEASES"
  [ "$status" -ne 0 ]
}

# ── Verify guard (promoted-before-job-ran 방어) ───────────────────────────────

verify_still_prerelease() {
  local CURRENT_STATE="$1"  # "true" or "false"
  # Simulates: gh release view "$TAG" --json isPrerelease --jq '.isPrerelease'
  if [ "$CURRENT_STATE" != "true" ]; then
    echo "skip=true"
  else
    echo "skip=false"
  fi
}

@test "verify: still prerelease → skip=false, proceed with rollback" {
  run verify_still_prerelease "true"
  [ "$output" = "skip=false" ]
}

@test "verify: already promoted to stable → skip=true, abort rollback" {
  run verify_still_prerelease "false"
  [ "$output" = "skip=true" ]
}
