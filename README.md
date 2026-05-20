# now-start/workflow

now-start 조직의 공통 GitHub Actions 워크플로우 저장소입니다.

## 재사용 가능한 워크플로우

### Java Build and Deploy Workflow

Java/Spring Boot 애플리케이션을 위한 표준화된 CI/CD 파이프라인입니다.

#### 기능
- Gradle 빌드 및 테스트
- 버전 자동 추출 (build.gradle)
- Docker 이미지 빌드 및 GHCR 푸시
- 자동 릴리스/태그 생성
- 중복 빌드 방지 (기존 태그 체크)
- **단일 레포 / 모노레포 모두 지원**

---

## 사용 패턴

### 패턴 1 — 단일 레포 (Single Repo)

서비스 하나가 독립 레포로 존재하는 경우입니다. `module` 없이 최소 설정만으로 동작합니다.

```yaml
# .github/workflows/build.yaml
name: App CI/CD

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  release:
    types: [released, prereleased, edited]

permissions:
  contents: write
  packages: write

jobs:
  app:
    uses: now-start/workflow/.github/workflows/reusable-java-app.yaml@main
    secrets:
      registry-password: ${{ secrets.GITHUB_TOKEN }}
```

- Docker 이미지 이름 기본값: 레포지토리 이름 (예: `nyang-nyang-bot`)
- 태그 형식: `{version}` (예: `5.3.4`)
- Docker 이미지: `ghcr.io/now-start/nyang-nyang-bot:5.3.4`

---

### 패턴 2 — 모노레포 (Monorepo)

하나의 레포에 여러 Gradle 서브모듈이 존재하는 경우입니다.  
변경된 모듈만 빌드/배포하고, 릴리스도 모듈별로 독립 관리합니다.

```yaml
# .github/workflows/build.yaml
name: Platform CI/CD

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  release:
    types: [released, prereleased, edited]

permissions:
  contents: write
  packages: write

jobs:
  changes:
    if: ${{ github.event_name != 'release' }}
    runs-on: ubuntu-latest
    outputs:
      config: ${{ steps.filter.outputs.config }}
      gateway: ${{ steps.filter.outputs.gateway }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            config:
              - 'config/**'
              - 'gradle/**'
              - 'build.gradle'
              - 'settings.gradle'
            gateway:
              - 'gateway/**'
              - 'gradle/**'
              - 'build.gradle'
              - 'settings.gradle'

  config:
    needs: changes
    # push 시 경로 변경 감지 OR 해당 모듈 태그의 릴리스 이벤트만 처리
    if: ${{ always() && (needs.changes.outputs.config == 'true' || (github.event_name == 'release' && startsWith(github.event.release.tag_name, 'config-'))) }}
    uses: now-start/workflow/.github/workflows/reusable-java-app.yaml@main
    with:
      module: config
    secrets:
      registry-password: ${{ secrets.GITHUB_TOKEN }}

  gateway:
    needs: changes
    if: ${{ always() && (needs.changes.outputs.gateway == 'true' || (github.event_name == 'release' && startsWith(github.event.release.tag_name, 'gateway-'))) }}
    uses: now-start/workflow/.github/workflows/reusable-java-app.yaml@main
    with:
      module: gateway
    secrets:
      registry-password: ${{ secrets.GITHUB_TOKEN }}
```

- 태그 형식: `{module}-{version}` (예: `config-2.1.5`, `gateway-4.8.0`)
- Docker 이미지: `ghcr.io/now-start/config:2.1.5` (`module`을 이미지 이름으로 사용하고, 이미지 태그는 semver만 사용)
- 릴리스 이벤트는 태그 prefix로 해당 모듈 job만 트리거

> **주의**: `startsWith(tag, 'config-')` 방식은 prefix 충돌 위험이 있습니다.  
> 모듈 이름이 다른 모듈 이름의 prefix가 되지 않도록 설계하세요 (예: `config`와 `config-service` 혼용 금지).

---

## 입력 매개변수

`reusable-java-app.yaml` 호출 시 사용 가능한 파라미터입니다.

| 매개변수 | 필수 | 기본값 | 설명 |
|---|---|---|---|
| `registry-org` | ❌ | `ghcr.io/now-start` | 컨테이너 레지스트리 조직/네임스페이스 |
| `enable-dev` | ❌ | `false` | `true` 시 DEV+PRD 모드, `false` 시 PRD 전용 |
| `module` | ❌ | `''` (비어 있음) | Gradle 서브모듈 이름. 모노레포에서는 Docker 이미지 이름으로도 사용 (예: `config`, `gateway`) |

