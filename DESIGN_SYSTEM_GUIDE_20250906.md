# OSO Camping BBQ - Material 3 디자인 시스템 가이드 (v2.0)

## 1. 디자인 철학

이 디자인 시스템은 Google의 Material Design 3(M3) 원칙을 기반으로 합니다. 목표는 사용자에게 명확하고, 신뢰감 있으며, 감성적으로 만족스러운 경험을 제공하는 것입니다. 적응성(Adaptive), 표현력(Expressive), 그리고 직관성(Intuitive)을 핵심 가치로 삼아 일관되고 아름다운 UI를 구축합니다.

---

## 2. 색상 시스템 (Color System)

M3의 역할 기반(Role-based) 색상 시스템을 채택합니다. 모든 색상은 특정 역할을 가지며, 이를 통해 다크 모드 확장 및 테마 변경이 용이해집니다. 기본 테마는 자연과 신뢰를 상징하는 딥 그린(#2E7D32)을 중심으로 구성됩니다.

### 2.1. 주요 색상 (Key Colors)

| 역할 | CSS 변수명 | Hex 코드 | 설명 |
| :--- | :--- | :--- | :--- |
| **Primary** | `--md-sys-color-primary` | `#2E7D32` | 핵심 버튼, 활성화된 입력 필드 등 가장 중요한 UI 요소에 사용됩니다. |
| **Surface** | `--md-sys-color-surface` | `#F8F9FA` | 컴포넌트(카드, 폼 컨테이너)의 배경색입니다. |
| **Background** | `--md-sys-color-background`| `#FEFEFE` | 페이지의 기본 배경색입니다. |
| **Error** | `--md-sys-color-error` | `#B00020` | 오류 상태, 유효성 검사 실패 등을 나타냅니다. |

### 2.2. 역할별 색상 팔레트

| 역할 | CSS 변수명 | Hex 코드 | 사용처 |
| :--- | :--- | :--- | :--- |
| **On Primary** | `--md-sys-color-on-primary` | `#FFFFFF` | Primary 색상 위에 위치하는 텍스트 및 아이콘 색상입니다. |
| **Primary Container**| `--md-sys-color-primary-container`| `#C8E6C9` | Primary보다 덜 강조되지만 관련된 요소(예: 활성 필터)에 사용됩니다. |
| **On Primary Container**|`--md-sys-color-on-primary-container`| `#0B3B0C` | Primary Container 위에 위치하는 텍스트 및 아이콘 색상입니다. |
| **On Surface** | `--md-sys-color-on-surface` | `#1A1C19` | Surface 색상 위에 위치하는 텍스트 및 아이콘의 기본 색상입니다. |
| **On Surface Variant**|`--md-sys-color-on-surface-variant`| `#434842` | 보조적인 텍스트(라벨, 설명)에 사용됩니다. |
| **Outline** | `--md-sys-color-outline` | `#737971` | 입력 필드 테두리 등 외곽선에 사용됩니다. |
| **Error Container** | `--md-sys-color-error-container` | `#FCD8DF` | 오류 관련 요소의 배경색입니다. |
| **On Error Container**| `--md-sys-color-on-error-container`| `#410002` | Error Container 위에 위치하는 텍스트 색상입니다. |

---

## 3. 타이포그래피 스케일 (Typography Scale)

M3의 타입 스케일을 적용하여 명확한 시각적 계층 구조를 설정합니다. 모든 텍스트는 특정 역할을 부여받습니다.

- **기본 글꼴:** 'Noto Sans KR'

| 역할 | 크기 | 줄 간격 | 굵기 | CSS 선택자 예시 |
| :--- | :--- | :--- | :--- | :--- |
| **Display Large** | 57px | 64px | 400 | `.hero-title` |
| **Headline Large** | 32px | 40px | 400 | `h1`, `.section-title` |
| **Title Large** | 22px | 28px | 500 | `h2` |
| **Title Medium** | 16px | 24px | 600 | `h3`, `.card-title` |
| **Body Large** | 16px | 24px | 400 | `body`, `p` |
| **Body Medium** | 14px | 20px | 400 | `.card-body` |
| **Label Large** | 14px | 20px | 600 | `label`, `.button-text` |
| **Label Medium** | 12px | 16px | 500 | `.input-helper-text` |

---

## 4. 형태 및 간격 (Shape & Spacing)

### 4.1. 형태 (Shape)

컴포넌트의 모서리 반경을 체계적으로 관리하여 일관된 시각적 언어를 만듭니다.

| 크기 | `border-radius` | 사용처 |
| :--- | :--- | :--- |
| **Extra Small** | `4px` | 칩(Chip) 등 작은 요소 |
| **Small** | `8px` | 버튼, 입력 필드 |
| **Medium** | `12px`| 카드, 모달 창 |
| **Large** | `16px`| 대형 시트(Sheet) |

### 4.2. 간격 (Spacing)

- **기본 단위(Base Unit):** `8px`. 모든 간격은 8의 배수를 사용하는 것을 원칙으로 합니다.
- **주요 간격:**
    - **폼 그룹 간 간격:** `24px`
    - **컨테이너 내부 여백:** `32px`
    - **컴포넌트 간 수평 간격:** `16px`

---

## 5. 컴포넌트 스타일 (Components)

### 5.1. 버튼 (Buttons) - Filled

가장 중요한 CTA(Call to Action)에 사용되는 버튼입니다.

- **`height`:** `40px`
- **`border-radius`:** `8px` (Small)
- **`padding`:** `0 24px`
- **상태별 스타일:**
    - **Enabled:** 배경색은 `Primary`, 글자색은 `On Primary` 입니다.
    - **Hover:** 배경 위에 `8%`의 흰색 레이어가 오버레이됩니다.
    - **Pressed:** 배경 위에 `12%`의 흰색 레이어가 오버레이됩니다.
    - **Disabled:** 배경은 `On Surface` 색상의 `12%` 불투명도, 글자색은 `On Surface` 색상의 `38%` 불투명도입니다.

### 5.2. 텍스트 필드 (Text Fields) - Outlined

사용자 입력을 받는 기본 필드입니다.

- **`border-radius`:** `8px` (Small)
- **상태별 스타일:**
    - **Enabled:** 테두리는 `1px solid var(--md-sys-color-outline)` 입니다. 라벨 색상은 `On Surface Variant` 입니다.
    - **Hover:** 테두리는 `1px solid var(--md-sys-color-on-surface)` 입니다.
    - **Focused:** 테두리는 `2px solid var(--md-sys-color-primary)` 입니다. 라벨 색상도 `Primary`로 변경됩니다.
    - **Error:** 테두리와 라벨 색상 모두 `Error`로 변경됩니다.