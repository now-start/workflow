# now-start/.github

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
name: Build and Deploy
on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    uses: now-start/.github/.github/workflows/reusable-java-build.yml@main
    with:
      service-name: your-service-name  # 예: admin-service, lotto-service
    secrets:
      registry-password: ${{ secrets.GITHUB_TOKEN }}
```

#### 입력 매개변수

| 매개변수 | 필수 | 기본값 | 설명 |
|---------|------|--------|------|
| `service-name` | ✅ | - | Docker 이미지 태깅을 위한 서비스 이름 |
| `java-version` | ❌ | '17' | 사용할 Java 버전 |
| `gradle-version` | ❌ | 'wrapper' | 사용할 Gradle 버전 |
| `registry` | ❌ | 'ghcr.io' | 컨테이너 레지스트리 URL |
| `registry-username` | ❌ | `${{ github.actor }}` | 레지스트리 사용자명 |

#### 시크릿 매개변수

| 시크릿 | 필수 | 설명 |
|--------|------|------|
| `registry-password` | ❌ | 레지스트리 비밀번호/토큰 (기본값: GITHUB_TOKEN) |

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
3. **릴리스 생성**: 새 버전인 경우 태그 및 릴리스 자동 생성
4. **빌드**: Gradle로 애플리케이션 빌드
5. **Docker**: Docker 이미지 빌드 및 태깅
6. **배포**: GHCR에 이미지 푸시

## 장점

- ✅ **일관성**: 모든 서비스가 동일한 배포 프로세스 사용
- ✅ **유지보수성**: 중앙에서 워크플로우 관리
- ✅ **효율성**: 중복 코드 제거
- ✅ **확장성**: 새로운 서비스도 쉽게 추가 가능