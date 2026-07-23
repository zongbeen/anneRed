# anneRed — Apple Design 기준 전체 정비

작성일: 2026-07-22
대상: `anneRed` iOS 앱 (UIKit, 스토리보드, Core Data, 위젯 익스텐션)
기준: `apple-design` 스킬 (WWDC *Designing Fluid Interfaces* 외)

## 목적

D-day 앱의 인터페이스를 Apple의 유체 인터페이스 원칙에 맞게 정비한다. 세 축이다.

1. **모션과 피드백** — 지금은 누름 피드백도 햅틱도 없고, 목록 변화가 통째 리로드로 튄다
2. **재질과 타이포그래피** — 다크모드 버그, 하드코딩 폰트, Dynamic Type 미대응
3. **Craft** — 셀 재사용 없음, 강제 언래핑, 죽은 코드, 한·영 문구 혼재

배포 타깃이 iOS 26.0이므로 최신 API를 제약 없이 쓴다.

## 결정 사항

| 항목 | 결정 |
| --- | --- |
| 리스트 구조 | `UITableView` 유지 + `UITableViewDiffableDataSource` 전환 |
| 식별자 | Core Data에 `id: UUID` 추가 (경량 마이그레이션 + 백필) |
| 셀 | `TableViewCell.xib` 폐기, 코드로 재작성 (자기 크기 조정) |
| UI 문구 | 한국어로 통일 |
| 진행 | 7개 섹션을 순서대로, 각 단계마다 빌드 + 시뮬레이터 확인 |

`UICollectionView` 리스트 레이아웃 이전은 검토 후 기각했다. 이 앱의 셀은 60pt 큰 숫자를 쓰는 커스텀이라 `UIListContentConfiguration`을 쓸 여지가 없고, 애니메이션 diff·중단 가능성이라는 핵심 이득은 `UITableViewDiffableDataSource`로 동일하게 얻는다. 변경 표면만 커진다.

---

## 1. 데이터 계층 — 식별자

### 문제

현재 D-day의 신원(identity)이 `selectedDate`다.

- 고정 목록: `selectedDate`를 ISO8601 문자열로 저장 (`DdayViewController.savePinnedDates`)
- 삭제: `NSPredicate(format: "selectedDate = %@")` (`DdayDataManager.removeData`)
- 조회: `Calendar.isDate(_:inSameDayAs:)` 매칭 (`DdayViewController.reloadAllData`)

**같은 날짜에 D-day를 두 개 만들면 서로 구분되지 않는다.** 하나를 지우면 fetch 결과의 `.first`가 지워지므로 엉뚱한 레코드가 삭제되고, 고정도 어느 쪽인지 결정할 수 없다. 날짜를 편집하면 고정 상태가 끊어져 `updateStoredPinnedDate(from:to:)`라는 보정 코드로 떠받치고 있다.

diffable data source는 안정적인 고유 식별자를 요구하므로, 이 결함을 고치지 않으면 2번 섹션이 성립하지 않는다.

### 변경

- `anneRed.xcdatamodeld`의 `DdayData`에 `id: UUID` 속성 추가 (optional로 선언해 경량 마이그레이션 성립)
- `DdayData+CoreDataProperties.swift`에 프로퍼티 추가
- `AppDelegate`에 1회성 백필: `id == nil`인 레코드에 `UUID()` 부여 후 저장
- `DdayDataManager.saveData`가 생성 시점에 `id` 부여
- `DdayDataManager.removeData`의 predicate를 `id = %@`로 교체. 시그니처를 `removeData(id:completion:)`로 변경
- 고정 목록 저장 키를 UUID 문자열 배열로 전환. 기존에 저장된 ISO 날짜 배열은 최초 1회 날짜 매칭으로 UUID로 변환한 뒤 폐기 (`pinnedDates` → `pinnedIDs` 키 이름 변경으로 구분)
- `updateStoredPinnedDate(from:to:)` 및 그 호출부(`DatePickerViewController.dismissAndReload`) 삭제 — UUID 기준에서는 날짜를 바꿔도 고정이 따라온다

### 위젯 영향

`saveWidgetData()`는 `title`과 `date` 문자열만 App Group에 넘기므로 위젯 쪽 계약은 바뀌지 않는다. 위젯 코드 수정 불필요.

### 검증

- 기존 데이터가 있는 상태로 실행해 백필이 도는지 확인
- 같은 날짜로 D-day 2개 생성 → 하나만 삭제되는지, 각각 독립적으로 고정되는지 확인
- 고정한 항목의 날짜를 편집 → 고정 유지되는지 확인

---

## 2. 리스트 모션 · 피드백

기준: §1 Response, §3 Interruptibility, §4 Behavior over animation, §13 Multimodal feedback

### diffable data source

`UITableViewDiffableDataSource<Section, UUID>`로 교체한다.

