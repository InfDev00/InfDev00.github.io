---
date: '2026-06-06T21:46:47+09:00'
draft: false
title: 'C++로 TCP 서버 학습'
tags: ['cpp', 'tcp', 'network']
---

> TCP 서버 구조 학습하기

---

이전 과정에서는 asp.net을 활용해서 서버를 구축했다. 이번에는 프레임워크 없이 직접 만들어 보기로 했으며 더욱 깊게 학습하기 위해 C++ 언어를 선택했다.

---

## TCP 서버 실행 과정

소켓으로 서버를 만드는 과정은 정해진 순서가 있다. 운영체제 입장에서 "이 포트로 들어오는 연결을 받겠다"고 선언하고, 실제 연결을 하나씩 받아 처리하는 단계로 나뉜다.

우선 서버를 켤 때 진행되는 단계를 메서드에 따라 분류하면 아래와 같다.

{{< flowchart >}}socket( ) | bind( ) | listen( ) {{< /flowchart >}}

- **socket( )**   
통신에 쓸 소켓을 만든다
- **bind( )**  
소켓에 IP와 포트를 붙인다
- **listen( )**  
연결 요청을 받을 수 있는 상태로 바꾼다


서버가 켜진 이후에는 아래 흐름을 반복해서 실행한다.

{{< flowchart >}}accept( ) | recv( ) | send( ) | close( ) {{< /flowchart >}}

- **accept( )**  
들어온 연결 요청을 하나 수락한다
- **recv( )**  
데이터를 받는다
- **send( )**  
데이터를 보낸다
- **close( )**  
해당 연결을 끊는다

---

## 코드 구조

아래는 `tcp.hpp`의 구조이다. 헤더 파일로 클래스 구조를 미리 정의했다
```cpp
#pragma once

struct TCP
{
  TCP(int port);  // 생성자: socket → bind → listen로 서버를 켜는 준비
  void run();     // accept 루프를 돌며 연결을 계속 받는다

private:
  int port_;       // 서버가 열 포트 번호
  int server_fd_;  // 연결을 받는 리스닝 소켓의 fd

  void handle_client(int client_fd);  // run 내부에서 recv → send → close 진행
};
```

`server_fd_`의 `fd`는 **file descriptor**다. linux에선 프로세스가 소켓이나 파일 등의 대상에 접근할 때 내부 테이블을 통해서 접근한다. 이 내부 테이블의 index가 file descriptor로, 이 값을 통해 해당 소켓, 파일을 처리한다.

---

`tcp.cpp`에서 각 메서드의 실제 구조를 구현했다. 우선 생성자에서 포트를 받아 서버를 구성한다.

```cpp
TCP::TCP(int port): port_ {port}, server_fd_ {socket(AF_INET, SOCK_STREAM, 0)}
  {
  if (server_fd_ < 0) {
    throw std::runtime_error("socket() failed");
  }

  // SO_REUSEADDR 활성화
  int opt = 1;
  setsockopt(server_fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

  sockaddr_in addr {};
  addr.sin_family = AF_INET;          // IPv4 사용
  addr.sin_addr.s_addr = INADDR_ANY;  // 모든 네트워크 수신
  addr.sin_port = htons(port_);       // 포트를 네트워크 바이트 순서로 설정

  // 소켓에 IP/포트 주소를 할당
  if (bind(server_fd_, (sockaddr*)&addr, sizeof(addr)) < 0) {
    throw std::runtime_error("bind() failed");
  }

  // 연결 요청 대기
  if (listen(server_fd_, 5) < 0) {
    throw std::runtime_error("listen() failed");
  }
}
```

위 코드에서 `SO_REUSEADDR`은 의문이 생길 수 있는 부분이다. 없어도 서버는 제대로 실행된다.

하지만 그렇게 실행된 서버는 실행/종료를 자주 하다 보면 포트를 못 여는 오류가 생긴다. TCP 연결은 `FIN`/`ACK`를 주고받아 종료되는데, 먼저 끊는 쪽(Active Close)은 바로 종료되지 않고 `TIME_WAIT` 상태로 잠시 머문다. 이 상태에서도 포트를 잡고 있어서, 같은 포트로 서버를 다시 켜면 "Address already in use" 오류가 난다.

`SO_REUSEADDR` 설정을 통해 `TIME_WAIT`중인 포트도 사용할 수 있도록 하여 이 상황을 우회할 수 있다.


{{< linkcard url="https://hea-www.harvard.edu/~fine/Tech/addrinuse.html" title="Bind: Address Already in Use" description="TIME_WAIT 및 SO_REUSEADDR을 통한 해결" site="hea-www.harvard.edu" >}}

---

`run()` 메서드에서는 서버의 생명 주기를 구현했다. `accept()`로 하나씩 연결 요청을 받아 처리하는 방식이다.

```cpp
void TCP::run()
{
  std::cout << "Listen on port " << port_ << '\n';

  while (true) {
    sockaddr_in client_addr {};
    socklen_t len = sizeof(client_addr);

    int client_fd = accept(server_fd_, (sockaddr*)&client_addr, &len);
    if (client_fd >= 0) {
        handle_client(client_fd);
    }
  }
}

void TCP::handle_client(int client_fd)
{
  char buffer[1024];
  ssize_t n;

  while ((n = recv(client_fd, buffer, sizeof(buffer), 0)) > 0) {
    send(client_fd, buffer, n, 0);
  }

  close(client_fd);
}
```

`recv()`에서는 클라이언트로부터 받은 바이트의 수를 반환한다. 연결이 종료되는 경우는 0을 반환하므로 이를 통해 연결 종료 여부를 판별할 수 있다.

`send()`를 통해 클라이언트의 요청에 적절하게 회신할 수 있다. 현재는 단순한 echo 서버이기에 받은 입력을 그대로 돌려주는 방식을 취하고 있다.

---

`main.cpp`에서는 아래처럼 실행한다.

```cpp
int main()
{
  try {
    TCP server {8080};
    server.run();
  } 
  catch (std::exception const& e) {
    std::cerr << "ERROR: " << e.what() << '\n';
    return 1;
  }
}
```
---

## 직접 확인하기

서버를 띄우고 `nc`(netcat)로 접속하면 동작을 바로 볼 수 있다. 빌드된 프로젝트를 실행하고 다른 터미널에서 아래 명령어로 접속한다.

```sh
nc localhost 8080
```

여기서 아무 문자열이나 입력하면 같은 문자열이 그대로 되돌아온다. 입력한 줄이 `recv`로 서버에 도착하고, 서버가 `send`로 그대로 돌려보내고, `nc`가 받아 화면에 찍는 — 흐름 전체가 눈에 보인다.

`nc`를 끊으면 서버 쪽 `recv`가 `0`을 반환하면서 `handle_client`가 끝나고, 서버는 다시 다음 연결을 기다린다.

---

## 후기

이 서버에는 한 가지 한계가 있다. `handle_client`가 끝나야 `run`의 루프가 다음 `accept`로 돌아가기 때문에, 한 번에 클라이언트 **하나**만 처리한다. 다음 포스트에선 이 문제를 해결하는 방법을 찾아 보려고 한다.
