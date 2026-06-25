---
date: '2026-06-25T22:05:14+09:00'
draft: false
title: '서버 프로젝트 기록 (2)'
---

{{< linkcard url="/posts/server-develop00/" title="서버 프로젝트 기록 (1)" description="Shared 네트워크 레이어·IPeer·패킷 프로토콜, 서버/클라이언트 구조" site="infdev00.github.io" >}}

이전 기록에서 다룬 로그인까지 동작하는 서버에 게임 방 생성·참가 기능을 추가했다.

---

## 진행 방식

{{< flowchart >}} 방 입장 요청 | 입장 확인 + 인원 갱신 | 로딩 시작 | 로딩 완료 보고 | 게임 시작 {{< /flowchart >}}

우선 클라이언트가 `RoomEnterReqPacket`을 보내면 서버에서는 유저에게 방을 배정한 후 `RoomEnterAckPacket`을 전달한다.

이때 방에 있던 사람들에게 브로드캐스트로 `RoomStateNotifyPacket`을 보내 새로운 사람이 들어왔음을 알리고, 정원이 충족되었다면 `LoadingNotifyPacket`을 보내 게임 씬을 로딩하라고 알린다.

각 클라이언트에서 로딩이 완료되어 `LoadingCompleteReqPacket`을 보내고, 모든 클라이언트에서 로딩이 완료되면 `GameStartNotifyPacket`을 보내 게임을 시작한다.

---

## 게임 방 구현 방식

게임 방은 게임 로직을 구현하는 객체로 기획했다. 현재는 `User` 추가/제거 및 브로드캐스트 관련 코드만 있지만 추후 실제 게임 로직에 관한 코드를 구현할 계획이다.

브로드캐스트 과정에선 동일한 패킷을 반복해서 보내는 작업이기에 미리 `Pack()`을 진행하여 각 `User`로 `byte[]`로 된 데이터를 전달했다. 각 `User`마다 직렬화를 하는 오버헤드를 제거하기 위한 목적이다.

```csharp
// GameRoomManager.cs — 인원 갱신 통지
var state = Packet.Create<RoomStateNotifyPacket>(user);
state.Current = (short)current; // 현재 인원
state.Needed  = (short)needed; // 전체 인원
room.Broadcast(state.Pack());   // 한 번 직렬화한 byte[]를 방 전체에 재사용

// GameRoom.cs — Broadcast 구현
public void Broadcast(byte[] data)
{
    User[] snapshot = Snapshot();           // 락 안: 배열 복사만
    for (int i = 0; i < snapshot.Length; ++i)
        snapshot[i].Send(data);             // 락 밖: 소켓 I/O
}
```

위 과정에서 `Snapshot`으로 `User`의 배열을 가져왔는데 이는 혹시 클라이언트가 접속 종료되거나 새로 추가되었을 때를 대비하여 `lock`을 통해 안전하게 현재 클라이언트들을 받아오고자 하는 목적이다. `Send()`는 `lock` 외부로 분리했는데, `lock` 안에서 소켓 I/O를 수행하면 전송 완료까지 락을 점유하게 되어 다른 스레드가 해당 방에 접근하지 못하고 대기하게 되기 때문이다.

또한 클라이언트 코드를 작성하면서 각 `User`에게 `ID`를 부여하고자 했다. 게임 로직 구현 과정에서 패킷을 보낼 때 클라이언트 A 대상인지, B 대상인지 구분할 필요가 있었으며 특히 받아온 패킷이 본인 대상인지 아닌지에 따라 발생해야 하는 리액션이 달라지는 상황이 있었다.

기존 서적에서처럼 각 방마다 `ID`를 제공할까 했으나 유저 로그나 확장성 등을 고려해서 글로벌 `ID`를 할당하도록 제작했다.

---

## 로딩 지연 및 동시 실행

클라이언트에서 로딩을 구현하고자 게임 씬을 분리했고, 게임 씬이 로딩 완료되면 `LoadingCompleteReqPacket`을 보내 서버에게 알린다. 서버에선 게임 방에서 로딩 완료된 `User`를 기록하고 모든 `User`가 로딩 완료될 때까지 대기한다.

```csharp
// GameRoom.cs
public bool MarkLoaded(User user)
{
    lock (_lock)
    {
        if (!_users.ContainsKey(user.ID)) return false;
        _loaded.Add(user.ID);                              // HashSet이라 중복 무시
        return _users.Count > 0 && _loaded.Count >= _users.Count;
    }
}
```

위 메서드를 통해 `User`가 로딩 완료되었는지 기록한다. 전원 완료가 확인되면 `GameStartNotifyPacket`을 방 전체에 broadcast한다. 이 패킷에는 첫 번째 턴 플레이어 ID(`TurnPlayerID`)가 포함돼 있어 클라이언트가 시작 상태를 바로 구성할 수 있다.

---

## 클라이언트 패킷 처리

`NetworkSystem`에서 `ServerSession`의 큐에 패킷을 쌓고 읽어오는 구조는 이전 포스트에서 다뤘다. 

클라이언트 코드가 늘어나면서 단순히 `NetworkSystem` 내부에서 패킷을 처리하는 건 한계가 있었다. 따라서 `NetworkSystem`에 이벤트를 구독하는 방식으로 다른 객체에서도 패킷 처리를 진행하고자 했다. 

```csharp
// NetworkSystem.cs — Register
public void Register<T>(Action<T> handler) where T : Packet
{
    if (_wrappers.ContainsKey(handler)) return;
    Action<Packet> wrapper = p => handler((T)p);   // 타입을 알고 있는 시점에 캐스팅
    _wrappers[handler] = wrapper;
    _handlers.TryGetValue(typeof(T), out var cur);
    _handlers[typeof(T)] = cur + wrapper;
}

// Update 내부 — 수신 패킷 타입으로 핸들러 조회 후 호출
if (_handlers.TryGetValue(packet.GetType(), out var handler))
    handler(packet);
```

의도한 방식은 패킷의 타입을 `Key`로 해서 `Action<T>`을 저장하는 방식이었으나 `Dictionary<Type, Action<T>>`의 구조는 불가능했다.

그래서 어쩔 수 없이 `Dictionary<Type, Action<Packet>>`과 `Dictionary<Delegate, Action<Packet>>`의 핸들러와 원본 구조로 나누어 진행했다.

외부에서 `Action<T>`로 구독 요청이 들어오면 `Action<Packet>`의 wrapper를 만들어 핸들러에 `Type`을 키로 wrapper를 담아둔다. 이후 해당 `Action<T>`로 구독 해제가 들어오는 걸 대비하여 `Action<T>`를 키로 wrapper를 반환하는 원본 딕셔너리에 추가하는 방식이다.

처음에는 `DynamicInvoke`를 활용하여 하나의 딕셔너리로 진행하려 했으나, 리플렉션을 사용하고 싶지 않아서 해당 방법을 선택했다.
