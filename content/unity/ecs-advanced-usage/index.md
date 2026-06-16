---
date: '2026-06-12T18:36:06+09:00'
draft: false
title: 'ECS 활용 — Query, Lookup, Job'
tags: ['ecs', 'dots', 'performance']
---

> ECS의 성능을 끌어올리는 방법

## 성능을 끌어내는 세 가지 축

ECS가 기존 방식과 가장 크게 다른 점은 struct 기반 구조다. 단순한 문법 차이가 아니라, 메모리 배치·캐시 효율·병렬 처리·데이터 접근 전략 전체가 이 구조에서 비롯된다. 이 글에서는 그 구조를 활용해 성능을 끌어내는 세 가지 축인 **EntityQuery·Lookup·Job**을 차례로 살펴본다.

---

## EntityQuery

`EntityQuery`는 특정 Component 조합을 가진 Entity만 골라내는 방식이다. ECS에서 struct는 메모리 내부에 Chunk 단위로 연속 배치되어 있다. 따라서 각 struct를 일일이 확인하는 대신 조건에 맞지 않는 **Chunk 전체**를 건너뛰어 처리 대상 자체를 줄일 수 있다.

`EntityQuery`를 사용하는 방법은 두 가지가 있다. 우선 일반적인 방법으로 `SystemAPI.Query`를 사용하는 방법이다. 이 방식은 `ISystem`이나 `SystemBase`에서 실행되며 포함하는 Entity의 값을 바로 수정할 수 있어서 자주 사용된다.

```csharp
public partial struct MoveSystem : ISystem 
{
    public void OnUpdate(ref SystemState state)
    {
        float dt = SystemAPI.Time.DeltaTime;
        
        // 수정이 필요한 값은 RefRW로, 읽기만 할 값은 RefRO로 호출
        foreach(var (tf, v) in SystemAPI.Query<RefRW<LocalTransform>, RefRO<Velocity>>()
            .WithAll<PlayerTag>()
            .WithNone<LockedTag>())
        {
            tf.ValueRW.Position += v.ValueRO.Value * dt;
        }
    }
}
```

또 다른 방법은 `EntityQueryBuilder`를 사용하는 방법이다. `SystemAPI.Query`에 비해서는 자주 사용되지는 않지만, 쿼리를 객체로 직접 들고 다닐 수 있어서 `RequireForUpdate` 같은 메서드에 인자로 전달하거나 여러 곳에서 재사용할 때 유용한 방법이다.

```csharp
public partial struct MovementSystem : ISystem
{
    private EntityQuery _query;

    public void OnCreate(ref SystemState state)
    {
        _query = new EntityQueryBuilder(Allocator.Temp)
                    .WithAll<LocalTransform, Velocity>()
                    .WithNone<FrozenTag>()
                    .Build(ref state);
    
        // 해당 쿼리에 속하는 요소 없으면 update 실행 안함
        state.RequireForUpdate(_query);
    }
}
```

위 예시들처럼 `EntityQuery`는 주로 체이닝 메서드 방식으로 사용된다.

| 메서드 | 역할 |
|---|---|
| `WithAll<T>` | 나열한 타입을 **모두** 가진 Entity만 포함 |
| `WithAny<T>` | 나열한 타입 중 **하나라도** 가지면 포함 |
| `WithNone<T>` | 해당 타입을 가진 Entity를 배제 |
| `WithChangeFilter<T>` | 이번 프레임에 값이 변경된 Chunk만 포함 |
| `WithEntityAccess()` | 순회 시 Entity 자체도 함께 반환 (`SystemAPI.Query` 전용) |

이 외에도 `WithDisabled<T>`, `WithOptions(...)` 등 다양한 체이닝 메서드가 있다.

쿼리를 직접 작성하는 방법 외에 간접적으로 사용되는 경우도 있다. `IJobEntity`에서는 `[WithNone(typeof(FrozenTag))]`처럼 Attribute로 조건을 지정할 수 있고, `Execute` 메서드의 인자를 기반으로 쿼리가 자동 생성되어 필터링이 이루어진다.


---

## Lookup

struct 기반 구조에서는 객체 참조 대신 Entity ID로 데이터를 식별한다. System에서 처리 중인 Entity가 아닌, **다른 Entity의 데이터를 참조**해야 할 때 이 구조 위에서 안전하게 접근하는 방법이 Lookup이다.

### ComponentLookup

