---
date: '2026-06-03T11:43:45+09:00'
draft: false
title: 'Controller 기반 ASP.NET Core API 개발'
---

> Controller를 통한 API 체계화

---

[이전 포스트](../csharp-server-intro/)에서 Minimal API로 Todo API를 만들었다. 이번에는 같은 튜토리얼의 연장선인 **Controller 기반** 방식으로 동일한 API를 다시 구현했고 두 방식의 차이를 중심으로 정리한다.

공식 튜토리얼 링크는 아래를 참조한다.

{{< linkcard
  url="https://learn.microsoft.com/ko-kr/aspnet/core/tutorials/first-web-api?view=aspnetcore-10.0"
  title="자습서: ASP.NET Core를 사용하여 컨트롤러 기반 웹 API 만들기"
  description="Microsoft 공식 튜토리얼 — Controller 방식으로 Todo CRUD 제작"
  site="Microsoft Learn"
  image="https://learn.microsoft.com/en-us/media/logos/logo-ms-social.png"
>}}

---
 
## Minimal API vs Controller 방식

```csharp
app.MapGet("/todoitems", async (TodoDb db) =>
    await db.Todos.ToListAsync());
```

Minimal API는 위 코드처럼 `Program.cs` 파일 안에 라우트를 Inline Rambda로 직접 등록했다.  
Controller 방식은 라우트 처리 로직을 별도 Controller 클래스 파일로 분리하고, 어트리뷰트로 라우트를 선언하는 구조다.

<div class="grid">
{{< problem-card type="bad" tag="Minimal API" title="Program.cs에 모두 정의" >}}
{{< /problem-card >}}
{{< problem-card type="good" tag="Controller" title="Controller로 분리된 구조" >}}
{{< /problem-card >}}
</div>

기능 자체가 달라지는 건 아니다. 다만 규모가 커질수록 Controller 방식이 유지보수에 유리하다. Minimal API처럼 `Program.cs`에 라우팅을 포함시키는 방식은 엔드포인트가 늘어날수록 한 파일이 비대해져 전체 구조를 파악하기 어려워진다.  
이에 비해 Controller는 리소스 단위로 파일을 분리할 수 있어 관리가 수월해진다.

---

## Controller 클래스 구조

```
dotnet aspnet-codegenerator controller -name TodoItemsController -async -api -m TodoItem -dc TodoContext -outDir Controllers
```
위 명령어를 통해 controller를 생성할 수 있다. 생성된 `TodoItemController`는 `Route` Attribute를 통해 라우팅을 연결한다.

```csharp
// 라우팅 연결
[Route("api/[controller]")]  // → api/TodoItems
[ApiController]
public class TodoItemsController : ControllerBase
{
    private readonly TodoContext _context;

    // 생성자로 컨텍스트 주입
    public TodoItemsController(TodoContext context)
    {
        _context = context;
    }
    
    ...
}
```

Minimal API에서는 Inline Rambda를 통해 DI를 받았다. Controller에서는 생성자 주입으로 바뀌어서 `Program.cs`에 등록된 `TodoContext`를 생성자로 넣어준다.

---

### CRUD 메서드

Controller 생성 시에 CRUD 메서드들은 자동으로 생성된다. 코드의 기본 구조는 각 HTTP 메서드를 Attribute로 선언하며, 반환 타입으로 `ActionResult<T>`를 사용한다.

```csharp
// GET api/TodoItems
[HttpGet]
public async Task<ActionResult<IEnumerable<TodoItem>>> GetTodoItems()
{
    return await _context.TodoItems.ToListAsync();
}

// GET api/TodoItems/5
[HttpGet("{id}")]
public async Task<ActionResult<TodoItem>> GetTodoItem(long id)
{
    var todoItem = await _context.TodoItems.FindAsync(id);
    if (todoItem == null) return NotFound();
    return todoItem;
}

// PUT api/TodoItems/5
[HttpPut("{id}")]
public async Task<IActionResult> PutTodoItem(long id, TodoItem todoItem)
{
    if (id != todoItem.Id) return BadRequest();

    _context.Entry(todoItem).State = EntityState.Modified;

    try
    {
        await _context.SaveChangesAsync();
    }
    catch (DbUpdateConcurrencyException) when (!TodoItemExists(id))
    {
        return NotFound();
    }

    return NoContent();
}

// POST api/TodoItems
[HttpPost]
public async Task<ActionResult<TodoItem>> PostTodoItem(TodoItem todoItem)
{
    _context.TodoItems.Add(todoItem);
    await _context.SaveChangesAsync();

    return CreatedAtAction(nameof(GetTodoItem), new { id = todoItem.Id }, todoItem);
}

// DELETE api/TodoItems/5
[HttpDelete("{id}")]
public async Task<IActionResult> DeleteTodoItem(long id)
{
    var todoItem = await _context.TodoItems.FindAsync(id);
    if (todoItem == null) return NotFound();

    _context.TodoItems.Remove(todoItem);
    await _context.SaveChangesAsync();

    return NoContent();
}
```

---

## Program.cs 변경 사항

Controller로 기능을 분리했기에 `Program.cs`의 코드는 보다 간단해졌다. Minimal API에서는 `Program.cs`에 엔드포인트를 직접 등록했지만, Controller 방식에서는 서비스만 등록하고 라우팅은 `MapControllers()`에 위임한다.

```csharp
var builder = WebApplication.CreateBuilder(args);

// Controller 서비스 등록
builder.Services.AddControllers();
builder.Services.AddOpenApi();
builder.Services.AddDbContext<TodoContext>(opt => opt.UseInMemoryDatabase("TodoList"));

var app = builder.Build();

app.UseHttpsRedirection();
app.UseAuthorization();

// 모든 Controller의 라우트를 한 번에 연결
app.MapControllers();

app.Run();
```

`AddControllers()`와 `MapControllers()`가 Minimal API의 `MapGet/Post/Put/Delete`를 대체했으며 EndPoint 정의 자체는 Controller 클래스로 이동했다.

---

## DTO 패턴

Minimal API 튜토리얼에서는 `Todo` 모델을 그대로 API 요청/응답에 사용했다. Controller 튜토리얼에서는 **DTO(Data Transfer Object)** 를 도입한다.

예시 데이터로 `TodoItem`에는 `Secret` 필드를 추가했다.

```csharp
public class TodoItem
{
    public long Id { get; set; }
    public string? Name { get; set; }
    public bool IsComplete { get; set; }
    public string? Secret { get; set; }  // 외부에 노출하면 안 되는 필드
}
```

이 필드를 그대로 응답으로 내보내면 의도치 않게 민감한 데이터가 유출된다. 따라서 외부에 노출할 field만 포함해서 `TodoItemDTO`를 제작한다.

```csharp
public class TodoItemDTO
{
    public long Id { get; set; }
    public string? Name { get; set; }
    public bool IsComplete { get; set; }
    // Secret 없음
}
```

Controller에서는 내부 엔티티 대신 DTO만 외부에 노출하도록 변환 메서드를 사용한다.

```csharp
private static TodoItemDTO ItemToDTO(TodoItem todoItem) => new TodoItemDTO
{
    Id = todoItem.Id,
    Name = todoItem.Name,
    IsComplete = todoItem.IsComplete
};
```

이 패턴을 **오버포스팅 방지**라고 부른다. 클라이언트가 모델의 모든 필드를 마음대로 수정하지 못하게 차단하는 구조다.