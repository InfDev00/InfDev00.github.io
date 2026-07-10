---
date: '2026-07-10T21:09:48+09:00'
draft: false
title: 'SQL 활용'
---

SQL 명령어를 사용해 데이터베이스를 정의/조작/제어할 수 있다. 이 명령들이 어떻게 활용되는지 살펴본다.

---

## 데이터 정의어

데이터 정의어는 데이터베이스 자체를 생성·변경·제거할 때 사용된다.

### CREATE

```sql
CREATE TABLE <테이블 명> (<속성 명> <타입> [<제약 조건>], ...
[<테이블 제약 조건>]);
```

여기서 `<제약 조건>`은 각 속성에 거는 제약이다. `UNIQUE`, `NOT NULL` 등의 제약을 걸 수 있다.

`<테이블 제약 조건>`은 테이블 자체에 걸리는 제약으로 외래키, 기본키나 처리 옵션 등을 정의한다.

```sql
-- 외래키
[CONSTRAINT <제약 명>] FOREIGN KEY (<속성 명>, ...) REFERENCES <참조 테이블> (<속성 명>, ...)

-- 기본키
PRIMARY KEY (<속성 명>, ...)

-- 수정/제거 옵션
ON UPDATE/DELETE <처리 옵션>
```

처리 옵션에는 `NO ACTION`, `SET NULL`, `CASCADE`, `RESTRICT` 등이 있다. 이때 `CASCADE`는 관련된 튜플 전부에 동일하게 처리하도록 하고, `RESTRICT`는 관련된 튜플이 없을 때만 실행한다.

---

### ALTER

`ALTER`는 여러 활용법이 있다.

```sql
ALTER TABLE <테이블 명> ADD <속성 명> <타입> [<위치 옵션>];
```

위 명령을 통해 새로운 속성을 추가한다. 이때 위치는 `FIRST`로 맨 앞에 두거나, `AFTER <속성 명>`을 사용해 특정 속성 뒤에 둘 수 있다.

```sql
ALTER TABLE <테이블 명> MODIFY <속성 명> <타입>;
ALTER TABLE <테이블 명> RENAME COLUMN <원본 속성 명> TO <신규 속성 명>;
```

`MODIFY`는 타입을, `RENAME COLUMN`은 속성 명을 수정한다.

```sql
ALTER TABLE <테이블 명> ADD CONSTRAINT <제약 명> <제약 조건>;
ALTER TABLE <테이블 명> ENABLE/DISABLE/DROP CONSTRAINT <제약 명>;
```

위 명령어로 새로운 제약 조건을 추가하거나, 활성화/비활성화 및 제거를 할 수 있다.

---

### DROP

```sql
DROP TABLE <테이블 명> [<처리 옵션>];
TRUNCATE TABLE <테이블 명>;
```

우선 `DROP`을 통한 제거는 테이블 자체를 제거한다. 이때 `<처리 옵션>`에는 `CASCADE`나 `RESTRICT`만 올 수 있다.

`TRUNCATE`는 테이블 비우는 명령어다. 테이블 자체는 살아있지만 내부 데이터만 지워진다.

---

## 데이터 조작어

데이터베이스의 데이터를 조회/삽입/삭제/변경의 작업을 할 때 사용한다.

### INSERT

```sql
INSERT INTO <테이블 명> VALUES (<값>, ...);
INSERT INTO <테이블 명> (<속성명>, ...) VALUES (<값>, ...);
INSERT INTO <테이블 명> (<속성명>, ...) <SELECT 문>;
```

`INSERT`는 항상 `INSERT INTO`로 실행된다.

---

### UPDATE

```sql
UPDATE <테이블 명> SET <속성 명> = <값> WHERE <조건식>;
```

`UPDATE`는 해당 조건에 맞는 대상에서 해당 속성의 값을 변경한다.

---

### DELETE

```sql
DELETE FROM <테이블 명> WHERE <조건식>;
```

`DELETE`는 항상 `DELETE FROM`으로 실행되며 조건에 맞는 튜플을 제거한다.

---

### SELECT

```sql
SELECT [DISTINCT] <속성 명>, ... FROM <테이블 명> 
[WHERE <조건식>]
[GROUP BY <속성 명> [HAVING <조건식>]]
[ORDER BY <속성 명> [ASC/DESC]];
```

`SELECT`는 기본으로 중복을 허용한다. 다만 `DISTINCT` 옵션 사용 시 중복을 제거할 수 있다.

또한 `<테이블 명>`에서 그냥 테이블 대신 `JOIN`을 사용할 수도 있다. `<T1> JOIN <T2> ON <조건식>` 꼴로 사용하며 `JOIN` 대신 `LEFT/RIGHT/FULL OUTER JOIN`도 사용가능하다.

### 조건식

데이터 조작어에서는 조건식을 많이 사용한다. 기본적으로는 `<속성명> > 2` 이런 방식으로 사용하지만 명령어를 통해 더욱 다양하게 표현할 수 있다.

```sql
<조건식> AND <조건식>                -- 모두 참이어야 함
<조건식> OR <조건식>                 -- 하나만 참이어도 됨

<속성명> BETWEEN <하단> AND <상단>   -- 범위 조건 (양 끝값 포함)
<속성명> IN (<값>, ...)             -- 여러 값 중 하나와 일치
<속성명> LIKE <패턴>                 -- %: 0개 이상 문자, _: 1개 문자
<속성명> IS NULL                    -- NULL 여부 (= NULL로는 비교 불가)

하위 질의                           -- 하위 질의 결과와 비교
    <속성명> = (<SELECT 문>)
    <속성명> IN (<SELECT 문>)
    EXISTS (<SELECT 문>)
```

---

## 데이터 제어어

데이터베이스 사용자에게 권한을 부여하거나 회수할 때 사용한다.

### GRANT

```sql
GRANT <권한>, ... ON <객체> TO <사용자> [WITH GRANT OPTION];
```

`<권한>`에는 `SELECT`, `INSERT`, `UPDATE`, `DELETE` 등이 들어간다. `WITH GRANT OPTION`을 붙이면 권한을 받은 사용자가 다른 사용자에게 그 권한을 다시 부여할 수 있다.

---

### REVOKE

```sql
REVOKE <권한>, ... ON <객체> FROM <사용자> [CASCADE];
```

`REVOKE`는 부여된 권한을 회수한다. `CASCADE`를 붙이면 `GRANT OPTION`으로 전달된 권한까지 연쇄적으로 회수한다.