- `reloadAllData()`의 `tableView.reloadData()` → `apply(snapshot, animatingDifferences: true)`
- `leadingSwipeActionsConfigurationForRowAt`의 수동 `performBatchUpdates { deleteRows + insertRows }` 짝을 제거하고 스냅샷 하나로 대체. 고정/해제 시 행이 섹션 사이를 애니메이션으로 이동한다
- 삭제도 동일하게 스냅샷 경유
- `viewWillAppear`의 전면 리로드가 diff로 바뀌므로, 편집 후 복귀 시 바뀐 행만 움직인다

`animatingDifferences: true`는 내부적으로 중단 가능한 애니메이션을 쓴다 — §3이 요구하는 "진행 중 잡아서 되돌릴 수 있음"을 프레임워크가 제공한다.

### press 피드백 (§1)

셀에 `setHighlighted(_:animated:)` 오버라이드. **touch-down 즉시** 반응한다 — release를 기다리지 않는다.

```
scale 0.97, 배경 tint
UIViewPropertyAnimator(duration: 0.25, timingParameters: UISpringTimingParameters(dampingRatio: 1.0))
```

기존 애니메이터가 살아 있으면 `stopAnimation(false)` 후 **현재 presentation layer 값에서** 새 애니메이션을 시작한다 (§3: "always animate from the presentation value"). 목표값에서 시작하면 눈에 보이는 점프가 생긴다.

### 스프링 파라미터 (§4)

| 상황 | bounce | duration |
| --- | --- | --- |
| 기본 전환 (행 삽입/삭제, 편집 모드) | 0 (critically damped) | 0.4 |
| 스와이프로 고정/해제 | 0.2 | 0.4 |
| press 피드백 | 0 | 0.25 |

바운스는 제스처가 운동량을 실어 온 경우에만 준다. 스와이프는 손가락이 밀어낸 결과이므로 오버슈트가 맞고, 그냥 나타나는 전환에는 틀리다.

### 햅틱 (§13)

| 사건 | 피드백 |
| --- | --- |
| 고정 / 고정 해제 | `UIImpactFeedbackGenerator(style: .light)` |
| 삭제 확정 | `UIImpactFeedbackGenerator(style: .rigid)` |
| 저장 성공 | `UINotificationFeedbackGenerator` `.success` |
| 고정 최대치 도달 | `UINotificationFeedbackGenerator` `.warning` |

§13 harmony: 햅틱이 시각 변화와 **같은 프레임**에 터져야 한다. 제너레이터를 스와이프 시작 시점에 `prepare()`해 두고, 스냅샷 적용과 같은 지점에서 트리거한다. 지연되면 인과관계가 깨진다.

§13 utility: 위 네 개로 제한한다. 스크롤·탭·화면 전환에는 넣지 않는다 — 과하면 전부 무시하게 된다.

### 편집 모드 전환 수정

`DdayViewController.setEditing`의 현재 구현에 두 가지 문제가 있다.

```swift
tableView.visibleCells.compactMap { $0 as? TableViewCell }.forEach { cell in
    if editing { cell.ddayLabel.isHidden = true }
    else { UIView.transition(with: cell.ddayLabel, duration: 0.5, options: .transitionCrossDissolve) { ... } }
}
```

1. `visibleCells`만 순회하므로 이후 스크롤로 들어온 셀은 상태가 어긋난다
2. 0.5s 고정 duration 크로스디졸브 — §4가 말하는 "미리 각본이 짜인 애니메이션". 길고 중단 불가능하다

셀 자신의 `setEditing(_:animated:)` 오버라이드로 옮긴다. 셀이 재사용될 때 `tableView.isEditing`을 읽어 초기 상태를 맞춘다. 전환은 `bounce 0`, `duration 0.3` 스프링 + alpha.

### 검증

- 고정/해제 시 행이 섹션 간 이동하는 애니메이션이 보이는지
- 셀을 누른 즉시(떼기 전) 축소되는지
- 편집 모드에서 스크롤해 새로 들어온 셀도 D-day 라벨이 숨겨져 있는지
- 햅틱이 시각 변화와 동시에 오는지 (실기기 없으면 코드 위치로 확인)

---

## 3. 셀 재작성 · 타이포그래피

기준: §15 Typography

### xib 폐기

`TableViewCell.xib`의 세 라벨은 각각 `systemFont(weight: .light)` 60pt / 32pt / 16pt로 하드코딩돼 있고, `heightForRowAt`는 90을 반환한다. **Dynamic Type을 켜도 글자만 커지고 셀 높이는 그대로**라 잘린다.

코드로 재작성하고 `heightForRowAt`를 `UITableView.automaticDimension`으로 바꾼다. 셀 내부 제약을 `contentView` 상단부터 하단까지 끊김 없이 연결해야 자기 크기 조정이 성립한다.

