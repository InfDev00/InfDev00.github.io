---
date: '2026-05-30T16:00:42+09:00'
draft: true
title: 'C# 서버 입문하기 — ASP.NET Core Minimal API'
---

> C# 서버 입문자를 위한 가이드

---

Unity 개발자이기에 서버 입문 과정은 익숙한 C#을 사용하는 방식으로 시작했다. 아래 내용은 Microsoft 공식 가이드를 기반으로 작성했다.

{{< linkcard 
  url="https://learn.microsoft.com/en-us/aspnet/core/tutorials/min-web-api?view=aspnetcore-10.0" 
  title="Tutorial: Create a Minimal API with ASP.NET Core" 
  description="Official tutorial to build a complete CRUD REST API with minimal code using ASP.NET Core (.NET 10)"
  site="Microsoft Learn"
  image="https://learn.microsoft.com/en-us/media/logos/logo-ms-social.png"
>}}

첫 시작이기에 우선 최대한 간단한 방식인 **Minimal API**를 사용했다.

---

## 실행 과정

### 1. 기본 프로젝트 생성

```shell
dotnet new web -o TodoApi

dotnet add package Microsoft.EntityFrameworkCore.InMemory
dotnet add package Microsoft.AspNetCore.Diagnostics.EntityFrameworkCore
```
우선 `dotnet` 명령어로 빈 ASP.NET CORE 프로젝트를 생성한다. 여기서는Todo에 대해 간단한 CRUD 기능을 구현할 것이다.  
이 과정에서 사용할 패키지를 추가로 설치한다.

### 2. 모델 및 데이터베이스 생성

기본 모델 클래스와 `EntityFrameworkCore`를 활용한 데이터베이스 콘텍스트를 생성한다.

```csharp
//Todo.cs
public class Todo
{
    public int Id{ get; set; }
    public string? Name{ get; set; }
    public bool IsComplete{ get; set; }
}

//TodoDb.cs
using Micorosoft.EntityFrameworkCore;

```


기본 `Todo` class와 이를 관리하는 데이터베이스 class를 추가한다.

```csharp
//Todo.cs
public class Todo
{
    public int Id{ get; set; }
    public string? Name{ get; set; }
    public bool IsComplete{ get; set; }
}

//TodoDb.cs
using Microsoft.EntityFrameworkCore;

public class TodoDb : DbContext
{
    public TodoDb(DbContextOptions<TodoDb> options) : base(options) { }
    
    public DbSet<Todo> Todos => Set<Todo>();
}
```


## 프로젝트 구조

실제로 만든 Todo API 프로젝트의 구조는 단순하다.

```
TodoApi/
├── Program.cs        # 서버 진입점, 엔드포인트 등록
├── Todo.cs           # 도메인 모델
├── TodoDb.cs         # DB 컨텍스트
└── TodoApi.csproj    # 패키지 의존성
```

코드 파일 3개(`Program.cs`, `Todo.cs`, `TodoDb.cs`)로 완전한 CRUD API를 구성할 수 있다.

---

## 핵심 개념

### 빌더 패턴: builder와 app

ASP.NET Core의 서버 시작 코드는 두 단계로 나뉜다.

```csharp
var builder = WebApplication.CreateBuilder(args); // 서비스 등록 단계
// ... 서비스 추가

var app = builder.Build(); // 앱 구성 단계
// ... 미들웨어·엔드포인트 등록

app.Run(); // 서버 시작
```

`builder`는 서버가 사용할 도구들을 등록하는 단계고, `app`은 그 도구들을 실제로 어떻게 연결할지 정의하는 단계다.

### 의존성 주입(DI)

ASP.NET Core의 핵심 철학 중 하나는 **의존성 주입**이다. 서비스(DB 컨텍스트, 로거 등)를 `builder.Services`에 등록해두면, 엔드포인트 핸들러에서 매개변수로 자동으로 받아올 수 있다.

```csharp
// 서비스 등록: InMemory DB를 사용하는 TodoDb 등록
builder.Services.AddDbContext<TodoDb>(opt =>
    opt.UseInMemoryDatabase("TodoList"));

// 엔드포인트에서 DI로 자동 주입받음
app.MapGet("/todoitems", async (TodoDb db) =>
    await db.Todos.ToListAsync());
```

`TodoDb db`를 직접 `new`로 생성하지 않아도 된다. ASP.NET Core가 등록된 서비스에서 찾아 자동으로 주입한다.

### 라우트 매핑

HTTP 메서드별로 엔드포인트를 등록한다.

```csharp
app.MapGet("/경로", 핸들러);         // GET
app.MapPost("/경로", 핸들러);        // POST
app.MapPut("/경로/{id}", 핸들러);    // PUT
app.MapDelete("/경로/{id}", 핸들러); // DELETE
```

URL에 `{id}`처럼 중괄호로 감싸면 경로 변수를 받을 수 있다. 핸들러의 매개변수 이름과 자동으로 매칭된다.

---

## 모델과 DB 컨텍스트

### Todo 모델

```csharp
public class Todo
{
    public int Id { get; set; }
    public string? Name { get; set; }  // nullable: 이름 없는 Todo 허용
    public bool IsComplete { get; set; }
}
```

