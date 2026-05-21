#!/usr/bin/env bats
# reusable-java-app.yaml 의 release-match 로직 테스트
# 릴리스 태그의 module이 현재 module과 일치하는지 검증

match_module() {
  local MODULE="$1"
  local TAG_NAME="$2"

  if [ -z "$MODULE" ]; then
    echo "true"
    return
  fi

  local TAG_MODULE
  TAG_MODULE=$(echo "$TAG_NAME" | sed -nE 's/^(.+)-[0-9]+\.[0-9]+\.[0-9]+[^ ]*$/\1/p')
  if [ "$TAG_MODULE" = "$MODULE" ]; then
    echo "true"
  else
    echo "false"
  fi
}

# ── 단일 레포 (MODULE 없음) ─────────────────────────────────────────────────

@test "single-repo: empty module always matches any tag" {
  run match_module "" "5.3.4"
  [ "$output" = "true" ]
}

@test "single-repo: empty module matches module-prefixed tag" {
  run match_module "" "config-2.1.5"
  [ "$output" = "true" ]
}

# ── 모노레포 ─────────────────────────────────────────────────────────────────

@test "monorepo: module matches own tag" {
  run match_module "config" "config-2.1.5"
  [ "$output" = "true" ]
}

@test "monorepo: module does not match other module tag" {
  run match_module "config" "gateway-4.8.0"
  [ "$output" = "false" ]
}

@test "monorepo: prefix collision — config does NOT match config-service tag" {
  run match_module "config" "config-service-2.1.5"
  [ "$output" = "false" ]
}

@test "monorepo: config-service matches config-service tag" {
  run match_module "config-service" "config-service-2.1.5"
  [ "$output" = "true" ]
}

@test "monorepo: module does not match bare semver tag (no prefix)" {
  run match_module "config" "2.1.5"
  [ "$output" = "false" ]
}

@test "monorepo: module matches tag with patch version" {
  run match_module "eureka" "eureka-1.0.0"
  [ "$output" = "true" ]
}

@test "monorepo: module does not match when tag has wrong module" {
  run match_module "admin" "eureka-1.0.0"
  [ "$output" = "false" ]
}

@test "monorepo: underscore in module name is handled" {
  run match_module "my_service" "my_service-3.0.0"
  [ "$output" = "true" ]
}