### 타이포그래피 규칙

- **D-day 숫자**: `UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for:)`로 스케일. **`monospacedDigitSystemFont`** 필수 — 현재는 `D-9` → `D-10`처럼 자릿수가 바뀔 때 글자 폭이 흔들린다
- **네거티브 트래킹**: 큰 숫자에 `NSAttributedString.Key.kern`으로 `-0.02em` 상당 (§15 — 글자가 커질수록 자간이 벌어져 보이므로 조여야 한다). 본문 라벨은 0 근처를 유지
- 전 라벨 `adjustsFontForContentSizeCategory = true`
- 위계는 크기 단독이 아니라 **weight + size + leading 조합**으로 구성 (§15). 제목은 weight로 존재감을 주고 크기는 절제
- 여백은 고정 pt 대신 `UIFontMetrics`로 스케일해 큰 글자에서 레이아웃이 깨지지 않게 한다

### 접근성 라벨

현재 세 라벨이 VoiceOver에서 따로 읽힌다. `isAccessibilityElement = true`로 셀을 하나의 요소로 묶고 `accessibilityLabel`을 "2026년 3월 1일, D-30, 제목" 형태로 구성한다.

### 검증

- 설정에서 텍스트 크기를 최대로 올렸을 때 셀이 같이 커지고 글자가 잘리지 않는지
- D-day 숫자 자릿수가 바뀔 때 폭이 흔들리지 않는지
- VoiceOver로 셀 하나가 한 번에 읽히는지

---

## 4. 재질 · 다크모드

기준: §12 Materials & depth

### 다크모드 버그 (실질적 결함)

`DdayViewController.tableView(_:viewForHeaderInSection:)`에서 섹션 헤더 라벨이 `textColor = .white`로 하드코딩돼 있다. "다크모드 처리" 커밋(`ec51417`)이 있었으나 여기가 누락돼 **라이트모드에서 흰 배경에 흰 글씨**가 된다.

### 변경

- 손으로 만든 헤더 `UIView` + 수동 제약 + 수동 separator를 `UIListContentConfiguration.groupedHeader()` 기반으로 교체. 시스템 여백·타이포·다크모드 대응을 그대로 받는다
- 하드 구분선 제거 (§12: "scroll edge effects, not hard dividers"). iOS 26에서는 네비게이션 바·탭바가 기본으로 유리 재질이므로 커스텀 블러를 넣지 않고 `scrollEdgeAppearance` 정리만 한다
- 죽은 `if #available(iOS 15.0, *)` 분기 제거 (배포 타깃 26.0)

§12의 반투명 계층은 iOS 26 시스템 크롬이 이미 제공한다. 직접 `UIVisualEffectView`를 쌓지 않는다 — "light 반투명 위에 light 반투명을 겹치지 말라"는 규칙을 시스템이 지켜주고 있고, 손대면 깨진다.

### 검증

- 라이트/다크 모드를 전환하며 섹션 헤더가 양쪽에서 읽히는지
- 스크롤 시 콘텐츠가 네비게이션 바 아래로 자연스럽게 지나가는지

---

## 5. DatePicker 화면 정비

기준: §16 Craft, Feedback

코드 품질이 가장 나쁜 지점이다.

### 셀 재사용 없음 (버그 원인)

`DatePickerViewController.tableView(_:cellForRowAt:)`가 매 호출마다

```swift
let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
```

로 셀을 새로 만들고 `cell.contentView.addSubview(tf)`로 텍스트필드를 붙인다. 재사용이 전혀 없고, **테이블이 리로드될 때마다 텍스트필드가 새 인스턴스로 교체돼 입력 포커스가 날아간다.**

- 재사용 식별자로 등록하고 셀 클래스 2종으로 분리: 값 표시용(D-Day), 입력용(제목 / 계산)
- 텍스트필드는 셀이 소유하고 재사용 시 값만 갱신. delegate/target은 `prepareForReuse`에서 정리
- deprecated `textLabel` / `detailTextLabel` → `UIListContentConfiguration`

### 그 외

- 편집 진입인데 타이틀이 항상 `"Add List"`다. 신규/편집 분기 (한국어 문구로: "새 D-Day" / "편집")
- 강제 언래핑 정리: `data!.selectedDate!`, `dday!`, `daysLeft!`, `selectedDate!`
- `dismissAndReload`의 presenting VC 4단 캐스팅 체인을 제거한다. UUID 도입 후 `updateStoredPinnedDate` 호출이 사라지므로, `DatePickerViewControllerDelegate` 프로토콜(`didSave(id:)` / `didCancel()`)을 정의하고 `DdayViewController`가 채택한다. 프레젠팅 VC를 타입으로 추측하지 않는다
- `caculate` → `calculate` 오타 정정 (`caculInputText`, `caculResultText`, `caculateDay`, `caculTextFieldChanged`)

