---
date: '2026-07-23T12:50:14+09:00'
draft: false
title: '서비스 계층, DTO와 Form'
tags: ['spring-boot', 'service', 'dto', 'validation']
---

[이전 포스트](../spring-boot-jpa-entity/)에서 엔티티를 다뤘다. 이번 편에서는 데이터베이스를 활용하는 서비스 계층과 실제 웹 서비스를 제공하는 방법을 정리한다.

---

## 서비스 계층과 DTO

데이터를 보다 효율적으로 다루기 위해서 컨트롤러는 Repository를 직접 호출하는 대신 **서비스** 계층을 거쳐서 접근한다.

<div class="grid">
{{< card color="green" title="복잡한 코드 모듈화">}}
여러 개의 컨트롤러가 특정 Repository에 직접 접근한다면, 각 컨트롤러는 해당 Repository를 처리하는 코드를 중복해서 구현해야 한다.

서비스에서 해당 구현을 대신함으로써 모듈화가 가능하다.
{{< /card >}}
{{< card color="blue" title="엔티티 객체를 DTO 객체로 변환">}}
엔티티 클래스는 데이터베이스와 직결된 클래스이므로 직접 사용 시 민감한 데이터가 노출될 수 있다.

해당 클래스를 대신할 DTO 클래스로 변환하는 작업도 마찬가지로 반복해서 구현돼야 할 부분이므로 서비스에서 처리한다.
{{< /card >}}
</div>

실제 코드로 구현하는 방식은 아래와 같다.

```java
@Service
@RequiredArgsConstructor
public class QuestionService {

    private final QuestionRepository questionRepository;

    public List<QuestionDTO> getList() {
        List<Question> questionList = this.questionRepository.findAll();
        List<QuestionDTO> dtoList = new ArrayList<>();
        for (Question q : questionList) {
            dtoList.add(new QuestionDTO(q.getId(), q.getSubject(), q.getCreateDate()));
        }
        return dtoList;
    }

    public void create(String subject, String content) {
        Question q = new Question();
        q.setSubject(subject);
        q.setContent(content);
        q.setCreateDate(LocalDateTime.now());
        this.questionRepository.save(q);
    }
}
```

`@Service`는 이 클래스가 비즈니스 로직을 담당하는 빈이라는 것을 나타낸다. `@RequiredArgsConstructor`는 `final` 필드인 `questionRepository`를 받는 생성자를 자동으로 만들어주는 롬복 어노테이션이다. 이 생성자를 통해 스프링이 자동으로 `QuestionRepository`를 주입한다.

`getList()`는 조회한 `Question` 엔티티를 그대로 반환하지 않고 `QuestionDTO`로 변환해서 반환한다. `QuestionDTO`는 아래처럼 화면에 필요한 필드만 담아 정의한다.

```java
@Getter
@AllArgsConstructor
public class QuestionDTO {
    private Integer id;
    private String subject;
    private LocalDateTime createDate;
}
```

```java
@Controller
@RequiredArgsConstructor
public class QuestionController {

    private final QuestionService questionService;

    @GetMapping("/question/list")
    @ResponseBody
    public List<QuestionDTO> list() {
        return this.questionService.getList();
    }
}
```

컨트롤러에서는 이전처럼 Repository를 직접 사용하는 대신 `QuestionService`를 사용해서 접근하게 된다.

---

## Form 클래스

사용자 입력을 받을 때 비어 있는 값이나 형식에 맞지 않는 값이 입력될 수도 있다. 이를 방지하기 위해서 Form 클래스를 사용해 입력값을 체크할 수 있다.

이 과정은 `spring-boot-starter-validation` 의존성을 추가해야 진행할 수 있다.

```java
@Getter
@Setter
public class QuestionForm {

    @NotEmpty(message = "제목은 필수항목입니다.")
    @Size(max = 200)
    private String subject;

    @NotEmpty(message = "내용은 필수항목입니다.")
    private String content;
}
```

`@NotEmpty`는 값이 비어 있으면 안 된다는 검증 조건이고, `@Size(max = 200)`는 길이 제한을 건다. 만일 조건에 맞지 않으면 입력한 메시지를 에러로 반환한다.

---

### 컨트롤러

컨트롤러에서는 `@Valid`로 검증을 실행하고 `BindingResult`로 그 결과를 받는다.

```java
@PostMapping("/question/create")
public String createQuestion(@Valid QuestionForm questionForm, BindingResult bindingResult) {
    if (bindingResult.hasErrors()) {
        return "question_form";
    }

    this.questionService.create(questionForm.getSubject(), questionForm.getContent());
    return "redirect:/question/list";
}
```

`@Valid`가 `QuestionForm`에 붙은 검증 어노테이션을 기준으로 값을 검사하고, 오류가 있으면 `BindingResult`에 담는다. `bindingResult.hasErrors()`가 참이면 저장 로직을 실행하지 않고 폼 화면으로 다시 돌아간다. 이때 사용자가 입력했던 값은 `questionForm`에 그대로 남아 있어서, 템플릿에서 그 값을 다시 채워 보여줄 수 있다.

---

### Form 작성

위 코드에서 `QuestionForm`을 작성하는 부분이 없는 걸 볼 수 있는데 이는 폼 데이터를 `QuestionForm`에 채워주는 것은 스프링이 자동으로 처리하기 때문이다.

HTML `<form>`은 아래처럼 각 입력 요소의 `name` 속성을 key로, 사용자가 입력한 값을 value로 하는 key-value 쌍으로 데이터를 전송한다.

```html
<form action="/question/create" method="post">
    <input type="text" name="subject">
    <textarea name="content"></textarea>
    <button type="submit">저장</button>
</form>
```

스프링은 이 key 값과 `QuestionForm`의 필드명(`subject`, `content`)이 일치하는지 확인하고, 일치하면 해당 필드의 setter를 호출해서 값을 채워 넣는다. `QuestionForm`에 `@Setter`가 필요한 이유도 이 때문이다.