`string?`의 `?`는 null을 허용한다는 의미다. .NET 6부터 nullable이 기본 활성화되어 있어서, null이 가능한 타입은 명시적으로 표시해야 한다.

### DB 컨텍스트

```csharp
class TodoDb : DbContext
{
    public TodoDb(DbContextOptions<TodoDb> options) : base(options) { }

    public DbSet<Todo> Todos => Set<Todo>(); // Todos 테이블
}
```

Entity Framework Core의 `DbContext`를 상속받아 DB 접근을 담당하는 클래스를 만든다. `DbSet<Todo>`는 Todo 테이블에 대한 LINQ 쿼리 인터페이스다.

---

## CRUD 엔드포인트

### 조회 (GET)

```csharp
// 전체 목록 조회
app.MapGet("/todoitems", async (TodoDb db) =>
    await db.Todos.ToListAsync());

// 완료된 항목만 필터링
app.MapGet("/todoitems/complete", async (TodoDb db) =>
    await db.Todos.Where(t => t.IsComplete).ToListAsync());

// ID로 단건 조회 (없으면 404)
app.MapGet("/todoitems/{id}", async (int id, TodoDb db) =>
    await db.Todos.FindAsync(id)
        is Todo todo
            ? Results.Ok(todo)
            : Results.NotFound());
```

### 생성 (POST)

```csharp
app.MapPost("/todoitems", async (Todo todo, TodoDb db) =>
{
    db.Todos.Add(todo);
    await db.SaveChangesAsync();
    // 201 Created와 함께 생성된 리소스 경로 반환
    return Results.Created($"/todoitems/{todo.Id}", todo);
});
```

POST 핸들러에서 `Todo todo` 매개변수는 요청 Body의 JSON을 자동으로 역직렬화한다.

### 수정 (PUT)

```csharp
app.MapPut("/todoitems/{id}", async (int id, Todo inputTodo, TodoDb db) =>
{
    var todo = await db.Todos.FindAsync(id);

    if (todo is null) return Results.NotFound();

    todo.Name = inputTodo.Name;
    todo.IsComplete = inputTodo.IsComplete;

    await db.SaveChangesAsync();
    return Results.NoContent(); // 204: 성공, 반환 데이터 없음
});
```

### 삭제 (DELETE)

```csharp
app.MapDelete("/todoitems/{id}", async (int id, TodoDb db) =>
{
    if (await db.Todos.FindAsync(id) is Todo todo)
    {
        db.Todos.Remove(todo);
        await db.SaveChangesAsync();
        return Results.NoContent();
    }

    return Results.NotFound();
});
```

---

## InMemory DB와 Swagger

### InMemory 데이터베이스

`UseInMemoryDatabase`는 실제 DB 없이 메모리에 데이터를 저장한다. 개발·학습 단계에서 DB 설정 없이 바로 API를 테스트할 수 있다. 서버를 재시작하면 데이터가 초기화되므로 개발용으로만 사용한다. 실제 서비스에서는 SQLite, PostgreSQL, SQL Server 등으로 교체한다.

<div class="grid">
{{< problem-card type="bad" tag="⚠ 개발 환경" title="InMemory DB" >}}
서버 재시작 시 데이터 초기화  
실제 DB 제약 조건 미적용  
→ 개발·학습 단계에서만 사용
{{< /problem-card >}}
{{< problem-card type="good" tag="✓ 프로덕션 환경" title="실제 DB (SQLite, PostgreSQL 등)" >}}
데이터 영속성 보장  
실제 DB 동작과 동일한 제약 조건  
→ `UseInMemoryDatabase` → `UseSqlite` 등으로 교체
{{< /problem-card >}}
</div>

### NSwag로 Swagger UI 구성

```csharp
// Swagger 서비스 등록
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddOpenApiDocument(config =>
{
    config.DocumentName = "TodoAPI";
    config.Title = "TodoAPI v1";
    config.Version = "v1";
});

// 개발 환경에서만 Swagger UI 노출
if (app.Environment.IsDevelopment())
{
    app.UseOpenApi();
    app.UseSwaggerUi(config =>
    {
        config.Path = "/swagger";
    });
}
```

NSwag는 등록된 엔드포인트를 자동으로 분석해 Swagger UI를 생성한다. `/swagger`로 접속하면 브라우저에서 각 엔드포인트를 직접 테스트할 수 있다. `IsDevelopment()` 조건으로 프로덕션에서는 노출되지 않는다.

---

## HTTP 상태 코드

Minimal API에서는 `Results` 클래스로 HTTP 응답을 명시적으로 반환한다.

| **응답 코드** | **메서드** | **의미** |
| :--- | :--- | :--- |
| 200 OK | `Results.Ok(data)` | 요청 성공, 데이터 반환 |
| 201 Created | `Results.Created(url, data)` | 리소스 생성 완료 |
| 204 No Content | `Results.NoContent()` | 성공, 반환 데이터 없음 |
| 404 Not Found | `Results.NotFound()` | 요청한 리소스 없음 |

올바른 상태 코드를 반환하는 것은 API를 사용하는 클라이언트가 응답을 올바르게 처리하기 위한 기본 약속이다. `void`처럼 그냥 200만 돌려주는 API는 클라이언트 입장에서 예외 처리를 제대로 할 수 없다.