```csharp
public partial struct DamageSystem : ISystem
{
    // Lookup 필드 — OnCreate에서 초기화
    private ComponentLookup<HealthComponent> _healthLookup;

    public void OnCreate(ref SystemState state)
    {
        _healthLookup = state.GetComponentLookup<HealthComponent>(isReadOnly: false);
    }

    public void OnUpdate(ref SystemState state)
    {
        _healthLookup.Update(ref state);

        // 쿼리가 순회하는 대상은 탄환 Entity
        foreach (var hit in SystemAPI.Query<RefRO<HitTarget>>().WithAll<BulletTag>())
        {
            // 체력을 깎을 대상은 탄환이 가리키는 '다른' Entity
            var targetEntity = hit.ValueRO.TargetEntity;
            if (_healthLookup.HasComponent(targetEntity))
            {
                var health = _healthLookup[targetEntity];
                health.Value -= hit.ValueRO.Damage;
                _healthLookup[targetEntity] = health;
            }
        }
    }
}
```

위 코드는 탄환이 맞힌 대상의 체력을 깎는 System이다. 쿼리가 순회하는 것은 탄환 Entity이고, 체력을 깎아야 할 대상은 탄환의 `HitTarget`이 가리키는 **다른 Entity**다. 쿼리는 현재 순회 중인 Entity의 Component만 가져올 수 있어서, 순회 도중에야 알게 되는 대상 Entity의 데이터에는 접근할 수 없다. 이때 Lookup이 Entity ID를 키로 사용하는 사전처럼 동작해서 임의 접근을 가능하게 한다.


이 외에도 `DynamicBuffer`에 접근할 때는 `BufferLookup`을 사용한다.

---

## Job

struct 기반 데이터 레이아웃은 캐시 친화적 메모리 배치를 보장하기 때문에, Job을 통한 병렬 처리 시 성능 이점이 극대화된다. 병렬 처리 자체는 `IJobEntity`의 `ScheduleParallel()`만으로 가능하고, 여기에 Lookup을 결합하면 병렬 Job 안에서도 다른 Entity의 데이터에 접근할 수 있다.

### IJobEntity에서 Lookup 사용

```csharp
public partial struct MissileChaseJob : IJobEntity
{
    [ReadOnly]
    public ComponentLookup<LocalTransform> TransformLookup;
    public EntityCommandBuffer.ParallelWriter ECB;

    void Execute(Entity entity, [ChunkIndexInQuery] int chunkIndex, in MissileData missile)
    {
        if (!TransformLookup.HasComponent(missile.Target)) return;

        // Lookup으로 추적 대상의 현재 위치를 읽음
        var targetPosition = TransformLookup[missile.Target].Position;

        // 직접 Component 수정 대신 ECB에 명령 기록
        ECB.SetComponent(chunkIndex, entity, new MoveTarget { Position = targetPosition });
    }
}
```

Job 스케줄링 시 Lookup과 ECB를 전달한다.

```csharp
public partial struct MissileSystem : ISystem
{
    private ComponentLookup<LocalTransform> _transformLookup;

    public void OnCreate(ref SystemState state)
    {
        _transformLookup = state.GetComponentLookup<LocalTransform>(isReadOnly: true);
        state.RequireForUpdate<BeginSimulationEntityCommandBufferSystem.Singleton>();
    }

    [BurstCompile]
    public void OnUpdate(ref SystemState state)
    {
        _transformLookup.Update(ref state);

        var ecb = SystemAPI
            .GetSingleton<BeginSimulationEntityCommandBufferSystem.Singleton>()
            .CreateCommandBuffer(state.WorldUnmanaged)
            .AsParallelWriter(); // 병렬 Job에서는 ParallelWriter 필수

        new MissileChaseJob
        {
            TransformLookup = _transformLookup,
            ECB = ecb
        }.ScheduleParallel();
    }
}
```

Job에서 병렬 처리를 할 때는 ECB를 사용한다. ECB는 명령을 스레드 안전하게 기록해 두었다가 **정해진 시점에 일괄 반영**하며, 반영 순서는 기록 시 전달한 sortKey(`chunkIndex`)를 기준으로 결정되어 실행 결과가 일정하게 유지된다.

Job 안에서 `Entity`를 직접 추가·삭제하거나 Component를 추가·제거하는 작업은 모두 ECB를 통해서만 가능하다. `SetComponent`처럼 값만 바꾸는 경우도, 병렬 Job에서는 동일 Entity에 대한 경합이 발생할 수 있으므로 ECB를 통하는 편이 안전하다.

{{< linkcard url="https://docs.unity3d.com/Packages/com.unity.entities@1.0/manual/systems-looking-up-data.html" title="Look up arbitrary data — Unity Entities 1.0" description="ComponentLookup, BufferLookup의 공식 사용법과 주의사항" site="docs.unity3d.com" >}}
