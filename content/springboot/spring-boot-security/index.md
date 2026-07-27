---
date: '2026-07-27T13:47:29+09:00'
draft: false
title: '스프링 시큐리티, 회원가입과 로그인'
tags: ['spring-boot', 'spring-security', 'bcrypt', 'csrf']
---

[이전 포스트](../spring-boot-service-dto-form/)에서 서비스 계층과 폼 클래스를 다뤘다. 이번 편에서는 스프링 시큐리티로 회원가입과 로그인을 구현한 내용을 정리한다.

---

## 스프링 시큐리티 설정

**스프링 시큐리티**는 인증과 권한을 담당하는 프레임워크다. 인증은 사용자가 누구인지 확인하는 과정이고, 권한은 인증된 사용자가 무엇에 접근할 수 있는지를 결정하는 과정이다.

설치 후에는 기본적으로 인증되지 않은 사용자의 모든 접근을 막는다. 모든 페이지에 접근을 막으면 안 되므로 이러한 부분을 수정하기 위해 `SecurityConfig`의 설정 파일을 사용한다.

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests((authorizeHttpRequests) -> authorizeHttpRequests
                .requestMatchers(new AntPathRequestMatcher("/**")).permitAll());

        return http.build();
    }
}
```

`@Configuration`은 이 파일이 환경 설정 파일임을 알리며 `@EnableWebSecurity`는 애플리케이션의 모든 요청이 스프링 시큐리티의 제어를 받도록 만든다.

스프링 시큐리티는 `SecurityFilterChain`을 스프링의 객체인 **빈**으로 등록하는 방식으로 설정한다. `HttpSecurity` 객체에 체인으로 기능을 조정할 수 있으며 `authorizeHttpRequests`은 요청 별 접근 권한을 조정한다.

이후로도 새로운 체인을 통해 기능을 추가할 수 있다.

---

## 회원가입과 비밀번호 암호화

회원 정보를 저장할 `SiteUser` 엔티티를 만들고, 서비스에서 비밀번호를 암호화해서 저장한다.

```java
// SiteUser.java
@Getter
@Setter
@Entity
public class SiteUser {
    ...
    @Column(unique = true)
    private String username;
    
    private String password;

    @Column(unique = true)
    private String email;
    ...
}

// UserService.java
@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;

    public SiteUser create(String username, String email, String password) {
        SiteUser user = new SiteUser();
        user.setUsername(username);
        user.setEmail(email);
        BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();
        user.setPassword(passwordEncoder.encode(password));
        this.userRepository.save(user);
        return user;
    }
}
```

`SiteUser`에선 `username`과 `email`을 UNIQUE 처리를 해서 중복을 막는다. `UserService`에선 `BCryptPasswordEncoder`을 사용해 비밀번호를 그대로 저장하는 대신 암호화한 값을 저장한다. BCrypt는 단방향 해시 방식이라 암호화된 값에서 원래 비밀번호를 복원할 수 없고, 데이터베이스가 유출되더라도 실제 비밀번호는 노출되지 않기에 안전하다.

하지만 위처럼 직접 생성하는 방식은 반복 사용 시 불편하다. 따라서 일반적으로는 빈으로 등록해서 사용하게 된다.

```java
// SecurityConfig.java
public class SecurityConfig {
    ...
    @Bean
    PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
    ...
}

// UserService.java
public class UserService {
    ...
    private final PasswordEncoder passwordEncoder;
    ...
    public SiteUser create(String username, String email, String password) {
        SiteUser user = new SiteUser();
        user.setUsername(username);
        user.setEmail(email);
        user.setPassword(this.passwordEncoder.encode(password)); // 주입된 passwordEncoder 사용
        this.userRepository.save(user);
        return user;
    }
}
```

`@RequiredArgsConstructor`가 생성 시 자동으로 해당하는 빈을 주입해 주기 때문에 위 방식으로 사용이 가능하다.

---

## 로그인과 로그아웃

로그인을 처리하려면 우선 스프링 시큐리티에 로그인에 대한 체인을 추가해야 한다.

```java
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests((authorizeHttpRequests) -> authorizeHttpRequests
                .requestMatchers(new AntPathRequestMatcher("/**")).permitAll())
            .formLogin((formLogin) -> formLogin
                .loginPage("/user/login")
                .defaultSuccessUrl("/"))
            .logout((logout) -> logout
                .logoutRequestMatcher(new AntPathRequestMatcher("/user/logout"))
                .logoutSuccessUrl("/")
                .invalidateHttpSession(true));

        return http.build();
    }
    ...
}
```

위에서 추가된 `formLogin` 메서드는 로그인 설정을 담당하는데 login page는 `/user/login`이고 로그인 성공 시 `/`로 이동함을 의미한다.

`logout` 메서드는 로그아웃 설정을 담당하는데 `/user/logout` 경로로 요청이 오면 로그아웃을 처리하고 성공 시 `/`로 이동한다. `invalidateHttpSession(true)`는 로그아웃 시 세션을 무효화하겠다는 의미인데, 사실 스프링 시큐리티의 기본값도 `true`라 생략해도 동일하게 동작한다. 여기서는 로그아웃 시 세션이 실제로 정리된다는 것을 명시적으로 보여주기 위해 남겨뒀다.

---

로그인을 처리하려면 아이디로 사용자를 조회하는 `UserDetailsService` 구현체가 필요하다.

```java
@Service
@RequiredArgsConstructor
public class UserSecurityService implements UserDetailsService {

    private final UserRepository userRepository;

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        SiteUser user = this.userRepository.findByUsername(username)
                .orElseThrow(() -> new UsernameNotFoundException("사용자를 찾을 수 없습니다."));

        List<GrantedAuthority> authorities = new ArrayList<>();
        authorities.add(new SimpleGrantedAuthority("ROLE_USER"));
        return new User(user.getUsername(), user.getPassword(), authorities);
    }
}
```

로그인 페이지에서 아이디와 비밀번호를 입력하면, 스프링 시큐리티가 `loadUserByUsername`을 호출해서 입력한 아이디로 사용자를 조회한다. 조회한 사용자의 암호화된 비밀번호와 입력한 비밀번호를 `passwordEncoder`로 비교해서 일치하면 로그인이 완료된다. 로그아웃은 `SecurityConfig`에 설정해 둔 `/user/logout` 경로로 요청을 보내면 처리된다.

---

스프링 시큐리티는 기본적으로 **CSRF** 보호를 켜둔다. 그래서 로그인 폼처럼 `POST`로 데이터를 보내는 폼에는 CSRF 토큰이 함께 전달돼야 한다. 타임리프의 `th:action`으로 폼을 작성하면 이 토큰이 히든 필드로 자동 삽입되기 때문에 별도로 처리하지 않아도 된다.

```html
<form th:action="@{/user/login}" method="post">
    <input type="text" name="username">
    <input type="password" name="password">
    <button type="submit">로그인</button>
</form>
```