### 시크릿

| 시크릿 | 필수 | 설명 |
|---|---|---|
| `registry-password` | ✅ | 레지스트리 토큰 (예: `GITHUB_TOKEN`) |

---

## 태그 및 Docker 이미지 명명 규칙

| 레포 패턴 | Git 태그 | Docker 이미지 |
|---|---|---|
| 단일 레포 (`module` 없음) | `{version}` → `5.3.4` | `ghcr.io/now-start/{repository}:{version}` |
| 모노레포 (`module: config`) | `{module}-{version}` → `config-2.1.5` | `ghcr.io/now-start/{module}:{version}` |

Docker 이미지 이름은 단일 레포에서는 레포지토리 이름, 모노레포에서는 `module` 값을 사용합니다. Docker 이미지 태그는 항상 semver만 사용합니다. Git 태그의 모듈 prefix는 promote/rollback 시 자동으로 제거됩니다.

---

## 워크플로우 실행 과정

1. **PR**: 테스트만 실행 (`reusable-java-test.yaml`)
2. **main push (PRD-only 모드, `enable-dev: false`)**:
   - 버전 추출 → 태그 중복 확인 → 빌드/테스트 → Docker 이미지 푸시 (`:version`, `:latest`) → stable Release 생성
3. **main push (DEV+PRD 모드, `enable-dev: true`)**:
   - 버전 추출 → 태그 중복 확인 → 빌드/테스트 → Docker 이미지 푸시 (`:version`, `:dev`) → Pre-release 생성
4. **Release 승격 (prerelease → released)**:
   - `:{version}` 이미지를 `:latest`로 프로모트
5. **Release 다운그레이드 (released → prereleased, 롤백)**:
   - 직전 stable 릴리스의 이미지를 `:latest`로 재태깅

---

## 워크플로우 플로우 (ASCII 다이어그램)

```text
PR (pull_request)
  └─ test-only
       └─ reusable-java-test.yaml

main push (enable-dev = false, PRD-only 모드)
  └─ prepare-prd (reusable-java-prepare.yaml)
       ├─ build.gradle에서 version / Java version 추출
       ├─ 태그 중복 확인 (should-skip)
       └─ skip == false 인 경우에만:
            ├─ build-prd (reusable-java-test.yaml)  ← Gradle build & test
            ├─ docker-prd (reusable-java-docker.yaml)
            │    └─ 이미지 푸시: :{version}, :latest
            └─ release-prd (reusable-java-release.yaml)
                 └─ tag: {version}  /  {module}-{version} (모노레포)
                    prerelease = false

main push (enable-dev = true, DEV+PRD 모드)
  └─ prepare-dev (reusable-java-prepare.yaml)
       ├─ build.gradle에서 version / Java version 추출
       ├─ 태그 중복 확인 (should-skip)
       └─ skip == false 인 경우에만:
            ├─ build-dev (reusable-java-test.yaml)  ← Gradle build & test
            ├─ docker-dev (reusable-java-docker.yaml)
            │    └─ 이미지 푸시: :{version}, :dev
            └─ release-dev (reusable-java-release.yaml)
                 └─ tag: {version}  /  {module}-{version} (모노레포)
                    prerelease = true

release 이벤트 (prerelease → released, PRD 프로모트)
  └─ promote-to-prod (reusable-promote-to-prod.yaml)
       ├─ 태그에서 semver 추출 (config-2.1.5 → 2.1.5)
       └─ 이미지 :{version} → :latest 태깅/푸시

release 이벤트 (released → prereleased, 롤백)
  └─ rollback-on-demote (reusable-rollback.yaml)
       ├─ 모노레포: {module}- prefix로 릴리스 목록 필터링
       ├─ 직전 stable 릴리스 선택
       ├─ 태그에서 semver 추출
       └─ 해당 버전 이미지를 :latest 로 재태깅/푸시
```

---

## 지원 레포지토리

| 레포 | 패턴 |
|---|---|
| [platform](https://github.com/now-start/platform) | 모노레포 (config, eureka, admin, gateway) |
| [nyang-nyang-bot](https://github.com/now-start/nyang-nyang-bot) | 단일 레포 |

---

## 장점

- ✅ **일관성**: 모든 서비스가 동일한 배포 프로세스 사용
- ✅ **유지보수성**: 중앙에서 워크플로우 관리
- ✅ **효율성**: 변경된 모듈만 빌드 (모노레포 경로 필터)
- ✅ **확장성**: 단일 레포/모노레포 모두 동일한 재사용 워크플로우로 지원
