---
date: '2026-06-22T16:31:21+09:00'
draft: false
title: 'C#으로 온라인 게임 서버 만들기 (02) — 서버와 게임 로직 연결'
---

네트워크 모듈 위에 실제 게임 로직을 올리는 방법을 정리한다. 이전 편에서 `CNetworkService`·`CUserToken`·`CMessageResolver`로 소켓 계층을 조립했다면, 이번에는 그 위에 IPeer 인터페이스로 **콘텐츠 계층**을 분리하고, **게임 방과 준비 배리어**까지 완성하는 흐름이다.

{{< linkcard url="https://product.kyobobook.co.kr/detail/S000001057893" title="유니티 개발자를 위한 C#으로 온라인 게임 서버 만들기" description="01편에서 다룬 네트워크 모듈의 원출처. 이번 편은 그 위에 올라가는 게임 서버 계층을 다룬다." site="kyobobook.co.kr" >}}

---

## 권위적 서버

게임 서버 설계의 출발점은 **누가 게임 상태를 결정하느냐**이다. 클라이언트가 스스로 "내가 이동했다", "내가 이겼다"를 결정하면 클라이언트 코드를 조작해 치팅이 가능하다. 그래서 멀티플레이 게임 서버는 대부분 **권위적 서버** 모델을 쓴다.

전체 구조는 클라이언트는 "이렇게 하고 싶다"는 요청을 보내고, 서버가 규칙에 따라 유효성을 검증한 뒤 결과를 모든 클라이언트에 브로드캐스트한다.

{{< flowchart >}} 클라이언트 요청 | 서버 검증 | 서버 결과 브로드캐스트 | 클라이언트 리액선 {{< /flowchart >}}


클라이언트의 리액션은 항상 서버가 보내준 결과를 기반으로 한다. 만일 클라이언트 쪽에서 판정을 먼저 계산하더라도, 서버 결과와 다르면 서버 기준으로 덮어씌운다.

---

## IPeer — 네트워크와 로직 분리

`IPeer`는 소켓 계층(`CUserToken`)과 콘텐츠 계층(`CGameRoom`) 사이의 경계다. `CUserToken`이 패킷만 전달하면 `IPeer`가 게임 로직인 `CGameRoom`으로 전달한다.

| | **서버** (`CGameUser`) | **클라이언트** (`CRemoteServerPeer`) |
|:---|:---|:---|
| **표현 대상** | 접속해 온 클라이언트 1명 | 연결된 서버 |
| **연결 방식** | `listen` 수동 대기 → accept 시 생성 | `CConnector`로 능동 connect → 성공 시 생성 |
| **`on_message` 처리** | 요청(REQ) 처리 후 응답 | 응답(ACK) 받아 화면 출력 |

서버의 `IPeer`는 "이 클라이언트가 보낸 걸 어떻게 처리할까", 클라이언트의 `IPeer`는 "서버가 보낸 걸 어떻게 처리할까"다. 

에코 서버를 예로 들면 — 클라이언트가 `CHAT_MSG_REQ`를 보내면 서버 `CGameUser.on_message`가 받아 같은 텍스트를 `CHAT_MSG_ACK`로 되돌리고, 클라이언트 `CRemoteServerPeer.on_message`가 그것을 받아 출력한다.

---

## 게임 서버 구조

네트워크 계층(`CNetworkService` / `CUserToken`)과 콘텐츠 계층(`CGameUser`) 위에 게임 서버가 올라간다. 구성은 크게 세 가지다:

**`CGameUser`** — 소켓을 가진 유저 객체. `IPeer`를 구현해 패킷을 받고, 유저 요청을 전달한다.

**`CGameRoom`** — 게임 방 하나를 표현한다. 게임 로직을 관리하며 유저 또한 게임 로직 객체인 `CPlayer`로 관리한다.

**`CGameServer`** — `CGameRoom`들을 생성·삭제하는 `CGameRoomManager`, 유저 목록, 메시지 큐를 묶는 상위 허브다. 메시지 큐를 활용하여 각 `CUserToken`의 경쟁 상태를 처리한다.

매칭은 가장 단순한 형태다. 유저가 `ENTER_GAME_ROOM_REQ`를 보내면 대기 리스트에 추가하고, **2명이 모이면** 방을 생성해 두 유저를 입장시킨다. 방에 입장하면 양쪽에 `START_LOADING` 패킷을 보내고 로딩을 기다린다.

```csharp
void matching_req(CGameUser user) {
    wait_queue.Add(user);
    if (wait_queue.Count < 2) return;   // 아직 부족

    // 2명이 모이면 방 생성
    var players = wait_queue.Take(2);
    wait_queue.RemoveRange(0, 2);
    room_manager.create_room(players[0], players[1]);
}
```

---

## 클라이언트 준비 배리어

클라이언트마다 하드웨어 성능과 네트워크 상태가 다르다. 로딩이 빨리 끝난 플레이어가 느린 플레이어를 기다리지 않으면 게임이 어긋난다. **배리어(barrier)** 패턴이 이 문제를 해결한다.

각 클라이언트는 단계를 마치면 ACK 패킷을 서버에 보낸다. 서버는 상태를 갱신하고 **전원이 같은 상태인지 확인(`allplayers_ready`)** 한 뒤, 모두 도달했을 때만 다음 단계로 넘어간다.

```csharp
// 로딩 완료 배리어
public void loading_complete(CPlayer player) {
    change_playerstate(player, PLAYER_STATE.LOADING_COMPLETE);
    if (!allplayers_ready(PLAYER_STATE.LOADING_COMPLETE)) return; // 아직 대기
    battle_start(); // 전원 준비됨 → 게임 시작, 보드 초기 상태 브로드캐스트
}

// 턴 종료 배리어
public void turn_finished(CPlayer player) {
    change_playerstate(player, PLAYER_STATE.TURN_FINISHED);
    if (!allplayers_ready(PLAYER_STATE.TURN_FINISHED)) return;    // 아직 대기
    turn_end(); // 전원 준비됨 → 다음 턴으로, 누구 턴인지 브로드캐스트
}

bool allplayers_ready(PLAYER_STATE state) {
    return players.All(p => p.state == state);
}
```

배리어는 게임 흐름에서 두 번 등장한다. **로딩 배리어**는 모든 클라이언트가 로딩을 마칠 때까지 대기하고, **턴 종료 배리어**는 착수 이후 모든 클라이언트의 연출이 끝날 때까지 다음 턴을 미룬다. 플레이어 상태를 열거형으로 관리하고 전원의 상태가 일치하는지 카운팅하는 것만으로 구현된다.

이 패턴은 배리어가 필요한 모든 턴 기반 게임에 그대로 적용할 수 있다.
