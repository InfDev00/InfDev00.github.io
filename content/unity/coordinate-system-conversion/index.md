---
date: '2026-07-02T13:15:59+09:00'
draft: false
title: '좌표계 변환하기: 직교, 원통, 구면'
tags: ['math', 'coordinate-system', 'unity']
---

게임에서 위성처럼 대상을 따라 순회하거나, 주위를 회전하도록 구현해야 하는 상황이 있다. 이때 단순히 `x,y,z` 값을 직접 계산하면 비직관적이다. 회전은 **거리**와 **각도** 두 값으로 표현되는데 매번 좌표로 환산해야 하기 때문이다.

이런 상황에선 일반적으로 사용하는 직교좌표계 대신 원통좌표계, 구면좌표계를 사용할 수  있다. 각 좌표계는 설명하는 방식이 다르지만 같은 점을 가리키는 표현 방식이다. 그래서 서로 변환할 수 있고, 상황에 맞는 좌표계를 골라 쓰면 계산이 단순하고 코드가 직관적으로 변한다.

---

## 좌표계의 종류

<div class="grid" style="grid-template-columns: repeat(3, 1fr);">
{{< card color="blue" title="직교 좌표계" >}} (x, y, z)  
일반적인 x,y,z 좌표계 {{< /card >}}
{{< card color="teal" title="원통 좌표계" >}} (ρ, θ, z)  
xy 평면 위에 반지름 ρ, 각도 θ와 직교 좌표계의 z를 높이로 사용  {{< /card >}}
{{< card color="teal" title="구면 좌표계" >}} (ρ, θ, φ)  
반지름 ρ와 두 각도 θ, φ로 표현 {{< /card >}}
</div>

우리가 일반적으로 사용하는 좌표계는 직교 좌표계이다. 이 직교 좌표계에서 Δθ만큼 회전한다고 해 보자.

```text
x = x·cos(Δθ) - y·sin(Δθ)
y = x·sin(Δθ) + y·cos(Δθ)
```

위 수식에선 삼각함수를 4번이나 사용해야 하고, 실제 코드로 구현시 누적된 부동소수점 오차로 반지름이 바뀌기 시작한다. 이를 해결하고자 사용된 방법이 **원통 좌표계**이다.

원통 좌표계에서는 좌표를 반지름 ρ와 각도 θ로 표현한다. 따라서 같은 회전이 아래처럼 간편하게 해결되며 추가로 ρ를 수정하지 않아 반지름이 변하는 문제도 해결된다.

```text
θ += Δθ
```


마찬가지로 **구면좌표계** 또한 구면 기준으로 회전을 간편하게 표현하고자 사용한다.

---

## Unity Orbit 카메라 구현

구면 좌표계를 활용해서 최적화하는 예시이다. Orbit 카메라는 대상(target)으로부터 거리 `ρ`, 극각 `θ`, 수평 회전각 `φ` 세 값만 들고 있으면 된다. 매 프레임 이 값을 위 공식으로 직교좌표로 변환해 카메라 위치에 대입한다.

```csharp
public class OrbitCamera : MonoBehaviour
{
    public Transform target;
    public float distance = 5f;
    public float theta;  // 극각 θ (0 ~ 180)
    public float phi;    // 수평 회전각 φ
    public float mouseSensitivity = 3f;

    void LateUpdate()
    {
        phi += Input.GetAxis("Mouse X") * mouseSensitivity;
        theta -= Input.GetAxis("Mouse Y") * mouseSensitivity;

        transform.position = target.position 
            + SphericalToCartesian(distance, theta * Mathf.Deg2Rad, phi * Mathf.Deg2Rad);

        transform.LookAt(target);
    }

    Vector3 SphericalToCartesian(float rho, float theta, float phi)
    {
        float x = rho * Mathf.Sin(theta) * Mathf.Cos(phi);
        float y = rho * Mathf.Sin(theta) * Mathf.Sin(phi);
        float z = rho * Mathf.Cos(theta);

        return new Vector3(x, z, y); // 수학의 z축(극축) → Unity y축(상향)
    }
}
```

이 방식은 `transform.RotateAround`처럼 카메라를 매 프레임 회전시키는 방식과 달리, 상태를 `(ρ, θ, φ)` 세 개의 독립된 숫자로만 들고 있다. 회전을 누적하지 않고 매번 절대각으로 위치를 계산하므로 오차가 쌓이지 않고, 회전 자체는 `θ += Δθ` 덧셈만으로 처리되어 Quaternion도 필요 없으며 거리·각도 값을 그대로 UI 슬라이더에 연결하거나 저장하기도 쉬워진다.