### "최대 2개" 막다른 버튼 (§16 Feedback)

현재 고정이 2개 찼을 때 스와이프하면 `completion(false)`만 하는 회색 "최대 2개" 버튼이 나온다. 아무 일도 하지 않는 버튼이라 §16의 피드백 4종(status / completion / warning / error) 중 어디에도 속하지 않는다.

warning으로 다시 설계한다. 모달 얼럿은 쓰지 않는다 — §16은 확인 대화상자를 정말 되돌릴 수 없는 파괴적 동작에만 쓰라고 하며, 이건 그런 상황이 아니다.

- 스와이프 액션 제목 자체를 이유와 해법으로 바꾼다: `"고정 해제 후 가능"`, 배경 `.systemGray`, 아이콘 `pin.slash`
- 탭하면 `.warning` 햅틱을 울리고 `completion(false)`로 행을 되돌린다 (§16 warning: 문제가 되기 전에 알린다)
- 동시에 고정 섹션 헤더 우측에 `"2/2"` 보조 텍스트를 상시 노출해, 스와이프하기 전에 이미 한도를 알 수 있게 한다 (§16: 사후 경고보다 사전 상태 노출이 낫다)

### 검증

- 제목 입력 중 날짜를 바꿔도 입력 포커스와 내용이 유지되는지
- 기존 항목을 탭했을 때 타이틀이 "편집"인지
- 고정 2개 찬 상태에서 세 번째를 스와이프했을 때 이유가 전달되는지

---

## 6. 접근성 — Reduced Motion

기준: §14

`UIAccessibility.isReduceMotionEnabled`가 켜져 있으면:

- 스프링과 스케일 변화를 짧은 크로스페이드(0.2s)로 대체
- 오버슈트(`bounce 0.2`) 제거 — 바운스는 전정계에 부담을 준다
- 행 삽입/삭제는 `animatingDifferences: false`

§14의 요점은 "피드백을 없애는 게 아니라 순한 등가물로 바꾸는 것"이다. 햅틱과 색·투명도 변화는 유지한다.

`UIAccessibility.reduceMotionStatusDidChangeNotification`을 구독해 런타임 변경에 반응한다.

### 검증

- 설정 > 손쉬운 사용 > 동작 > 동작 줄이기를 켜고 고정/삭제 시 스프링이 사라지는지

---

## 7. 죽은 코드 · 문구 정리

### 삭제

- `ViewController.swift` — 스토리보드에서 참조되지 않음
- `Model.swift` — 사용되지 않는 struct
- `TableViewCell.models` — 사용되지 않는 프로퍼티
- `DdayViewController.saveWidgetData()`의 `print` 디버그 3종
- 빈 `viewDidAppear` / `viewWillDisappear` 오버라이드 (`DdayViewController`)
- 빈 `awakeFromNib` / `setSelected` 오버라이드 (`TableViewCell`)
- `DdayNavigationViewController` / `DatePickerNavigationViewController`의 빈 `viewDidLoad`

### 문구 한국어 통일

| 현재 | 변경 |
| --- | --- |
| Record | 기록 |
| Add List | 새 D-Day / 편집 |
| Edit / Done | 편집 / 완료 |
| Cancel / Save | 취소 / 저장 |
| Pinned / Other | 고정 / 나머지 |
| Title (placeholder: title) | 제목 |
| Calculate (placeholder: days) | 일수 |
| Item 1 (탭바) | 기록 |

§16의 "모호한 우산 대신 구체적인 이름" 원칙을 적용한다. "Other"는 내용을 설명하지 않으므로 "전체"로 바꾼다.

### 남겨두는 것

`UpdateViewController`는 텍스트필드 2개가 어디에도 연결되지 않은 빈 스텁이다. 미구현 화면으로 판단해 손대지 않는다. 탭바에서 숨길지는 별도 판단 사항.

---

## 진행 순서

각 단계마다 `xcodebuild` 빌드 + iPhone 17 Pro 시뮬레이터 확인 후 다음으로 넘어간다.

1. 데이터 계층 (UUID 마이그레이션) — 가장 아래층, 나머지가 여기 의존
2. 리스트 모션 · 피드백
3. 셀 재작성 · 타이포그래피
4. 재질 · 다크모드
5. DatePicker 화면 정비
6. Reduced Motion
7. 죽은 코드 · 문구 정리

1번은 데이터 손실 위험이 있는 유일한 단계다. 기존 데이터가 있는 시뮬레이터 상태에서 마이그레이션과 백필을 먼저 확인한 뒤 진행한다.

## 범위 밖

- `UpdateViewController` 구현
- 위젯 디자인 변경 (데이터 계약이 그대로이므로 손대지 않음)
- 신규 기능 (알림, 반복 D-day, 정렬 옵션 등)
- Core Data → SwiftData 이전
