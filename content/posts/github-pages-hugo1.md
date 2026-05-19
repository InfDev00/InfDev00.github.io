---
date: '2026-05-19T00:42:48+09:00'
draft: false
title: 'Hugo로 GitHub Pages 블로그 만들기 (2)'
---

> 간단하게 시작하는 블로그 디자인
---

## 다양한 테마를 적용하는 방법

Hugo는 이전 편에서 PapaMod를 사용했던 것처럼 다양한 테마를 제공한다. 이러한 테마들은 [Hugo Themes](https://themes.gohugo.io/) 사이트에서 간편하게 확인하고 적용할 수 있다.

테마를 적용하는 건 submodule을 사용해서 간단하게 진행할 수 있다.
```shell
# 기존 테마 제거
git submodule deinit -f "themes/<기존 테마 명>"
git rm -f "themes/<기존 테마 명>"
rm -rf ".git/modules/themes/<기존 테마 명>"

# 새 테마 추가
git submodule add "<git 저장소 URL>" "themes/<새 테마 명>"
```

이후 `hugo.yaml`에서 theme 부분을 수정해야 한다. 참고로 이 시점에서 편의성의 이유로 `hugo.toml`도 `hugo.yaml`로 변경했다.
```shell
theme = "<새 테마 명>"
```

---

## 메뉴와 사이드바 구현하기

이렇게 만들어진 블로그는 아직은 조금 심심하다. 이제는 블로그의 여러 기본 기능들을 추가할 차례이다.

### 상단 메뉴 구현

PaperMod에서 상단 메뉴는 설정 파일의 `menu.main`에서 관리한다. 따라서 아래의 코드를 `hugo.yaml` 하단에 추가해 주면 된다.

```shell
menu:
  main:
  # 메인 창. 최신 글 목록을 보여준다.
    - name: "Home"
      url: "/"
      weight: 10
  # 자기 소개창. content/about.md 파일을 생성하고 그 안에 자기소개 내용을 작성한다.
    - name: "About"
      url: "/about/"
      weight: 20
  # GitHub 링크
    - name: "GitHub"
      url: "https://github.com/<사용자 명>"
      weight: 30

```

### 사이드바 구현

PaperMode는 기본적으로 1단 레이아웃, 즉 하나의 column 구조를 사용하는 테마이다. 하지만 GitHub Pages 답게 코드를 통해 간편하게 구현할 수 있다.

**1.사이드바 템플릿 생성**

`layouts/partials/sidebar.html` 파일을 생성하고 아래 내용을 작성한다.
```html
<aside class="sidebar">
    <section class="widget">
        <h3 class="widget-title">Sections</h3>
        <ul class="widget-list">
            {{ range .Site.Sections }}
            <li>
                <a href="{{ .Permalink }}">{{ .Title }} <span>({{ len .Pages }})</span></a>
            </li>
            {{ end }} {{/* 반복문 종료 */}}
        </ul>
    </section>
</aside>
```
우선 `range .Site.Sections`는 Hugo 템플릿 문법으로 `.Site.Sections`의 데이터를 가져와 순회한다. 즉 `content/` 폴더의 최상위 폴더들을 순회한다.

순회하며 출력하는 내용은 `.Title`로 폴더(섹션) 명을, `len .Pages`로 해당 폴더의 페이지 수를 보여주며 `.Permalink`로 해당 폴더로 향하는 링크를 달아두는 방식이다.

---

**2. 메인 레이아웃 수정**

메인 레이아웃에 사이드 바를 포함하고 있지 않으므로 테마를 커스텀 해야 한다.
`themes/PaperMod/layouts/_default/baseof.html` 경로의 파일을 복사 후, `layouts/_default/baseof.html` 파일을 생성하여 붙여넣는다.

`baseof.html` 파일은 블로그의 뼈대를 담당하는 기본 파일이며 `_default`는 적용할 디자인이 없을 때 적용하는 fallback 폴더이다. Hugo는 `content/` 폴더와 `layouts/` 내부 폴더의 이름이 일치하면 해당 디자인을 적용해 준다. 예를 들어 `content/posts/` 폴더에 적용하려면 `layouts/posts/` 폴더에 해당 디자인 `.html` 파일을 담아서 처리할 수 있다.


`baseof.html`에서 `<main class="main">` 부분을 아래로 교체해 주면 된다.
```html
<!--변경 전-->
<main class="main">
  {{- block "main . }}{{ end }}
</main>

<!--변경 후-->
<div class="container-with-sidebar">
    {{- partial "sidebar.html" . -}}
    <main class="main">
        {{- block "main" . }}{{ end }}
    </main>
</div>
```
위 코드를 통해서 이전에 만들었던 `partial/sidebar.html`을 불러와서 사용한다.

---

**3. CSS로 디자인 적용하기**

사이드바를 추가했지만 아직 자연스럽게 보이지 않는다. 이를 위해서 디자인 파일이 필요하다. `assets/css/extended/custom.css` 파일을 생성하고 아래 내용을 추가한다. 참고로 아래 코드는 AI를 통해 간단하게 생성한 코드이므로 자세하게 참고할 필요는 없다.

<details>
<summary>custom.css 코드</summary>

```css
@media screen and (min-width: 768px) {
    .container-with-sidebar {
        display: flex;
        max-width: calc(var(--main-width) + var(--gap) * 2 + 250px);
        margin: 0 auto;
        padding: 0 var(--gap);
    }
    
    .sidebar {
        width: 250px;
        flex-shrink: 0;
        padding-top: var(--main-top-gap);
        margin-right: var(--gap);
    }

    .main {
        flex-grow: 1;
        max-width: var(--main-width);
    }
}

/* 모바일 화면에서는 사이드바가 위로 가도록 처리 */
@media screen and (max-width: 767px) {
    .sidebar {
        padding: var(--gap);
        border-bottom: 1px solid var(--border);
    }
}

/* 사이드바 디자인 리터칭 */
.widget-title {
    margin-bottom: 15px;
    font-size: 1.2rem;
    font-weight: bold;
    color: var(--primary);
}
.widget-list {
    list-style: none;
    padding: 0;
    margin: 0;
}
.widget-list li {
    margin-bottom: 10px;
}
.widget-list a {
    color: var(--secondary);
    text-decoration: none;
}
.widget-list a:hover {
    color: var(--primary);
    text-decoration: underline;
}
```
</details>

PaperMod 테마는 빌드 시 `assets/css/extended`에서 유저들의 `.css` 파일을 가져온다. 따라서 `extended/`를 통해 커스텀 디자인을 넣어 둘 수 있다.