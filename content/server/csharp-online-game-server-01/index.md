---
date: '2026-06-19T17:42:02+09:00'
draft: false
title: 'C#으로 온라인 게임 서버 만들기 (01) — 서버 제작의 기초'
---

게임 서버 개발 입문을 위해 참고한 **유니티 개발자를 위한 C#으로 온라인 게임 서버 만들기**의 학습 및 내용 정리이다. 

책의 전반부 두 파트 — **서버 네트워크 모듈**과 **TCP 메시지 처리** — 를 중심으로 정리한다.

{{< linkcard url="https://product.kyobobook.co.kr/detail/S000001057893" title="유니티 개발자를 위한 C#으로 온라인 게임 서버 만들기" description="SocketAsyncEventArgs 기반 네트워크 모듈부터 에코 서버 조립까지, 실전 C# 게임 서버 입문서." site="kyobobook.co.kr" >}}

---

## 서버 네트워크 모듈

서버가 시작되면 소켓을 **bind**하고, **listen**으로 연결 대기 상태를 만든다. 이후 클라이언트가 연결을 요청하면 **accept**로 새 소켓을 생성해 채널을 연다. 이 흐름은 하나의 서버가 여러 클라이언트를 받아들이는 동안 반복된다.

{{< flowchart >}} bind | listen | accept {{< /flowchart >}}

**.NET 비동기 소켓: 호출 → 완료 통지**

.NET 소켓에서는 `AcceptAsync`·`ReceiveAsync`인 이벤트 기반 API를 통해 작업을 진행한다. 내부적으로는 플랫폼별 비동기 I/O 메커니즘으로 소켓 작업을 위임하며 Windows에서는 IOCP, Linux에서는 epoll, macOS에서는 kqueue를 사용한다. 

비동기 I/O 등록 이후 커널이 작업을 마치면 .NET 스레드 풀의 I/O 완료 스레드가 통지를 받아 `SocketAsyncEventArgs.Completed` 이벤트를 발화한다.

```text
AcceptAsync(saea) 호출
  └─ 플랫폼 비동기 I/O 등록 (IOCP / epoll / kqueue)
       └─ 커널이 연결 수락 → 완료 통지 → I/O 완료 스레드 → SocketAsyncEventArgs.Completed 발화
```

이때 반환값이 `false`면 이미 동기 완료이며 플랫폼 I/O 경로를 거치지 않으므로 `Completed` 이벤트가 오지 않는다. 처리 메서드를 직접 호출해 흐름을 이어야 한다.

**CNetworkService / CListener / CUserToken 구조**

해당 서적에서는 서버 모듈 구조를 크게 아래 세 가지 파트로 구성한다.

<div class="grid" style="grid-template-columns: repeat(3, 1fr);">
{{< tool-card title="CNetworkService" description="전체 네트워크 허브. 클라이언트 접근 관리" >}}
{{< tool-card title="CListener" description="해당 소켓에 bind -> listen -> accept 할당" >}}
{{< tool-card title="CUserToken" description="접속한 클라이언트에 대응" >}}
</div>


**CNetworkService** — 전체 네트워크 레이어의 허브이며 클라이언트 접근을 기다리는 객체. 시작 시 수신·송신용 `SocketAsyncEventArgs`의 pool 및 전체 buffer를 관리하는 `BufferManager`를 구성하고, `listen()`으로 `CListener`를 시작한다. 새 연결이 생기면 이벤트를 통해 애플리케이션에 알린다.

```csharp
class CNetworkService {
    SocketAsyncEventArgsPool receive_pool;   // 재사용 가능한 SocketAsyncEventArgs 풀 (수신)
    SocketAsyncEventArgsPool send_pool;      // 재사용 가능한 SocketAsyncEventArgs 풀 (송신)
    BufferManager buffer_manager;            // 전체 버퍼를 하나로 관리, 연결당 슬롯 할당

    // 새 연결 수락 시 CUserToken을 앱 레이어로 전달
    public event Action<CUserToken> session_created_callback;

    public void initialize(int max_connections) { ... }  // 풀·버퍼 사전 할당
    public void listen(string host, int port, int backlog) { ... }  // CListener 시작
}
```

