# Mobile-Specific Flakiness (Appium)

Mobile E2E flakiness has unique causes beyond timing.

---

## Mobile-specific causes

| Cause | Symptom | Fix |
|---|---|---|
| App install failure | `AppiumError: App not installed` | Retry install step, verify APK path in CI artifacts |
| Device/emulator not ready | `ConnectionRefused` on session start | Add `adb wait-for-device` / health check before test |
| System dialogs (permissions, updates) | Test clicks wrong element | Dismiss system dialogs in `beforeAll` or app setup |
| Keyboard covering elements | `Element not interactable` | Scroll to element before interaction, dismiss keyboard explicitly |
| Animation lag on slower emulators | `Element not found` during transition | Set `animationsEnabled: false` in test builds |
| App crash (unrelated to test) | Session dies mid-test | Capture logcat on failure, file bug separately |

## Appium retry config

```python
# conftest.py
from appium import webdriver

@pytest.fixture(scope="function")
def driver(request):
    caps = {
        "platformName": "Android",
        "deviceName": "emulator-5554",
        "app": os.environ["APP_PATH"],
        "noReset": False,
        "newCommandTimeout": 120,
        "androidInstallTimeout": 90000,
    }
    d = webdriver.Remote("http://localhost:4723/wd/hub", caps)
    yield d
    d.quit()
```

```ini
# pytest.ini — extra delay for mobile startup
addopts = --reruns 2 --reruns-delay 3
```

## Pre-test device setup

```python
def setup_device(driver):
    # Dismiss any system dialogs
    try:
        driver.find_element(By.ID, "android:id/button1").click()  # "Allow"
    except:
        pass  # no dialog present

    # Disable animations for stable selectors
    driver.execute_script("mobile: shell", {
        "command": "settings put global window_animation_scale 0 && "
                   "settings put global transition_animation_scale 0 && "
                   "settings put global animator_duration_scale 0"
    })

    # Wait for app to be fully loaded
    WebDriverWait(driver, 30).until(
        EC.presence_of_element_located((By.ID, "com.example.app:id/main_container"))
    )
```

## Mobile flaky rate tracking

Track mobile flakiness separately from web E2E:
- Mobile flaky rate target: < 5% (higher tolerance — emulators are noisier)
- Quarantine threshold: fails on > 3 different runs in a week
- Escalate to dev if: crash logs appear in logcat on failure
