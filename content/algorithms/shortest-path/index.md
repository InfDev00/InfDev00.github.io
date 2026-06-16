---
date: '2026-06-04T22:01:15+09:00'
draft: false
title: '최단 경로 알고리즘: 다익스트라와 벨만-포드'
tags: ['graph', 'dijkstra', 'bellman-ford']
---

> 가중 그래프에서 가장 적은 비용으로 도달하는 길을 찾기.

---

## 가중 그래프와 최단 경로 알고리즘

가중 그래프는 각 그래프의 간선마다 가중치가 있는 그래프이다. 이 그래프에서 한 정점에서 다른 정점으로 가는 경로 중 가중치의 합이 최소가 되는 경로를 찾는 알고리즘은 **최단 경로 알고리즘**이라고 한다.

MST가 "모든 정점을 최소 비용으로 연결하는 트리"를 구했다면, 최단 경로 알고리즘은 "특정 출발점에서 각 정점까지의 최소 거리"를 구한다. 둘 다 가중 그래프를 다루지만 목적이 다르다.

---

## 다익스트라(Dijkstra) 알고리즘

다익스트라는 **음수가 아닌 가중치**를 가진 그래프에서 한 정점으로부터 다른 모든 정점까지의 최단 경로를 구하는 알고리즘이다. **그리디** 방식을 기반으로 하며, 매 단계에서 아직 확정되지 않은 정점 중 거리가 가장 짧은 정점을 선택해 확정한다.

### 동작 방식
1. 출발 정점의 거리를 `0`, 나머지 정점의 거리를 `무한대(∞)`로 초기화한다.
2. 아직 방문하지 않은 정점 중 **거리가 가장 짧은 정점**을 선택해 확정한다.
3. 선택한 정점과 인접한 정점들의 거리를 최소 거리로 갱신한다.
4. 모든 정점이 확정될 때까지 2~3을 반복한다.

핵심은 매번 "가장 가까운 정점"을 빠르게 꺼내는 것이다. 이를 위해 **우선순위 큐(최소 힙)** 를 사용한다. 프림 알고리즘에서 최소 가중치 간선을 힙으로 꺼냈던 구조와 동일하다.

### 구현 예시 (Python)

```python
import heapq

def dijkstra(vertex_count, start, graph_adjacent_list):
    # 모든 정점까지의 거리를 무한대로 초기화
    distance = [10e9] * (vertex_count + 1)
    distance[start] = 0

    # (거리, 정점) 형태로 우선순위 큐에 삽입
    priority_queue = [(0, start)]

    while priority_queue:
        current_distance, current_vertex = heapq.heappop(priority_queue)

        # 이미 더 짧은 경로로 확정된 정점이면 건너뛴다
        if current_distance > distance[current_vertex]:
            continue

        # 인접 정점들의 거리를 갱신
        for next_vertex, weight in graph_adjacent_list[current_vertex]:
            new_distance = current_distance + weight
            
            if new_distance < distance[next_vertex]:
                distance[next_vertex] = new_distance
                heapq.heappush(priority_queue, (new_distance, next_vertex))

    return distance
```

`current_distance > distance[current_vertex]` 검사가 중요하다. 같은 정점이 여러 번 큐에 들어갈 수 있는데, 이미 더 짧은 거리로 처리된 경우에는 건너뛰어 불필요한 연산을 막는다.

### 시간 복잡도

우선순위 큐를 사용한 다익스트라의 시간 복잡도는 **O(E log V)** 다. (V는 정점 수, E는 간선 수) 모든 간선을 한 번씩 확인하며, 각 갱신마다 힙 연산이 `log V` 시간이 걸린다.

### 한계점 - 음수 간선

다익스트라는 "한 번 확정된 정점의 최단 거리는 다시 바뀌지 않는다"는 그리디 가정 위에서 동작한다. 그런데 **음수 간선**이 있으면 이 가정이 깨진다. 이미 확정한 정점이 나중에 더 짧은 경로로 도달 가능해질 수 있기 때문이다.

이런 문제점을 해결하기 위해 벨만-포드 알고리즘을 사용한다.

---

## 벨만-포드(Bellman-Ford) 알고리즘

벨만-포드는 **음수 가중치 간선이 있어도** 최단 경로를 구할 수 있는 알고리즘이다. 다익스트라처럼 가장 가까운 정점을 골라 확정하는 대신, **모든 간선을 V-1번 반복해서 완화(relaxation)** 한다.

### 동작 방식
1. 출발 정점의 거리를 `0`, 나머지를 `무한대(∞)`로 초기화한다.
2. **모든 간선**에 대해 완화를 시도한다. (`distance[u] + weight < distance[v]`이면 `distance[v]` 갱신)
3. 위 과정을 `V-1`번 반복한다.

정점이 V개일 때 최단 경로는 최대 `V-1`개의 간선으로 구성된다. 따라서 모든 간선을 `V-1`번 완화하면 모든 최단 거리가 확정된다.

한 번 더 모든 간선을 검사했을 때 여전히 갱신이 일어나면 **음수 사이클**이 존재한다는 의미다.

### 구현 예시 (Python)

```python
def bellman_ford(vertex_count, start, edges):
    # edges: (출발 정점, 도착 정점, 가중치) 튜플의 리스트
    distance = [10e9] * (vertex_count + 1)
    distance[start] = 0

    # V-1번 모든 간선을 완화
    for _ in range(vertex_count - 1):
        for u, v, weight in edges:
            if distance[u] != 10e9 and distance[u] + weight < distance[v]:
                distance[v] = distance[u] + weight

    # 음수 사이클 검사: 한 번 더 갱신되면 음수 사이클 존재
    for u, v, weight in edges:
        if distance[u] != 10e9 and distance[u] + weight < distance[v]:
            return None  # 음수 사이클 존재

    return distance
```

`distance[u] != 10e9` 조건은 아직 도달하지 못한 정점을 기준으로 완화하는 것을 막기 위함이다.

### 시간 복잡도

모든 간선을 `V-1`번 반복하므로 시간 복잡도는 **O(V × E)** 이다. 다익스트라보다 느리지만, 음수 간선을 다룰 수 있고 음수 사이클까지 탐지할 수 있다.
