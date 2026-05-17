---
date: '2026-05-18T00:42:48+09:00'
draft: false
title: 'Hugo로 GitHub Pages 블로그 만들기'
---

# Hugo로 GitHub Pages 블로그 만들기

> 간편하게 시작하는 나만의 블로그.

---

## 왜 Hugo인가?

블로그를 시작할 때는 많은 선택지가 있다. 하지만 개발자라면 한번쯤은 GitHub Pages를 사용한, 코드로 완성하는 블로그를 꿈꿀 것이다.
그렇다면 다른 쟁쟁한 후보를 제치고 왜 Hugo인가? 

| 항목 | 내용 |
|------|------|
| **속도** | 밀리초(ms) 단위의 압도적인 사이트 빌드 및 라이브 리로드 속도 |
| **세팅** | 의존성 없는 단일 실행 파일 구성으로 매우 간편한 로컬 환경 설정 |
| **작성** | 복잡한 HTML 대신 가독성 높은 마크다운(.md) 기반의 콘텐츠 관리 |
| **관리** | 레이아웃과 콘텐츠의 완전한 분리로 효율적인 전체 사이트 유지보수 |
| **배포** | GitHub Actions 연동을 통해 푸시(Push) 한 번으로 배포 자동화 |

HTML이나 Jekyll도 고려했지만 Hugo를 선택한 이유는 단순하다.
MarkDown을 통해 HTML보다 편리하게 글을 작성할 수 있고, 단순히 Hugo 하나만 설치해도 진행할 수 있었다.
특히 블로그 글이 많아지더라도 압도적인 빌드 속도를 유지할 수 있다는 점에서 선택했다.

---

## 설치 과정

### 1. GitHub 저장소 생성

우선 블로그를 작성할 repository를 생성해야 한다. 이때 저장소 이름은 반드시 '\<사용자 명\>.github.io'여야 GitHub에서 이 저장소를 GitHub Pages라고 인식할 수 있다.

> 예시: GitHub ID가 'User123'이라면 → 'User123.github.io'

---

### 2. Hugo 설치

Mac 사용자라면 Homebrew를 통해 간편하게 Hugo를 설치할 수 있다.

```shell
brew install hugo
```

---

### 3. 프로젝트 생성

우선 원하는 위치에서 아래 명령어를 실행하여 hugo 프로젝트를 생성한다.

```shell
hugo new site <프로젝트 명>
```

생성된 폴더 구조:

```
github-pages/
├── archetypes/    # 블로그 글 생성시 기본 템플릿
├── content/       # 블로그 글 (.md)
├── layouts/       # 커스텀 HTML 레이아웃. themes/ 보다 우선순위
├── static/        # 이미지, CSS 등 정적 파일
├── themes/        # 테마
└── hugo.toml      # 블로그 설정. YAML 등 형식도 지원
```

---

### 4. 테마 설치

Hugo는 기본 테마를 제공하지 않으므로 마음에 드는 테마를 추가해야 한다. 이때는 Submodule을 활용하는데 그 이유는 아래와 같다.
 - `git submodule update --remote` 명령어로 테마 최신화 가능
 - `GitHub Actions`를 통한 자동 배포 시  yml파일에서 `submodules: true` 옵션을 통해 원작자의 저장소에서 올바르게 가져와 빌드합니다.

```shell
# 깃 초기화
git init

# 테마 추가(여기서는 PaperMod 테마 사용)
git submodule add https://github.com/adityatelange/hugo-PaperMod.git themes/PaperMod
```

`hugo.toml` 수정

```toml
baseURL = "https://<사용자 명>.github.io/"
languageCode = "ko-kr"
title = "내 블로그 이름"
theme = "PaperMod"
```

이때 테마를 미리 보고 싶다면 `hugo server`를 사용하여 배포 업이 local에서 확인할 수 있다.

---

### 5. GitHub Actions 설정

[peaceiris/actions-hugo](https://github.com/peaceiris/actions-hugo) 를 사용해 자동 배포를 구성한다.  
Hugo 설치부터 빌드, gh-pages 배포까지 한 번에 처리해주는 공식 GitHub Action이다.
 
```shell
mkdir -p .github/workflows
touch .github/workflows/deploy.yml
```
 
`deploy.yml` 내용:
 
```yaml
name: GitHub Pages
 
on:
  push:
    branches:
      - main
 
permissions:
  contents: write
 
jobs:
  deploy:
    runs-on: ubuntu-22.04
    concurrency:
      group: ${{ github.workflow }}-${{ github.ref }}
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: true  # PaperMod 테마 포함
          fetch-depth: 0    # 글 수정일 추적을 위해 전체 히스토리 필요
 
      - name: Setup Hugo
        uses: peaceiris/actions-hugo@v3
        with:
          hugo-version: 'latest'
          extended: true    # PaperMod는 Hugo Extended 버전 필요
 
      - name: Build
        run: hugo --minify
 
      - name: Deploy
        uses: peaceiris/actions-gh-pages@v4
        if: github.ref == 'refs/heads/main'
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./public
```

---

### 6. 배포

위 과정이 전부 완료되었다면 배포를 시작하자.

```shell
git remote add origin git@github.com:<사용자 명>/<사용자 명>.github.io.git
git add .
git commit -m "블로그 시작"
git branch -M main
git push -u origin main
```

배포 후 Actions가 완료되면 `gh-pages` 브랜치가 자동 생성된다. 이제 `main`은 Hugo 소스코드가 포함되는 내 작업 공간이고, `gh-pages`는 실제 웹에 보여지는 파일이다.


따라서 GitHub Pages가 `gh-pages` 브랜치를 바라보게 해야 하므로 설정(Settings) 탭에서 Branch를 `gh-pages`로 수정해 준다.

---

### 7. 글 작성 방법

글을 작성하기 전에 우선 템플릿 부터 수정해야 한다. 기본 템플릿은 TOML 형식이기에 작성하기 편리한 YAML 형식으로 변경하는게 편하며, 배포를 위해선 `draft`를 `false`로 설정해야 한다.

`archtypes/default.md` 내용:

```YAML
---
date: '{{ .Date }}'
draft: false
title: '{{ replace .File.ContentBaseName "-" " " | title }}'
---
```

이후 글을 작성할 때는 아래 스크립트로 파일을 생성 후, 아래에 내용을 작성하면 된다. Actions로 자동화 되었기에 `push`만 하면 블로그에 자동 반영된다. 

```shell
hugo new content/posts/<글 제목>.md
```