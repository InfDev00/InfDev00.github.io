---
date: '2026-06-15T15:20:07+09:00'
draft: true
title: '멀티 클라이언트 TCP 서버 구현'
---

> 한 번에 한 명에서 동시에 여러 명으로

---

이전 글에서 소켓 API만으로 TCP echo 서버를 만들었다. 기능에는 문제가 없지만 `handle_client`가 끝나야 `run`의 루프가 다음 `accept`로 돌아가기 때문에, 한 번에 클라이언트 **하나**만 처리한다는 문제점이 있었다.

{{< linkcard url="/server/cpp-tcp-server/" title="C++로 TCP 서버 학습" description="소켓 API로 만든 단일 클라이언트 TCP echo 서버" site="infdev00.github.io" >}}

여러 클라이언트를 동시에 처리하는 효율적인 방법 중 하나가 비동기 I/O다. 이를 구현하려면 `epoll`을 통해 직접 구현하거나 다른 library를 사용해서 구현할 수 있다.

| | 직접 구현 | Boost.Asio | Poco | **asio** |
|---|---|---|---|---|
| **의존성** | 없음 | Boost 전체 | Poco 전체 | **없음 (헤더 온리)** |
| **C++ 표준 연계** | ✗ | ✓ | ✗ | ✓ |

이 중 이번 포스트에서 사용한 방안은 `asio` 라이브러리이다. 의존성 없이 C++ 표준 방향과 가장 가까운 쪽이 `asio`였다. 이를 통해 같은 echo 서버지만 여러 클라이언트를 동시에 받아 처리하도록 바꾼다.

---

## 이벤트 루프와 비동기 동작

`asio`의 중심에는 `io_context`가 있다. 등록된 비동기 작업들을 보관하다가, 준비된 것부터 callback을 꺼내 실행하는 **이벤트 루프**다.

### 클라이언트 대응이 되지 않는 이유

이전 코드를 확인해 보면  `accept`와 `recv`는 **블로킹** 함수다. 호출 시 결과가 준비될 때까지 스레드를 멈춰 세워버린다. 특히 `recv`에서 현재 클라이언트의 입력을 기다리는 동안에 서버는 묶여있게 되고, 다른 클라이언트가 접속해도 `accept`가 실행되지 않으므로 받아줄 수 없다.

```cpp
void TCP::run()
{
  while (true) {
    int client_fd = accept(server_fd_, ...);  // 연결이 올 때까지 멈춰 기다린다
    if (client_fd >= 0) {
      handle_client(client_fd);
    }
  }
}

void TCP::handle_client(int client_fd)
{
  while ((n = recv(client_fd, ...)) > 0) { // 입력이 올 때까지 멈춰 기다린다
    send(client_fd, buffer, n, 0);
  }

}
```

이 구조에서 동시 처리를 하려면 클라이언트마다 스레드를 하나씩 띄우는 방법이 떠오른다. 하지만 연결이 늘어날수록 스레드도 같이 늘어나고, 대부분의 스레드는 `recv`에서 멈춘 채 입력만 기다린다. 정작 일은 안 하면서 자원만 차지하는 셈이다.

`asio`는 다른 길을 택한다. 블로킹해서 기다리는 대신, "데이터가 오면 이 함수를 불러달라"고 **등록**해두고 곧장 다음 일로 넘어간다. 기다리는 동안 멈추지 않으니, 스레드 하나로 여러 연결을 번갈아 처리할 수 있다.

흐름은 이렇게 바뀐다. 클라이언트를 기다리는 `accept`도, 입력을 받는 `recv`도 모두 **callback**으로 등록된다. `io_context`는 그중 실제로 데이터가 도착한 작업만 골라 callback을 실행한다. 스레드는 특정 I/O 결과를 기다리며 멈추는 일이 없고, 항상 준비된 callback을 실행하는 상태를 유지한다. 한 클라이언트의 callback을 처리하는 동안 다른 클라이언트 데이터가 도착하면, 그 callback은 이어서 실행할 대기열에 추가된다. **단일 스레드**만으로 여러 클라이언트를 처리할 수 있는 이유다.

---

## 구현 방식

- **`TCP`** — `io_context`와 `acceptor`를 들고 연결을 수락한다. 연결 하나가 잡힐 때마다 그 클라이언트를 담당할 세션을 만든다.
- **`Session`** — 클라이언트 한 명과의 read/write를 담당한다. 클라이언트 수만큼 생성되며 서로 독립적으로 작동한다.

```cpp
#pragma once

#include <asio.hpp>

// 클라이언트 한 명과의 연결을 담당하는 세션
class Session : public std::enable_shared_from_this<Session>
{
public:
  Session(asio::ip::tcp::socket socket);
  void read();                     // 비동기 읽기 등록

private:
  asio::ip::tcp::socket socket_;  // 이 클라이언트 전용 소켓
  char buffer_[1024] {};          // 읽고 되돌려보낼 데이터 버퍼
  
  void write(std::size_t length);  // 비동기 쓰기(echo) 등록
};

// 멀티 클라이언트 TCP echo 서버
struct TCP
{
  TCP(int port);
  void run();  // io_context 이벤트 루프 가동

private:
  asio::io_context io_context_;       // 모든 비동기 작업을 구동하는 이벤트 루프
  asio::ip::tcp::acceptor acceptor_;  // 연결 수락 전용 객체

  void accept();  // 비동기 연결 수락 등록
};
```

이전에는 `server_fd_`를 통해 직접 구현했으나, `acceptor_` 생성자를 통해 처리하도록 수정했다.

---

### 연결 수락

