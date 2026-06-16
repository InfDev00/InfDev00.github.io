---
date: '2026-05-24T23:57:37+09:00'
draft: false
title: 'ECS 개념 알아보기'
tags: ['ecs', 'dots', 'architecture']
---

> 데이터 중심으로 게임을 다시 분석하기

## 왜 ECS인가?

ECS는 DOTS(Data-Oriented Technology Stack) 구현 방식이며 기존 GameObject기반의 오브젝트 구조 대신 **데이터** 중심으로 이뤄진 구조이다.

기존의 GameObject는 참조 타입인 `class`이기에 데이터가 메모리에 흩어지고, **Update**를 개별 호출하기 때문에 CPU 캐시를 효율적으로 사용하기 어렵다.

ECS는 이 구조를 뒤집어서 **Entity**는 ID 역할만 하고 모든 데이터는 **Component**에 보관된다. **Component**는 값 타입인 `struct`이기에 메모리에 정렬되어 저장되고, ECS는 이를 **System**을 통해 한 번에 관리할 수 있어서 효율적이다.

<div class="grid">
{{< problem-card type="bad" tag="⚠ 기존 방식 (MonoBehaviour)" title="객체 지향 — 편하지만 느리다" >}}
1. 각 **GameObject**는 레퍼런스만 가져 데이터가 흩어져서 배치
2. 각 **GameObject**에서 Update를 하기에 캐싱에 어려움
3. GC로 인한 프레임 드랍
{{< /problem-card >}}

{{< problem-card type="good" tag="✓ ECS 방식" title="데이터 지향 — 어렵지만 빠르다" >}}
1. 같은 종류의 데이터를 메모리에 연속 배치
2. CPU 순차적 탐색을 통한 효율성
3. Burst 및 Job을 통한 멀티 프로세싱
{{< /problem-card >}}
</div>

이 외에도 같은 Component 조합을 사용하는 `Entity`끼리 묶는 Archetype을 사용하고 고정된 크기의 Chunk를 통하여 더욱 최적화한다.

---

## ECS 사용 방법

먼저 Component는 `IComponentData` 인터페이스를 통해서 구현한다. 이 내부에는 `class`나 `List`같은 참조 타입은 사용할 수 없으며 순수한 데이터만 담을 수 있다.

배열을 사용하고자 한다면 `IBufferElementData`를 활용해서 `DynamicBuffer`를 통해 사용할 수 있다.

```csharp
// 일반적인 데이터 구조 사용
public struct PositionComponent : IComponentData
{
    public Vector3 Value;
}

// 데이터 없이 분류 목적으로만으로도 사용
public struct TagComponent : IComponentData { }

// 배열 구현 시에는 IBufferElementData 사용
public struct ArrayComponent : IBufferElementData
{
    public int Value;
}
```

---

Entity를 관리하는 System은 `ISystem` 인터페이스나 `SystemBase` 클래스를 기반으로 진행한다. Unity 생명주기에서는 `OnCreate`, `OnUpdate`, `OnDestroy`를 자동으로 호출하게 된다.

`ISystem`과 `SystemBase`는 `Unmanaged`와 `Managed`의 차이가 있는데, 성능 면에서는 `ISystem`이 더 유리하지만 `SystemBase`는 기존 `GameObject`와 연계하여 사용하기 쉬워서 편리하다. 일반적으로 순수 ECS 구조에서는 `ISystem`을, 기존 씬과 혼용할 경우 `SystemBase`를 선택한다.

```csharp
public partial struct MoveSystem : ISystem
{
    public void OnUpdate(ref SystemState state)
    {
        float deltaTime = SystemAPI.Time.DeltaTime;

        // Query를 통해 해당 컴포넌트를 가진 Entity를 순회
        foreach(var (pos, speed) in 
            SystemAPI.Query<RefRW<PositionComponent>, RefRO<SpeedComponent>>())
        {
            // RefRW는 읽기/쓰기, RefRO는 읽기 전용
            pos.ValueRW.Value.y += speed.ValueRO.Value * deltaTime;
        }
    }
}
```

`RefRW`는 읽기/쓰기, `RefRO`는 읽기 전용을 명시한다. Job System이 의존성을 분석할 때 불필요한 write dependency를 줄여 병렬 처리 효율이 높아진다.

---

마지막으로 Entity는 `EntityManager`를 통해서 생성해서 사용한다.

```csharp
public partial struct SpawnSystem : ISystem
{
    public void OnCreate(ref SystemState state)
    {
        var em = state.EntityManager;

        // 1. Archetype 정의 - 선택 사항
        var archetype = em.CreateArchetype(
            typeof(PositionComponent),
            typeof(SpeedComponent),
            typeof(AliveTag)
        );

        // 2. Entity 생성 및 컴포넌트 설정
        var entity = em.CreateEntity(archetype);
        em.SetComponentData(entity, new PositionComponent { Value = float3.zero });
        em.SetComponentData(entity, new SpeedComponent { Value = 5.0f });
    }
}
```

---

이 외에도 `[BurstCompile]`로 네이티브 코드 최적화, `IJobEntity`를 통한 멀티스레드 병렬 처리로 성능을 더 끌어올릴 수 있다.