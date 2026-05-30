---
date: '2026-05-30T16:00:42+09:00'
draft: false
title: 'C# 서버 입문하기 — ASP.NET Core'
---

> 유니티 개발자의 C# 서버 배우기

---

Unity를 다루면서 서버에 대해 관심이 생겨 공부를 시작했다. 빠르게 입문하기 위해 우선 익숙한 C#을 사용하는 **ASP.NET Core Minimal API**를 선택했고, 아래 가이드를 통해 학습했다.

{{< linkcard 
  url="https://learn.microsoft.com/ko-kr/aspnet/core/tutorials/min-web-api?view=aspnetcore-10.0" 
  title="자습서: ASP.NET Core를 사용하여 최소 API 만들기"
  description="Microsoft 공식 튜토리얼 — Todo CRUD API를 최소한의 코드로 만드는 과정"
  site="Microsoft Learn"
  image="https://learn.microsoft.com/en-us/media/logos/logo-ms-social.png"
>}}

---

## Minimal API 제작하기

### 1. 프로젝트 생성

```shell
dotnet new web -o TodoApi
dotnet add package Microsoft.EntityFrameworkCore.InMemory
dotnet add package Microsoft.AspNetCore.Diagnostics.EntityFrameworkCore
```

빈 ASP.NET Core 프로젝트를 만들고, Entity Framework Core InMemory 패키지를 설치한다. 실제 DB 없이 메모리에 데이터를 저장하는 방식으로 시작한다.

### 2. 모델과 DB 컨텍스트 생성

```csharp
// Todo.cs — 데이터 구조 정의
public class Todo
{
    public int Id { get; set; }
    public string? Name { get; set; }
    public bool IsComplete { get; set; }
}

// TodoDb.cs — DB 접근 담당
using Microsoft.EntityFrameworkCore;

public class TodoDb : DbContext
{
    public TodoDb(DbContextOptions<TodoDb> options) : base(options) { }
    public DbSet<Todo> Todos => Set<Todo>();
}
```

`Todo`는 데이터 구조, `TodoDb`는 `DbContext`를 상속해 DB 접근을 담당하는 클래스다.

### 3. CRUD 엔드포인트

`Program.cs`에 DI Container에 Context들을 추가하고 HTTP 메서드별로 엔드포인트를 등록한다.

```csharp
// TodoDb에 대한 의존성 주입
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddDbContext<TodoDb>(opt => opt.UseInMemoryDatabase("TodoList"));
builder.Services.AddDatabaseDeveloperPageExceptionFilter();
var app = builder.Build();

// 전체 조회
app.MapGet("/todoitems", async (TodoDb db) => await db.Todos.ToListAsync());

// 단건 조회
app.MapGet("/todoitems/{id}", async (int id, TodoDb db) =>
    await db.Todos.FindAsync(id) is Todo todo ? Results.Ok(todo) : Results.NotFound());

// 생성
app.MapPost("/todoitems", async (Todo todo, TodoDb db) =>
{
    db.Todos.Add(todo);
    await db.SaveChangesAsync();
    return Results.Created($"/todoitems/{todo.Id}", todo);
});

// 수정
app.MapPut("/todoitems/{id}", async (int id, Todo inputTodo, TodoDb db) =>
{
    var todo = await db.Todos.FindAsync(id);
    if (todo is null) return Results.NotFound();
    todo.Name = inputTodo.Name;
    todo.IsComplete = inputTodo.IsComplete;
    await db.SaveChangesAsync();
    return Results.NoContent();
});

// 삭제
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

### 4. 검증

가이드에서는 Swagger를 사용해서 테스트를 하지만 보다 실제처럼 확인하고 싶을 수 있다. 이 때는 아래 코드를 사용해서 편하게 볼 수 있다.

```csharp
var app = builder.Build();

// 아래 코드 추가
app.UseDefaultFiles();
app.UseStaticFiles();
```
위 메서드를 추가하고 root 폴더에 `wwwroot/index.html`을 추가한다. `useStaticFiles`는 해당 폴더를 참조하므로 `dotnet run`으로 실행 후 localhost 경로로 접근하면 해당 html 파일이 열린다.

<details><summary>테스트용 HTML 코드 보기</summary>

```html
<!-- wwwroot/index.html에 저장 -->
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8" />
  <title>Todo API</title>
  <style>
    body { font-family: sans-serif; max-width: 600px; margin: 40px auto; padding: 0 16px; }
    input { padding: 6px; margin-right: 4px; }
    button { padding: 6px 12px; cursor: pointer; }
    ul { list-style: none; padding: 0; }
    li { display: flex; align-items: center; gap: 8px; padding: 6px 0; border-bottom: 1px solid #eee; }
    li.done span { text-decoration: line-through; color: #999; }
    li span { flex: 1; }
  </style>
</head>
<body>
  <h2>Todo List</h2>

  <div>
    <input id="newTodo" type="text" placeholder="할 일 입력" />
    <button onclick="addTodo()">추가</button>
  </div>

  <ul id="list"></ul>

  <script>
    const API = "/todoitems";

    async function loadTodos() {
      const res = await fetch(API);
      const todos = await res.json();
      const list = document.getElementById("list");
      list.innerHTML = "";
      for (const t of todos) {
        const li = document.createElement("li");
        if (t.isComplete) li.classList.add("done");
        li.innerHTML = `
          <input type="checkbox" ${t.isComplete ? "checked" : ""}
                 onchange="toggleTodo(${t.id}, this.checked, '${t.name}')">
          <span>${t.name}</span>
          <button onclick="deleteTodo(${t.id})">삭제</button>
        `;
        list.appendChild(li);
      }
    }

    async function addTodo() {
      const input = document.getElementById("newTodo");
      const name = input.value.trim();
      if (!name) return;
      await fetch(API, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name, isComplete: false }),
      });
      input.value = "";
      loadTodos();
    }

    async function toggleTodo(id, isComplete, name) {
      await fetch(`${API}/${id}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name, isComplete }),
      });
      loadTodos();
    }

    async function deleteTodo(id) {
      await fetch(`${API}/${id}`, { method: "DELETE" });
      loadTodos();
    }

    document.getElementById("newTodo").addEventListener("keydown", e => {
      if (e.key === "Enter") addTodo();
    });

    loadTodos();
  </script>
</body>
</html>
```

</details>

---

## 의존성 주입

**의존성 주입(DI)** 은 객체를 직접 생성하지 않고 프레임워크가 대신 만들어서 넣어주는 패턴이다. ASP.NET Core에서는 서비스를 컨테이너에 등록해두면, 핸들러 매개변수 타입을 보고 자동으로 주입해준다.

앞서 CRUD 코드에서 `TodoDb`를 `new`로 생성한 곳은 없다. `builder.Services.AddDbContext<TodoDb>(...)` 로 등록해뒀기 때문에, 핸들러가 `TodoDb db` 매개변수를 선언하면 ASP.NET Core가 자동으로 찾아서 넣어준다.

<div class="grid">
{{< problem-card type="bad" tag="new 방식" title="직접 생성해서 쓰기" >}}
→ 쓰는 쪽이 의존 대상을 직접 관리
{{< /problem-card >}}
{{< problem-card type="good" tag="DI 방식" title="등록해두면 알아서 들어온다" >}}
→ 프레임워크가 찾아서 주입
{{< /problem-card >}}
</div>

의존 대상이 많아질수록 후자가 훨씬 깔끔해진다.