`TCP`의 생성자는 acceptor를 열고 첫 연결 수락을 등록한다.

```cpp
TCP::TCP(int port)
    : acceptor_ {io_context_,
                 asio::ip::tcp::endpoint(asio::ip::tcp::v4(), port)}
{
  accept();  // 첫 연결 수락을 등록 (실제 동작은 run() 에서 시작)
}

void TCP::accept()
{
  acceptor_.async_accept(
      // socket: 새로 연결된 클라이언트 전용 소켓
      [this](std::error_code ec, asio::ip::tcp::socket socket)
      {
        if (!ec) {
          // 클라이언트마다 Session 을 새로 만들어 독립적으로 echo 처리한다
          std::make_shared<Session>(std::move(socket))->read();
        }
        accept();  // 곧바로 다음 연결 수락을 다시 등록
      });
}
```

`async_accept`는 이전 버전의 `accept`처럼 연결을 기다리며 멈추지 않는다. callback만 등록하고 즉시 반환한다. 새 클라이언트가 붙으면 그제서야 callback이 호출되어 전용 소켓을 넘겨받는다.

이전의 `while(true)`를 통해 `accept`를 처리하는 방식은 callback 내 재등록으로 대신했다. `accept()` 내부에서 `accept()`를 다시 등록하여 첫 연결 하나만 받고 끝나지 않고 계속 새 연결을 받아들인다.

---

### 세션의 echo 루프

연결이 잡히면 `Session`이 `read`와 `write`를 번갈아 등록하며 echo를 실행한다.

```cpp
void Session::read()
{
  auto self = shared_from_this();

  socket_.async_read_some(asio::buffer(buffer_, 1024),
                      [this, self](std::error_code ec, std::size_t length)
                      {
                        if (ec) {
                          return;  // 연결 종료(EOF) 또는 에러
                        }
                        write(length);  // 읽은 만큼 그대로 되돌려보낸다
                      });
}

void Session::write(std::size_t length)
{
  auto self = shared_from_this();

  asio::async_write(socket_,
                asio::buffer(buffer_, length),
                [this, self](std::error_code ec, std::size_t length)
                {
                  if (ec) {
                    return;
                  }
                  read();  // 다 보냈으면 다시 읽기를 걸어 루프를 이어간다
                });
}
```

`async_read_some`은 이전 버전의 `recv`를 대신하지만, 데이터가 올 때까지 멈추지 않는다는 점이 다르다. 데이터가 도착하면 callback이 호출되어 `length`만큼을 받고, 그대로 `write`로 넘겨 echo한다. 전송이 끝나면 다시 `read`를 걸어 루프가 이어진다. 읽기와 쓰기가 서로의 callback 안에서 번갈아 등록되는 구조다.

코드에서 `shared_from_this`와 `self` 캡처가 왜 필요한지 의문이 생길 수 있는 부분이다. 비동기 callback은 등록한 순간이 아니라 **미래의 어느 시점**에 실행된다. 그사이 `Session` 객체가 사라지면 callback이 죽은 객체를 건드리게 된다. `shared_from_this()`는 자기 자신을 가리키는 `shared_ptr`를 만들고, callback 람다가 이 `self`를 캡처한다. 그러면 callback이 실행될 때까지 참조 카운트가 유지되어 객체가 살아남는다.

반대로 연결이 끊겨 `ec`가 set되면 callback은 다음 작업을 등록하지 않고 그냥 반환한다. 더 이상 `self`를 캡처한 callback이 없으니 참조 카운트가 0이 되고, `Session`과 소켓이 자동으로 정리된다. 이전 버전에서 직접 호출하던 `close`가 필요 없어진 부분이다.

`accept`에서 `Session`을 `make_shared`로 만든 이유도 여기에 있다. callback 체인이 도는 동안 객체가 유지되려면 `shared_ptr`로 관리돼야 한다.

이를 구현하기 위해 `Session`은 `std::enable_shared_from_this<Session>`을 상속하여 구현한다.

---

### 이벤트 루프 가동

마지막으로 `run`이 `io_context`를 돌린다.

```cpp
void TCP::run()
{
  std::cout << "Listen on port " << acceptor_.local_endpoint().port() << "\n";

  // 등록된 비동기 작업 중 준비된 것의 callback을 차례로 실행한다
  io_context_.run();
}
```

`io_context_.run()`은 등록된 작업의 callback을 실행하는 이벤트 루프를 시작한다. accept가 계속 자기 자신을 다시 등록하므로 처리할 작업이 끊이지 않고, 루프는 사실상 무한히 돈다.

이 외에 `main`은 이전과 동일하다.

---

## 직접 확인하기

동시 처리가 정말 되는지는 클라이언트를 **여러 개** 띄워보면 바로 드러난다. 서버를 실행하고, 터미널 두 개를 열어 각각 `nc`로 접속한다.

```sh
nc localhost 8080
```

이전 서버였다면 두 번째 `nc`는 접속은 되어도 응답을 받지 못한다. 첫 번째 클라이언트가 `handle_client`를 붙잡고 있어 서버가 두 번째 연결까지 도달하지 못하기 때문이다. 반면 `asio` 버전에서는 양쪽 터미널 모두에서 입력한 문자열이 곧바로 echo되어 돌아온다. 두 연결이 각자의 `Session`을 가지고 독립적으로 돌고 있다는 뜻이다.

한쪽 `nc`를 끊어도 다른 쪽은 영향을 받지 않는다. 끊긴 세션은 `ec`가 set되며 조용히 정리되고, 나머지 세션과 acceptor는 그대로 돌아간다.
