---
date: '2026-07-22T13:40:40+09:00'
draft: false
title: 'ORM, JPA와 엔티티'
---

[이전 포스트](../spring-boot-controller-lombok/)에서 컨트롤러와 롬복을 다뤘다. 이번 편에서는 JPA 입문에 대해서 작성한다.

---

## ORM과 JPA

<div class="grid">
{{< card color="green" title="ORM" >}}
SQL 대신 **자바 클래스**를 통해 데이터베이스를 관리하는 도구.

DBMS의 종류와 무관하게 일관된 코드를 사용 가능.
{{< /card >}}
{{< card color="blue" title="JPA" >}}
ORM의 기술 표준으로 사용하는 인터페이스의 모음.

일반적으로 Hibernate 프레임워크를 통해 구현
{{< /card >}}
</div>

자바를 이해하지 못하는 데이터베이스를 위해 위 도구들을 사용해서 작업을 진행할 수 있다.

---

## Entity 작성

**엔티티**는 ORM에서 데이터베이스 테이블에 매핑되는 자바 클래스다. 게시판의 질문 데이터를 저장할 `Question` 클래스를 엔티티로 작성하면 아래와 같다.

```java
@Entity
public class Question {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(length = 200)
    private String subject;

    @Column(columnDefinition = "TEXT")
    private String content;

    private LocalDateTime createDate;

    @OneToMany(mappedBy = "question", cascade = CascadeType.REMOVE)
    private List<Answer> answerList;
}
```

`@Entity`는 이 클래스가 JPA가 관리하는 엔티티이고, 이름과 같은 `QUESTION` 테이블에 매핑된다는 것을 나타낸다. `@Id`는 이 필드가 테이블의 기본키라는 뜻이고, `@GeneratedValue(strategy = GenerationType.IDENTITY)`는 기본키 값을 직접 지정하지 않고 데이터베이스의 자동 증가 기능에 위임한다는 뜻이다. `subject`, `content`처럼 별도 설정이 필요 없는 필드는 필드명이 그대로 컬럼명이 되지만, 컬럼 길이나 타입을 추가적으로 지정해야 할 때는 `@Column`으로 조정한다.

애플리케이션을 실행한 뒤 브라우저에서 `http://localhost:8080/h2-console`에 접속하면 JDBC URL 입력창이 나온다. 여기에 `application.properties`에 설정한 `jdbc:h2:mem:testdb`를 입력하고 연결하면, 엔티티 클래스만 작성했을 뿐인데 `QUESTION` 테이블이 이미 만들어져 있는 걸 확인할 수 있다.

SQL에서 외래키를 다루는 것처럼 외부 엔티티와 관계를 가질 땐 특수한 애너테이션을 사용한다. 위 예시에선 `@OneToMany`를 통해 질문에서 답변 참조 시 `Answer`엔티티의 `question` 속성을 통해 접근하고자 했다.

---

## Repository 작성

엔티티만 가지고는 테이블의 CRUD를 구현할 수 없다. 테이블의 데이터를 관리하기 위해선 데이터베이스와 연동하는 JPA Repository가 필요하다.

```java
public interface QuestionRepository extends JpaRepository<Question, Integer> {

}
```

위 interface를 repository로 만들기 위해 `JpaRepository`를 상속한다. `JpaRepository<Question, Integer>`는 `Question`엔티티로 repository를 생성한다는 의미이며 해당 엔티티의 기본키가 Integer임을 추가로 지정해야 한다. 별도 구현 없이 상속만으로 `save`, `findAll`, `findById`, `delete` 같은 CRUD 메서드를 바로 사용할 수 있다.

---

## Repository 활용

### CREATE

```java
@Test
void testCreate() {
    Question q1 = new Question();
    q1.setSubject("질문 있습니다.");
    q1.setContent("질문 내용입니다.");
    q1.setCreateDate(LocalDateTime.now());
    this.questionRepository.save(q1);
}
```

`save` 메서드는 엔티티가 새로 생성된 것이면 `INSERT`, 이미 존재하는 것이면 `UPDATE` 쿼리를 실행한다.

---

### READ

```java
@Test
void testRead() {
    // 전체 조회
    List<Question> all = this.questionRepository.findAll();

    // 기본키로 단건 조회
    Optional<Question> oq = this.questionRepository.findById(1);
    if (oq.isPresent()) {
        Question q = oq.get();
    }
}
```

`findById`는 데이터가 없을 수도 있기 때문에 `Question`을 바로 반환하지 않고 `Optional<Question>`으로 감싸서 반환한다.

필드값으로 조회하고 싶다면 `QuestionRepository`에 이름 규칙에 맞는 메서드를 직접 선언한다.

```java
public interface QuestionRepository extends JpaRepository<Question, Integer> {
    Question findBySubject(String subject);
}
```

메서드를 구현하지 않아도 JPA가 `findBySubject`라는 이름을 분석해 `subject` 필드로 조회하는 쿼리를 자동으로 만들어준다.

```java
@Test
void testReadBySubject() {
    Question q = this.questionRepository.findBySubject("질문 있습니다.");
}
```

---

### UPDATE

```java
@Test
void testUpdate() {
    Optional<Question> oq = this.questionRepository.findById(1);
    Question q = oq.get();
    q.setSubject("수정된 제목");
    this.questionRepository.save(q);
}
```

수정은 별도의 메서드가 없다. 조회한 엔티티의 값을 바꾼 뒤 다시 `save`를 호출하면, 기본키가 이미 존재하므로 JPA가 `UPDATE` 쿼리로 처리한다.

---

### DELETE

```java
@Test
void testDelete() {
    Optional<Question> oq = this.questionRepository.findById(1);
    Question q = oq.get();
    this.questionRepository.delete(q);
}
```

`delete`는 삭제할 엔티티를 인자로 받는다. 기본키만 알고 있다면 `deleteById`를 사용해도 된다.

