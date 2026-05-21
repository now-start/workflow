#!/usr/bin/env bats
# promote-to-prod 및 rollback 에서 사용하는 semver 추출 로직 테스트

extract_version_with_module() {
  local TAG_NAME="$1"
  echo "$TAG_NAME" | sed -nE 's/^.+-([0-9]+\.[0-9]+\.[0-9]+[^ ]*)$/\1/p'
}

extract_version_without_module() {
  local TAG_NAME="$1"
  echo "$TAG_NAME" | sed -nE 's/^([0-9]+\.[0-9]+\.[0-9]+[^ ]*)$/\1/p'
}

# ── 모노레포 (module prefix 포함) ───────────────────────────────────────────

@test "with-module: extracts semver from config tag" {
  run extract_version_with_module "config-2.1.5"
  [ "$output" = "2.1.5" ]
}

@test "with-module: extracts semver from gateway tag" {
  run extract_version_with_module "gateway-4.8.0"
  [ "$output" = "4.8.0" ]
}

@test "with-module: handles hyphen in module name (config-service)" {
  run extract_version_with_module "config-service-2.1.5"
  [ "$output" = "2.1.5" ]
}

@test "with-module: preserves pre-release suffix (SNAPSHOT)" {
  run extract_version_with_module "config-1.0.0-SNAPSHOT"
  [ "$output" = "1.0.0-SNAPSHOT" ]
}

@test "with-module: returns empty for bare semver (no prefix)" {
  run extract_version_with_module "2.1.5"
  [ "$output" = "" ]
}

@test "with-module: returns empty for plain word" {
  run extract_version_with_module "invalid-tag"
  [ "$output" = "" ]
}

# ── 단일 레포 (prefix 없음) ──────────────────────────────────────────────────

@test "without-module: extracts bare semver" {
  run extract_version_without_module "5.3.4"
  [ "$output" = "5.3.4" ]
}

@test "without-module: preserves pre-release suffix" {
  run extract_version_without_module "1.0.0-SNAPSHOT"
  [ "$output" = "1.0.0-SNAPSHOT" ]
}

@test "without-module: returns empty when tag has module prefix" {
  run extract_version_without_module "config-2.1.5"
  [ "$output" = "" ]
}

@test "without-module: returns empty for plain word" {
  run extract_version_without_module "main"
  [ "$output" = "" ]
}
