---
date: '2026-05-23T10:22:07+09:00'
draft: false
title: '최소 신장 트리(MST): 크루스칼과 프림 알고리즘'
tags: ['graph', 'greedy', 'kruskal', 'prim']
---

> 모든 노드를 최소 비용으로 연결하는 최적의 경로 찾기.

---

## 최소 신장 트리(Minimum Spanning Tree)란?

**최소 신장 트리**는 그래프 내의 모든 정점을 연결하는 간선들 중에서 간선 가중치의 합이 **최소**가 되는 트리를 의미한다. 최소 신장 트리를 만족하는 조건은 아래와 같다.
- 모든 정점이 연결되어 있어야 한다.
- 사이클(Cycle)이 존재하지 않아야 한다.

최소 신장 트리를 구하는 대표적인 알고리즘으로 **Kruskal(크루스칼)** 알고리즘과 **Prim(프림)** 알고리즘이 있다.

---

## 프림(Prim) 알고리즘

프림 알고리즘은 **그리디** 알고리즘을 기반으로 하며 각 정점을 기준으로 확장해 나가는 방식이다. 시작 정점에서 출발하여 인접한 정점 중 가장 가중치가 낮은 간선을 선택하며 트리를 키워나가는 방식으로 진행한다.

### 동작 방식
1. 임의의 시작 정점을 선택하여 MST 집합에 포함시킨다.
2. MST 집합에 포함된 정점들과 인접한 정점들 중, 가중치가 **최소인 간선**을 선택한다.
3. 선택된 간선에 연결된 정점이 이미 MST에 포함되어 있다면 무시하고, 그렇지 않다면 MST에 포함시킨다.
4. 모든 정점이 MST에 포함될 때까지 반복한다.

### 구현 예시 (Python)

```python
import heapq

def prim(vertex_count, graph_adjacent_list):
    priority_queue = [(0, 1, None)]
    
    is_visited = [False] * (vertex_count + 1)
    mst_edges = []  # 최소 신장 트리를 구성하는 간선들을 담을 리스트

    while priority_queue:
        edge_cost, current_vertex, previous_vertex = heapq.heappop(priority_queue)

        if is_visited[current_vertex]:
            continue

        is_visited[current_vertex] = True
        
        if previous_vertex is not None:
            mst_edges.append((previous_vertex, current_vertex, edge_cost))
            total_minimum_cost += edge_cost

        # 현재 정점과 연결된 인접 들을 탐색
        for next_vertex, next_edge_cost in graph_adjacent_list[current_vertex]:
            if not is_visited[next_vertex]:
                heapq.heappush(priority_queue, (next_edge_cost, next_vertex, current_vertex))

    return mst_edges
```

위 코드에서는 인접 리스트 및 우선순위 큐를 활용해서 시간 복잡도를 `O(E log V)`로 최소화했다.  
정점마다 인접 정점까지의 간선을 확인하므로 희소 그래프에서 더 유리하다.

---

## 크루스칼(Kruskal) 알고리즘

크루스칼 알고리즘도 **그리디(Greedy)** 방식을 기반으로 하지만 프림 알고리즘과 달리 **간선**을 기준으로 한다.
간선을 가중치 기준으로 정렬한 뒤 사이클을 형성하지 않는 선에서 가장 작은 간선부터 선택하는 방식이다.

이때 사이클을 형성하지 않는지 확인할 때 `Union-Find`를 사용한다. `Union-Find`에 대해서는 아래 글을 참조하자.

{{< linkcard 
  url="/algorithms/union-find/" 
  title="서로소 집합(Disjoint Sets)과 Union-Find 알고리즘의 이해" 
  description="서로소 집합과 이를 구현하는 Union-Find 알고리즘에 대한 학습" 
  image="/algorithms/union-find/main-Image.png" 
  site="InfDev00 DevBlog"
>}}

### 동작 방식
1. 모든 간선을 가중치 기준 **오름차순**으로 정렬한다.
2. 가중치가 가장 낮은 간선부터 차례대로 확인한다.
3. 해당 간선을 선택했을 때 **사이클**이 발생하는지 확인한다.
4. 사이클이 발생하지 않는다면 해당 간선을 MST에 포함시킨다.
5. 모든 간선에 대해 위 과정을 반복한다.

### 구현 예시 (Python)

```python
def kruskal(v, edges):
    parent = [i for i in range(v + 1)]
    edges.sort() # 가중치 기준 정렬
    mst_edges = []

    for cost, a, b in edges:
        if find(parent, a) != find(parent, b):
            union(parent, a, b)
            mst_edges.append((a, b, cost))
            
    return mst_edges
```

크루스칼 알고리즘은 `O(E log E)`의 시간 복잡도를 갖는다.

---

## 알고리즘 비교

| 비교 항목 | 프림(Prim) | 크루스칼(Kruskal) |
| :--- | :--- | :--- |
| **핵심 철학** | 정점 중심 (Vertex-based) | 간선 중심 (Edge-based)|
| **자료구조** | 우선순위 큐(Heap) | Union-Find |
| **입력** | 인접 리스트 | 간선 리스트 |

위 조건들을 비교하여 상황에 맞게 사용하는 게 좋다.