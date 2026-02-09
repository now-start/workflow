# now-start/workflow

now-start 조직의 공통 GitHub Actions 워크플로우 저장소입니다.

## 재사용 가능한 워크플로우

### Java Build and Deploy Workflow

Java/Spring Boot 애플리케이션을 위한 표준화된 CI/CD 파이프라인입니다.

#### 기능
- Gradle 빌드 및 테스트
- 버전 자동 추출 (build.gradle)
- Docker 이미지 빌드
- GitHub Container Registry (GHCR) 푸시
- 자동 릴리스 생성
- 중복 빌드 방지 (기존 태그 체크)

#### 사용법

각 서비스의 `.github/workflows/build.yml` 파일:

```yaml
name: App CI/CD
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  release:
    types: [released, edited]

jobs:
  app:
    uses: now-start/workflow/.github/workflows/reusable-java-app.yaml@main
    with:
      service-name: your-service-name  # 예: admin-service, lotto-service
      enable-dev: true                 # DEV+PRD 모드 (false면 PRD 전용)
    secrets:
      registry-password: ${{ secrets.GITHUB_TOKEN }}
```

#### 입력 매개변수

| 매개변수           | 필수 | 기본값                 | 설명                                |
|----------------|----|---------------------|-----------------------------------|
| `service-name` | ❌  | 레포지토리 이름            | Docker 이미지 태깅을 위한 서비스 이름      |
| `registry-org` | ❌  | 'ghcr.io/now-start' | 컨테이너 레지스트리 조직/네임스페이스          |
| `enable-dev`   | ❌  | `false`             | `true` 시 DEV+PRD, `false` 시 PRD 전용 모드 |

#### 시크릿 매개변수

| 시크릿 | 필수 | 설명 |
|--------|------|------|
| `registry-password` | ✅ | 레지스트리 비밀번호/토큰 (예: GITHUB_TOKEN) |

## 지원 서비스

현재 다음 서비스들이 이 워크플로우를 사용할 수 있습니다:

- [admin-service](https://github.com/now-start/admin-service)
- [eureka-service](https://github.com/now-start/eureka-service)
- [gateway-service](https://github.com/now-start/gateway-service)
- [lotto-service](https://github.com/now-start/lotto-service)
- [nyang-nyang-bot](https://github.com/now-start/nyang-nyang-bot)

## 워크플로우 실행 과정

1. **버전 체크**: `build.gradle`에서 버전 추출
2. **태그 확인**: 해당 버전의 태그가 이미 존재하는지 확인
3. **Pre-release/Release 생성**:
   - DEV+PRD 모드(dev): dev 빌드 성공 시 해당 버전에 대한 Git 태그 및 Pre-release를 자동 생성(최초 1회)
   - PRD-only 모드(prd): main push 시 stable release 생성
4. **빌드**: Gradle로 애플리케이션 빌드
5. **Docker**: Docker 이미지 빌드 및 버전 태그(push)
6. **배포 태그 갱신**:
   - dev 환경: `:dev` 태그를 최신 이미지로 갱신 (watchtower가 dev 환경 자동 업데이트)
   - prd 환경: Release 승격 시 별도 워크플로에서 `:latest` 태그를 해당 버전으로 프로모트 (watchtower가 PRD 환경 자동 업데이트)

## 워크플로우 플로우 (ASCII 다이어그램)

```text
PR (pull_request)
  └─ test-only
       └─ reusable-java-test.yaml

main push (enable-dev = true, DEV+PRD 모드)
  └─ prepare-dev (reusable-java-prepare.yaml)
       ├─ Gradle에서 version / Java version 추출
       ├─ 동일 version 태그/릴리즈 존재 여부 확인
       └─ skip == false 인 경우에만:
            ├─ build-dev (reusable-java-test.yaml)
            │    └─ Gradle build & test
            ├─ docker-dev (reusable-java-docker.yaml)
            │    └─ 이미지 푸시: :<version>, :dev
            └─ dev 프리릴리즈 생성
                 └─ tag: <version>, prerelease = true

main push (enable-dev = false, PRD-only 모드)
  └─ prepare-prd (reusable-java-prepare.yaml)
       ├─ Gradle에서 version / Java version 추출
       ├─ 동일 version 태그/릴리즈 존재 여부 확인
       └─ skip == false 인 경우에만:
            ├─ build-prd (reusable-java-test.yaml)
            │    └─ Gradle build & test
            ├─ docker-prd (reusable-java-docker.yaml)
            │    └─ 이미지 푸시: :<version>, :latest
            └─ stable 릴리즈 생성
                 └─ tag: <version>, prerelease = false

release 이벤트 (프리릴리즈 → 릴리즈 승격)
  └─ promote-to-prod (reusable-promote-to-prod.yaml)
       └─ 이미지 <version> → :latest 태깅/푸시

release 이벤트 (릴리즈 → 프리릴리즈 demote, 롤백)
  └─ reusable-rollback.yaml
       ├─ stable 릴리즈 목록 조회
       ├─ 직전 stable 릴리즈 선택
       └─ 해당 버전 이미지를 :latest 로 재태깅/푸시
```

## 장점

- ✅ **일관성**: 모든 서비스가 동일한 배포 프로세스 사용
- ✅ **유지보수성**: 중앙에서 워크플로우 관리
- ✅ **효율성**: 중복 코드 제거
- ✅ **확장성**: 새로운 서비스도 쉽게 추가 가능
