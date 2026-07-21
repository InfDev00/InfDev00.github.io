---
date: '2026-07-21T16:18:49+09:00'
draft: true
title: '스프링 부트 시작하기 : 컨트롤러와 롬복'
---

백엔드 개발을 공부하고 싶어서 스프링 부트를 시작해 보고자 한다. 우선 익숙한 언어인 자바를 활용한 웹 프레임워크라는 점, 그리고 보편적으로 활용하고 있는 프레임워크라는 점에서 선택했다.

{{< linkcard
  url="https://product.kyobobook.co.kr/detail/S000211685975"
  title="Do it! 점프 투 스프링 부트 3"
  description="박응용 저 · 이지스퍼블리싱 — 백엔드 개발에 필요한 스프링 부트의 핵심만 담았다"
  site="교보문고"
  image="https://contents.kyobobook.co.kr/sih/fit-in/400x0/pdt/9791163035398.jpg"
>}}

위 책을 통해서 학습을 진행했다.

---

## 웹 서비스와 컨트롤러

웹 서비스는 기본적으로 클라이언트에서 요청을 보내고, 서버에서 응답하는 구조로 이뤄진다. 요청을 보낼 때는 서버의 주소인 IP 주소, 혹은 서버 주소를 대체할 도메인 명을 알아야 한다. 해당 요소를 통해 호출하면 해당되는 웹 서버가 호출되고 서버에선 적절한 응답을 클라이언트에게 돌려주는 방식이다.

서버에서 이러한 요청을 처리하는 자바 클래스가 바로 **컨트롤러**이다. 컨트롤러에선 적절한 URL을 메서드에 매핑하여 처리할 수 있다.

```java
@Controller
public class HomeController {

    @GetMapping("/hello")
    @ResponseBody
    public String hello() {
        return "Hello, Spring Boot!";
    }
}
```

`@Controller`는 이 클래스가 URL 요청을 처리하는 컨트롤러임을 스프링 부트에 알린다. `@GetMapping("/hello")`는 `/hello`로 들어오는 GET 요청을 `hello` 메서드에 연결한다. 서버를 실행한 뒤 브라우저에서 `http://localhost:8080/hello`에 접속하면 반환값이 그대로 화면에 나타난다.

추가로 메서드의 반환값이 출력값 그대로라는 걸 알려주려면 `@ResponseBody`를 붙여야 한다. 이 어노테이션 없이 문자열을 반환하면 스프링 부트는 그 문자열을 템플릿 파일 이름으로 해석해서 찾다가 오류를 낸다.

---

## 롬복(lombok)

자바 클래스는 필드를 캡슐화하기 위해 getter/setter와 생성자를 함께 작성하는 경우가 많다. 필드가 늘어날수록 이 코드는 기계적으로 반복된다.

```java
public class Question {
    private Integer id;
    private String subject;
    private String content;
    private LocalDateTime createDate;

    public Integer getId() {
        return id;
    }

    public void setId(Integer id) {
        this.id = id;
    }

    public String getSubject() {
        return subject;
    }

    public void setSubject(String subject) {
        this.subject = subject;
    }

    // content, createDate도 동일한 패턴 반복
}
```

**롬복**은 이런 반복 코드를 어노테이션으로 대체해주는 라이브러리다. 컴파일 시점에 어노테이션을 분석해 필요한 코드를 자동으로 생성한다.

```java
// Question.java
@Getter
@Setter
public class Question {
    private Integer id;
    private String subject;
    private String content;
    private LocalDateTime createDate;
}

// Answer.java
@RequiredArgsConstructor
public class Answer {
    private final Integer id;
    private final String content;
}

// Main.java
public class Main {
    public static void main(String[] args) {
        Question question = new Question();
        question.setId(1);
        question.setContent("내용");

        Answer answer = new Answer(1, "답변");
    }
}
```

`@Getter`와 `@Setter`가 모든 필드명에 get/set을 붙인 메서드를 자동으로 생성한다.

또한 `@RequiredArgsConstructor`를 사용해서 `final`을 붙인 필드들을 필요로 하는 생성자가 자동으로 추가된다.

롬복은 캡슐화가 자주 사용되는 java에서 보다 편리하게 코드를 작성시켜주는 도구이다. 이를 활용하면 코드 생산성을 더욱 개선할 수 있다.
