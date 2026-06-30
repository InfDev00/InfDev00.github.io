---
date: '2026-06-30T11:31:10+09:00'
draft: false
title: '서버 프로젝트 기록 (3)'
---

{{< linkcard url="/posts/server-develop01/" title="서버 프로젝트 기록 (2)" description="게임 방 생성 및 참가" site="infdev00.github.io" >}}

이전 기록에서 다룬 게임 방 생성·참가까지 구현한 서버에 최종적인 게임 로직을 추가했다.

구현하고자 했던 게임은 블랙잭 기반의 게임으로, 2명의 플레이어가 진행하며 각 플레이어는 매 턴 주사위를 굴리거나 확정을 선택할 수 있다. 최종적으로 21에 가장 가까운 플레이어가 승리한다.

---

## 패킷 교환 방식

클라이언트와 서버는 로직을 실행시키는 `UserSelectReqPacket`과 실행 결과를 전달하는 `TurnResultNotifyPacket`을 통해 통신한다.

<div class="grid">
{{< card color="blue" tag="클라이언트 → 서버" title="UserSelectReqPacket" >}}
주사위를 굴리거나, 확정시킬지 여부를 전달한다.
{{< /card >}}

{{< card color="teal" tag="서버 → 클라이언트" title="TurnResultNotifyPacket" >}}
게임 로직의 결과를 전달한다. 대상 클라이언트의 ID를 포함하며 게임 방 내부 모든 클라이언트에게 전달한다.
{{< /card >}}
</div>

초기에는 굴리기와 확정을 별도 패킷으로 구분했다. 그런데 두 행동 모두 결국 같은 `TurnResultNotifyPacket`을 반환하고 전송 타이밍도 동일했기에, `UserSelectReqPacket` 하나로 통합하고 인자로 행동을 구분하도록 변경했다.

---

## 게임 로직 구현

기존 계획은 `GameRoom` 내부에 실제 게임 로직을 포함하고자 했지만 직관성 및 편의성을 위해 `GameLogic`이라는 객체를 만들어서 게임 로직을 따로 분리했다.

```Csharp
public class GameLogic
{
    class Player
    {
        public int Number;      // 누적 합
        public bool Stopped;    // 스톱 선언 여부
    }

    ...

    public void Roll(int uid)
    {
        byte[] data;
        lock (_lock)
        {
            if (_over || uid != _turn) return;          // 턴·상태 검증(서버 권위)

            int result = _rand.Next(1, 11);
            GetPlayer(uid).Number += result;            // 결과 적용
            data = EndTurn(uid, result);                // 턴 종료 처리
        }
        _room.Broadcast(data);
    }

    ...
}
```

게임 로직에선 각 클라이언트에게 `Player` 객체를 할당한다. `User` 클래스는 네트워크 코드만 포함하고, 게임 로직과 분리하기 위한 처리다.

`Roll()`과 `Stop()` 모두 같은 구조로 진행된다. `lock`으로 동시 접근을 차단하고, 본인 턴인지 검증한 뒤 로직을 적용한다. 계산은 서버에서만 수행하고 클라이언트에는 결과만 전달하는데, 클라이언트 측 조작을 차단하기 위해서다.

--- 

## 클라이언트 처리

서버가 계산을 완료하고 결과만 전달하기에, 클라이언트는 검증 없이 그대로 반영한다.

```csharp
class GameTable 
{
    private void OnTurnResult(TurnResultNotifyPacket p)
    {
        // 굴린 결과 표시
        RollNumber.text = p.Result.ToString();

        // 굴린 플레이어의 누적 합으로 손패 갱신
        if (p.UID == SystemManager.Instance.MyID)
            MyHand.SetNumber(p.Total);
        else
            OtherHand.SetNumber(p.Total);

        if (p.IsGameOver == 1)
        {
            // 승자 ID로 승패 표시 (-1=무승부)
            if (p.WinnerID == -1)
                RollNumber.text = "DRAW";
            else
                RollNumber.text = (p.WinnerID == SystemManager.Instance.MyID) ? "WIN" : "LOSE";
            ActiveButton(false);
            return;
        }

        // 턴 갱신 → 내 턴일 때만 버튼 활성화
        SystemManager.Instance.TurnPlayerID = p.TurnPlayerID;
        ActiveButton(SystemManager.Instance.IsMyTurn());
    }
}
```