**CListener** — bind, listen 이후 별도 스레드에서 `AcceptAsync` 루프를 돌린다. `AutoResetEvent`로 한 번에 하나씩 처리하며, accept가 완료되면 소켓만 챙겨 이벤트로 넘기고 즉시 다음 accept를 건다. 소켓 처리와 콘텐츠 로직을 완전히 분리하는 구조다.

```csharp
class CListener {
    Socket listen_socket;
    AutoResetEvent flow_control_event;       // accept 완료 전까지 다음 요청 차단
    Action<Socket> callback_on_newclient;    // 소켓을 CNetworkService로 넘기는 콜백

    public void start(IPEndPoint endpoint, Action<Socket> callback) { ... }
    void accept_completed(object sender, SocketAsyncEventArgs e) 
    {
        callback_on_newclient(e.AcceptSocket); // 소켓만 꺼내 콜백으로 넘기고
        start_accept(e);                       // 즉시 다음 AcceptAsync 진행
    }
}
```

**CUserToken** — 연결 하나를 나타내는 세션 객체다. 소켓, 수신·송신용 `SocketAsyncEventArgs`를 하나로 묶는다.

```csharp
class CUserToken {
    public Socket socket;
    SocketAsyncEventArgs receive_args;   // 수신 전용 SocketAsyncEventArgs (풀에서 할당)
    SocketAsyncEventArgs send_args;      // 송신 전용 SocketAsyncEventArgs (풀에서 할당)
    CMessageResolver message_resolver;  // 스트림 경계 분리 담당
    IPeer peer;                          // 콘텐츠 레이어 인터페이스

    public void set_peer(IPeer peer) { this.peer = peer; }  // 앱 레이어와 바인딩
    public void start_receive() { ... } // ReceiveAsync 루프 시작
    public void send(CPacket msg) { ... }
}
```

---

## TCP 메시지 처리

TCP는 스트림 프로토콜이다. 보낸 두 메시지가 한 번에 도착하기도 하고, 하나가 쪼개져 여러 번에 걸쳐 도착하기도 한다. 수신 측은 어디서 한 메시지가 끝나는지 스스로 판단해야 한다.

예를 들어 "Hello World"라는 메시지를 보낼 때, "Hello World" 통째로 갈 수도, "Hel", "lo World"로 둘로 나눠질 수도 있다.

해당 문제를 해결하기 위해 모든 메시지에는 **2byte 크기의 헤더**를 추가한다. 해당 헤더는 본문의 크기를 이진 정수로 담으며, "Hello World"(11바이트)라면 `[0x0B][0x00][Hello World]` 형태로 전송된다.

수신 측은 먼저 헤더 2바이트를 채운 뒤, 헤더에서 읽은 크기만큼 본문을 쌓아 한 패킷으로 처리한다. 만일 크기를 채우지 못할 경우, 본문을 누적해서 다음 수신 시에 사용한다.

이 상태를 콜백을 넘나들며 유지하는 것이 `CMessageResolver`다.

```csharp
class CMessageResolver {
    const int HEADERSIZE = 2;
    byte[] message_buffer = new byte[1024];
    int current_position;   // 버퍼에 지금까지 채운 양
    int position_to_read;   // 이번 목표 바이트 수 (처음엔 HEADERSIZE, 이후 본문 크기)

    public void on_receive(byte[] buffer, int offset, int transferred, 
        Action<Const<byte[]>> on_message) 
    {
        remain_bytes = transferred;
        while (remain_bytes > 0) 
        {
            bool completed = read_until(buffer, ref offset, ref remain_bytes);
            if (!completed) break;                          // 목표 미달 — 다음 콜백까지 대기
            on_message(new Const<byte[]>(message_buffer)); // 완성된 패킷 전달
            clear_buffer();                                 // position 초기화, 다음 패킷 준비
        }
    }
}
```
