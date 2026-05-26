---
date: '2026-05-26T22:49:33+09:00'
draft: false
title: 'GameObject를 ECS로 — Baking 완전 정복'
---

> GameObject와 Entity가 공존하는 방법.


## GameObject 혼용 이유

ECS는 높은 성능을 보여주지만, **씬 관리·UI·카메라** 같은 영역에서는 여전히 GameObject를 사용할 필요가 있다. 그래서 많은 프로젝트가 이동·AI·물리 계산은 ECS에서 처리하고, 외부 영역은 GameObject가 담당하는 **ECS + GameObject 혼용** 방식을 택한다.

---

## Authoring을 사용하여 Baking

**Authoring Component**는 데이터를 보유하는 `MonoBehaviour`이다. `Baker`에서는 런타임 진입 전에 해당 Authoring을 Bake하며 **Entity**를 생성한다.

```csharp
// 데이터를 보유하는 MonoBehaviour
public class MoveAuthoring : MonoBehaviour
{
    public float Speed;

    // Baker — Authoring 데이터를 Entity로 변환
    class Baker : Baker<MoveAuthoring>
    {
        public override void Bake(MoveAuthoring authoring)
        {
            var entity = GetEntity(TransformUsageFlags.Dynamic);
            AddComponent(entity, new SpeedComponent { Value = authoring.Speed });
        }
    }
}


```

Authoring Component를 붙인 GameObject는 반드시 **SubScene** 안에 있어야 Baking이 실행된다.

### 주요 TransformUsageFlags

`GetEntity()` 호출 시 전달하는 `TransformUsageFlags`는 Entity의 Transform 처리 방식을 결정하며 **성능에 직접적인 영향**을 준다.

| 플래그 | 설명 |
| :--- | :--- |
| **None** | Transform 컴포넌트가 필요 없는 순수 데이터 Entity |
| **Dynamic** | 런타임에 이동이 필요한 오브젝트 (`LocalTransform` 추가) |
| **Renderable** | 렌더링만 필요하고 이동하지 않는 오브젝트 (`LocalToWorld` 추가) |
| **WorldSpace** | 부모 Entity가 있어도 항상 월드 공간 좌표를 유지해야 하는 오브젝트 |

움직이지 않는 오브젝트에 `Dynamic`을 쓰면 불필요한 Transform 시스템 처리를 해야 하는 등 손해가 발생하기에 용도에 맞게 선택한다.

---

## MonoBehaviour에서 Entity 제어

GameObject에서 Entity를 직접 생성하거나 Component 데이터를 수정해야 할 때가 생긴다. `World.DefaultGameObjectInjectionWorld.EntityManager`를 통해 EntityManager에 접근할 수 있다.

### Entity 생성

`EntityManager.CreateEntity()`로 Entity를 직접 생성하거나, `EntityManager.Instantiate()`로 Entity 프리팹을 복제하는 방식이 일반적이다. 

```csharp
public class SpawnerMono : MonoBehaviour
{
    void Start()
    {
        var world = World.DefaultGameObjectInjectionWorld;
        var entityManager = world.EntityManager;

        var entity = entityManager.CreateEntity();
        entityManager.AddComponentData(entity, new SpeedComponent { Value = 5f });
    }
}
```

프리팹을 복제할 때는 Authoring을 통해 Entity 프리팹을 Baking한 뒤, 컴포넌트에 저장해 참조한다.

```csharp
public class SpawnerAuthoring : MonoBehaviour
{
    public GameObject Prefab;

    class Baker : Baker<SpawnerAuthoring>
    {
        public override void Bake(SpawnerAuthoring authoring)
        {
            var entity = GetEntity(TransformUsageFlags.None);
            AddComponent(entity, new SpawnerData
            {
                // GameObject 프리팹 → Entity 프리팹으로 변환
                PrefabData = GetEntity(authoring.Prefab, TransformUsageFlags.Dynamic)
            });
        }
    }
}

// Baking된 Entity 프리팹을 보관하는 컴포넌트
public struct SpawnerData : IComponentData
{
    public Entity PrefabData;
}
```

---

### Component 데이터 수정

존재하는 Entity의 Component 값을 MonoBehaviour에서 직접 읽거나 쓸 수 있다.

```csharp
public class EnemyController : MonoBehaviour
{
    public Entity targetEntity;

    void Update()
    {
        var entityManager = World.DefaultGameObjectInjectionWorld.EntityManager;

        // Component 데이터 읽기
        var speed = entityManager.GetComponentData<SpeedComponent>(targetEntity);

        // Component 데이터 쓰기
        entityManager.SetComponentData(targetEntity, new SpeedComponent { Value = speed.Value * 2f });
    }
}
```

`SetComponentData`는 메인 스레드에서만 호출 가능하다. Job 안에서 데이터를 수정해야 한다면 `EntityCommandBuffer`를 사용한다.

