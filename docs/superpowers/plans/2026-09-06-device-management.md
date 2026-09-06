# Xiaozhi Device Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the verified Xiaozhi board from the isolated test database to the platform development database, with automatic discovery and administrator-controlled binding, disabling, re-enabling, rebinding, and chat lookup.

**Architecture:** Rails remains the authority for device discovery, binding state, child identity, conversations, and authorization. The local Python voice server reports a device at OTA/WebSocket entry, allows only Rails-approved devices, and still sends every turn through the existing Rails bridge. Vue adds one administrator-only device page that combines pending discoveries and bound devices without copying test data.

**Tech Stack:** Ruby 3.1, Rails 7, SQLite, Minitest, Vue 3, Vue Router, Vitest, Python 3.10, aiohttp, HTTPX, upstream Xiaozhi OTA/WebSocket protocol.

## Global Constraints

- Work only in the existing local platform and voice repositories; do not deploy the public server, push Git, flash firmware, or use Docker.
- Preserve all existing development data and unrelated dirty-worktree changes.
- Do not migrate the isolated synthetic child, test administrator, or test conversations into the normal development database.
- `ChildDevice` records always represent an explicit child binding; pending devices live in a separate discovery table.
- Unbound and disabled devices cannot receive a usable chat connection, call DeepSeek, or create child conversations.
- Rebinding rotates `binding_id` and increments `binding_epoch`; old conversations remain with the old child and never enter the new child context.
- Re-enabling the same binding preserves its binding version.
- Internal device endpoints accept only direct loopback requests authenticated by `XIAOZHI_BRIDGE_TOKEN`.
- Secrets remain in macOS Keychain or ignored runtime files and never enter source, logs, database fields, documentation, commits, or command output.
- The local profile remains trusted-LAN development only; device IDs are identifiers, not proof of hardware ownership.

---

## File map

Platform backend:

- `db/migrate/20260906000200_create_device_discoveries.rb`: durable first/last-seen records for unbound and known devices.
- `app/models/device_discovery.rb`: normalization and idempotent observation.
- `app/controllers/device_api/base_controller.rb`: shared loopback and bridge-token checks.
- `app/controllers/device_api/registrations_controller.rb`: observe a device and return only its authorization state.
- `app/controllers/device_api/turns_controller.rb`: inherit the shared internal controller without changing the turn contract.
- `app/services/child_device_management.rb`: list, bind, rebind, disable, and enable transactional operations.
- `app/controllers/admin_api/child_devices_controller.rb`: administrator JSON interface.
- `app/controllers/admin_api/child_chat_sessions_controller.rb`: optional normalized device filter.
- `config/routes.rb`: internal registration and administrator device routes.
- `test/models/device_discovery_test.rb`, `test/controllers/device_registrations_test.rb`, `test/controllers/admin_api/child_devices_controller_test.rb`: backend behavior and permission coverage.

Platform frontend:

- `src-vue/views/DeviceManagementView.vue`: complete management screen and confirmations.
- `src-vue/views/DeviceManagementView.test.js`: rendering and action coverage.
- `src-vue/views/ChildChatAdminView.vue`: read `device_id` query and request the filtered chat list.
- `src-vue/views/ChildChatAdminView.test.js`: filtered-chat coverage.
- `src-vue/layouts/RoleLayout.vue`: administrator navigation item.
- `src-vue/router/index.js`, `src-vue/router/router.test.js`: protected route.
- `src-vue/styles.css`: scoped reusable device status, grid, dialog, and responsive styles.

Voice server:

- `main/xiaozhi-server/core/integrations/kindergarten.py`: add registration/status call beside the existing turn exchange.
- `main/xiaozhi-server/core/websocket_server.py`: require Rails status `enabled` after token verification.
- `main/xiaozhi-server/core/connection.py`: remove static kindergarten device-set checks; the turn endpoint remains the final authorization boundary.
- `scripts/kindergarten_local.py`: register at OTA entry and remove the required `--device` argument.
- `tests/test_kindergarten_bridge.py`, `tests/test_kindergarten_local.py`: registration, fail-closed, and dynamic authorization tests.
- `docs/kindergarten-local.md`: normal-development startup and pairing instructions.

Runtime-only, ignored:

- `.runtime/rails-development.ru`: Keychain-backed real-model Rails process using the repository's normal development database.
- `.runtime/device-management-acceptance-2026-09-06.md`: non-secret verification evidence.

---

### Task 1: Rails device discovery and internal authorization

**Files:**

- Create: `kindergarten-management-system-backend/db/migrate/20260906000200_create_device_discoveries.rb`
- Create: `kindergarten-management-system-backend/app/models/device_discovery.rb`
- Create: `kindergarten-management-system-backend/app/controllers/device_api/base_controller.rb`
- Create: `kindergarten-management-system-backend/app/controllers/device_api/registrations_controller.rb`
- Modify: `kindergarten-management-system-backend/app/controllers/device_api/turns_controller.rb`
- Modify: `kindergarten-management-system-backend/config/routes.rb`
- Create: `kindergarten-management-system-backend/test/models/device_discovery_test.rb`
- Create: `kindergarten-management-system-backend/test/controllers/device_registrations_test.rb`

**Interfaces:**

- Consumes: `ChildDevice.normalize_id(value)` and `ENV["XIAOZHI_BRIDGE_TOKEN"]`.
- Produces: `DeviceDiscovery.observe!(device_id:, at: Time.current) -> DeviceDiscovery` and `POST /device/registration` returning `{device_id, status}` where status is `pending`, `enabled`, or `disabled`.

- [ ] **Step 1: Write failing model tests**

```ruby
require "test_helper"

class DeviceDiscoveryTest < ActiveSupport::TestCase
  test "observe normalizes and updates one discovery" do
    first = DeviceDiscovery.observe!(device_id: " AA:BB ", at: Time.zone.parse("2026-09-06 10:00"))
    second = DeviceDiscovery.observe!(device_id: "aa:bb", at: Time.zone.parse("2026-09-06 10:05"))

    assert_equal first.id, second.id
    assert_equal "aa:bb", second.device_id
    assert_equal Time.zone.parse("2026-09-06 10:00"), second.first_seen_at
    assert_equal Time.zone.parse("2026-09-06 10:05"), second.last_seen_at
  end

  test "observe rejects blank and oversized identifiers" do
    assert_raises(ActiveRecord::RecordInvalid) { DeviceDiscovery.observe!(device_id: " ") }
    assert_raises(ActiveRecord::RecordInvalid) { DeviceDiscovery.observe!(device_id: "x" * 129) }
  end
end
```

- [ ] **Step 2: Write failing internal endpoint tests**

Cover valid pending, enabled, disabled, repeated observation, blank/oversized/non-string IDs, missing configuration, wrong token, non-loopback peer, and responses that never contain student fields.

```ruby
post "/device/registration",
  params: { device_id: "New-Board" },
  headers: { "Authorization" => "Bearer bridge-test-token-32-characters", "REMOTE_ADDR" => "127.0.0.1" },
  as: :json
assert_response :success
assert_equal({ "device_id" => "new-board", "status" => "pending" }, response.parsed_body)
```

- [ ] **Step 3: Run the new tests and verify the missing feature fails**

Run:

```bash
PATH=/opt/homebrew/opt/ruby@3.1/bin:$PATH PARALLEL_WORKERS=1 bundle exec rails test test/models/device_discovery_test.rb test/controllers/device_registrations_test.rb
```

Expected: failure because `DeviceDiscovery` and `/device/registration` do not exist.

- [ ] **Step 4: Add the discovery migration and model**

```ruby
class CreateDeviceDiscoveries < ActiveRecord::Migration[7.0]
  def change
    create_table :device_discoveries do |t|
      t.string :device_id, null: false
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false
      t.timestamps
    end
    add_index :device_discoveries, :device_id, unique: true
  end
end
```

Implement `observe!` with `ChildDevice.normalize_id`, validation, a short transaction, `first_seen_at ||= at`, and `last_seen_at = at`. Rescue `ActiveRecord::RecordNotUnique` once by loading the winner and updating `last_seen_at`; do not recurse indefinitely.

- [ ] **Step 5: Extract the shared internal controller and add registration**

`DeviceApi::BaseController < ActionController::API` owns `require_loopback`, `authenticate_bridge`, and `render_error`. Change `TurnsController` to inherit it and remove only the duplicated private methods.

`RegistrationsController#create` validates a string ID of 1–128 non-whitespace characters, calls `DeviceDiscovery.observe!`, loads `ChildDevice` by normalized ID, and returns:

```ruby
status = if device.nil?
  "pending"
elsif device.enabled?
  "enabled"
else
  "disabled"
end
render json: { device_id: discovery.device_id, status: status }, status: :ok
```

Add `post "/registration", to: "registrations#create"` inside the existing device scope.

- [ ] **Step 6: Run migrations in test and run focused tests**

Run the Task 1 test command again. Expected: all Task 1 tests pass and the existing device-turn tests remain green:

```bash
PATH=/opt/homebrew/opt/ruby@3.1/bin:$PATH PARALLEL_WORKERS=1 bundle exec rails test test/models/device_discovery_test.rb test/controllers/device_registrations_test.rb test/controllers/device_chat_turns_test.rb
```

- [ ] **Step 7: Commit Task 1**

Commit only the Task 1 files with message `feat: register local child devices`.

---

### Task 2: Administrator device management and chat filtering

**Files:**

- Create: `kindergarten-management-system-backend/app/services/child_device_management.rb`
- Create: `kindergarten-management-system-backend/app/controllers/admin_api/child_devices_controller.rb`
- Modify: `kindergarten-management-system-backend/app/models/child_device.rb`
- Modify: `kindergarten-management-system-backend/app/controllers/admin_api/child_chat_sessions_controller.rb`
- Modify: `kindergarten-management-system-backend/config/routes.rb`
- Create: `kindergarten-management-system-backend/test/controllers/admin_api/child_devices_controller_test.rb`
- Modify: `kindergarten-management-system-backend/test/controllers/child_learning_test.rb`

**Interfaces:**

- Consumes: Task 1 `DeviceDiscovery`, existing `ChildDevice.bind!`, `Student`, `Classroom`, and administrator JWT authorization.
- Produces: `ChildDeviceManagement.list`, `.bind!(device_id:, student_id:)`, `.disable!(id:)`, `.enable!(id:)`, and REST endpoints under `/admin/child_devices`.

- [ ] **Step 1: Write failing administrator tests**

Create discoveries and bound devices, then verify:

```ruby
get "/admin/child_devices", headers: admin_headers
assert_response :success
assert_equal ["disabled", "enabled", "pending"], response.parsed_body.map { |row| row["status"] }.sort

post "/admin/child_devices/bind",
  params: { device_id: "pending-board", student_id: @student.id },
  headers: admin_headers,
  as: :json
assert_response :created
assert_equal @student.id, response.parsed_body.dig("student", "id")
```

Also test teacher/parent/child/anonymous rejection; nonexistent discovery, student, or device; duplicate clicks; same-child no-op/re-enable; different-child epoch rotation; disable; enable; and retained old sessions.

- [ ] **Step 2: Add a failing chat device-filter test**

Create one web session and two device sessions. Request `/admin/child_chat_sessions?device_id=board-a` and assert only `board-a` sessions are returned. Assert an unknown normalized ID returns an empty array.

- [ ] **Step 3: Run focused tests and verify route/service failures**

```bash
PATH=/opt/homebrew/opt/ruby@3.1/bin:$PATH PARALLEL_WORKERS=1 bundle exec rails test test/controllers/admin_api/child_devices_controller_test.rb test/controllers/child_learning_test.rb
```

Expected: failures for missing administrator device routes and missing device filter.

- [ ] **Step 4: Implement the management service**

`list` returns the union of discovery IDs and existing `ChildDevice` IDs, so a bound legacy row remains manageable even before its next observation. Rows are ordered with pending first and the available `last_seen_at` descending. Each row has:

```ruby
{
  id: device&.id,
  device_id: discovery.device_id,
  status: device.nil? ? "pending" : device.enabled? ? "enabled" : "disabled",
  first_seen_at: discovery&.first_seen_at,
  last_seen_at: discovery&.last_seen_at,
  bound_at: device&.updated_at,
  student: device && { id: device.student.id, name: student_name(device.student), admission_number: device.student.admission_number },
  classroom: device && { id: device.student.classroom.id, name: device.student.classroom.name }
}
```

`bind!` requires an existing discovery and student. Lock an existing device. When student is unchanged, set `enabled=true` without rotating binding identity; otherwise call the existing binding path so the epoch increments and binding UUID changes. `disable!` and `enable!` lock the device and update only `enabled`.

- [ ] **Step 5: Implement administrator routes and controller**

Add:

```ruby
resources :child_devices, only: [:index] do
  collection { post :bind }
  member do
    patch :disable
    patch :enable
  end
end
```

The controller renders list rows directly, returns `201` for a first binding, `200` for rebind/re-enable, `404` for unknown resources, `409` for stale conflicts, and `422` for invalid input. It never exposes `binding_id` or service credentials.

- [ ] **Step 6: Add normalized chat filtering**

When `params[:device_id]` is present, normalize it, locate the matching `ChildDevice`, and filter by `child_device_id`; an unknown ID yields `ChildChatSession.none`. Keep the existing student filter compatible and composable.

- [ ] **Step 7: Run Task 2 and related Rails tests**

```bash
PATH=/opt/homebrew/opt/ruby@3.1/bin:$PATH PARALLEL_WORKERS=1 bundle exec rails test test/controllers/admin_api/child_devices_controller_test.rb test/controllers/child_learning_test.rb test/controllers/device_chat_turns_test.rb
```

Expected: all focused tests pass.

- [ ] **Step 8: Commit Task 2**

Commit only Task 2 files with message `feat: manage child devices as admin`.

---

### Task 3: Vue administrator device page

**Files:**

- Create: `kindergarten-management-system-frontend/src-vue/views/DeviceManagementView.vue`
- Create: `kindergarten-management-system-frontend/src-vue/views/DeviceManagementView.test.js`
- Modify: `kindergarten-management-system-frontend/src-vue/layouts/RoleLayout.vue`
- Create: `kindergarten-management-system-frontend/src-vue/layouts/RoleLayout.test.js`
- Modify: `kindergarten-management-system-frontend/src-vue/router/index.js`
- Modify: `kindergarten-management-system-frontend/src-vue/router/router.test.js`
- Modify: `kindergarten-management-system-frontend/src-vue/views/ChildChatAdminView.vue`
- Modify: `kindergarten-management-system-frontend/src-vue/views/ChildChatAdminView.test.js`
- Modify: `kindergarten-management-system-frontend/src-vue/styles.css`

**Interfaces:**

- Consumes: Task 2 `/admin/child_devices`, `/admin/child_devices/bind`, `/admin/child_devices/:id/disable`, `/admin/child_devices/:id/enable`, `/admin/students`, and `/admin/classrooms`.
- Produces: protected route `/admin_dashboard/child_devices` and chat link `/admin_dashboard/child_chat_sessions?device_id=<encoded-id>`.

- [ ] **Step 1: Write failing route and navigation tests**

Assert the router resolves `/admin_dashboard/child_devices` with `meta.role === "admin"` and redirects an unauthenticated visit to `/admin_login`. In `RoleLayout.test.js`, mount `RoleLayout` for admin and assert the visible label `设备管理`; mount teacher/parent layouts and assert it is absent.

- [ ] **Step 2: Write failing page tests**

Mock the API with one pending, one enabled, and one disabled row. Assert the page shows all three counts, device IDs, child/classroom data, and correct action labels. Exercise binding, disabling, enabling, rebinding confirmation, repeated-submit prevention, API failure feedback, and the encoded chat link.

```js
expect(api.post).toHaveBeenCalledWith(
  "/admin/child_devices/bind",
  { device_id: "aa:bb", student_id: 7 },
  "admin",
)
```

- [ ] **Step 3: Add a failing filtered-chat test**

Mount `ChildChatAdminView` with route query `{ device_id: "aa:bb" }` and assert it requests `/admin/child_chat_sessions?device_id=aa%3Abb`; without the query it must keep the original endpoint.

- [ ] **Step 4: Run focused Vue tests and verify failures**

```bash
NODE_OPTIONS=--no-experimental-webstorage npm test -- --run src-vue/router/router.test.js src-vue/layouts/RoleLayout.test.js src-vue/views/DeviceManagementView.test.js src-vue/views/ChildChatAdminView.test.js
```

Expected: failure because the route and page do not exist and chat filtering is absent.

- [ ] **Step 5: Implement route, navigation, and page data flow**

Add `TabletSmartphone` navigation icon and the administrator-only route. The page loads devices, students, and classrooms in parallel, derives counts from `status`, filters students by selected classroom and search text, and sends integer `student_id` values.

Use one semantic dialog state:

```js
const dialog = reactive({ open: false, mode: "bind", device: null, classroomId: "", studentId: "", search: "" });
```

`mode` is `bind`, `rebind`, or `disable`. The confirm handler uses `saving` to reject duplicate clicks, calls the exact Task 2 endpoint, closes only on success, shows a toast/notice, and refreshes the list.

- [ ] **Step 6: Implement the current visual style and responsive layout**

Use existing `page-heading`, `surface`, `surface-pad`, `button`, and `notice` classes. Add only focused `.device-*` classes for the three summary cards, pending cards, desktop table, mobile cards, status pills, and modal overlay. At widths below 760px hide the table header and render each device row as a labeled card. Status pills include text `待绑定`, `使用中`, or `已停用` in addition to color.

- [ ] **Step 7: Implement chat navigation filtering**

Use `useRoute()` in `ChildChatAdminView`, encode the query with `URLSearchParams`, and preserve the unfiltered endpoint when no device ID exists. Display a small active-filter line and a “清除筛选” route link when filtered.

- [ ] **Step 8: Run frontend tests and build**

```bash
NODE_OPTIONS=--no-experimental-webstorage npm test -- --run src-vue/router/router.test.js src-vue/layouts/RoleLayout.test.js src-vue/views/DeviceManagementView.test.js src-vue/views/ChildChatAdminView.test.js
npm run build
```

Expected: focused tests pass and Vite production build exits zero.

- [ ] **Step 9: Commit Task 3**

Commit only Task 3 files with message `feat: add admin device management page`.

---

### Task 4: Dynamic Rails authorization in the voice server

**Files:**

- Modify: `xiaozhi-esp32-server/main/xiaozhi-server/core/integrations/kindergarten.py`
- Modify: `xiaozhi-esp32-server/main/xiaozhi-server/core/websocket_server.py`
- Modify: `xiaozhi-esp32-server/main/xiaozhi-server/core/connection.py`
- Modify: `xiaozhi-esp32-server/scripts/kindergarten_local.py`
- Modify: `xiaozhi-esp32-server/tests/test_kindergarten_bridge.py`
- Modify: `xiaozhi-esp32-server/tests/test_kindergarten_local.py`

**Interfaces:**

- Consumes: Task 1 `POST http://127.0.0.1:3000/device/registration` and existing bridge token.
- Produces: `KindergartenBridge.registration_status(device_id) -> str`, accepting only `pending`, `enabled`, or `disabled`; dynamic OTA and WebSocket gates.

- [ ] **Step 1: Write failing bridge registration tests**

Use the existing local HTTP fake boundary and assert the method posts only `{device_id}`, sends the bearer token, rejects empty IDs, rejects unexpected status/body, redacts remote bodies from errors, disables redirects/environment proxies, and performs no automatic retries.

```python
self.assertEqual("enabled", bridge.registration_status("AA:BB"))
self.assertEqual({"device_id": "aa:bb"}, captured["json"])
```

- [ ] **Step 2: Write failing launcher and dynamic-gate tests**

Assert `build_config` works with no device list, includes `registration_url`, and never inserts a static kindergarten allowlist. Test the OTA wrapper for pending/disabled `403`, enabled sanitized OTA response, and Rails failure `503`. Test `WebSocketServer._handle_auth` refuses non-enabled Rails state after normal token verification.

- [ ] **Step 3: Run focused Python tests and verify failures**

```bash
.venv/bin/python -m unittest tests.test_kindergarten_bridge tests.test_kindergarten_local -v
```

Expected: failures for missing `registration_status`, required `--device`, and static device-set behavior.

- [ ] **Step 4: Implement the registration client**

Refactor the HTTP request construction into a private method shared by turn exchange and registration. `registration_status` normalizes the ID, performs exactly one POST to the configured registration URL, requires HTTP 200 and an exact allowed status string, and raises `KindergartenBridgeError("Kindergarten registration unavailable")` for transport, JSON, or response failures without embedding provider text.

- [ ] **Step 5: Replace the OTA static allowlist**

Remove the required `devices` validation and `--device` parser requirement. Configure:

```python
config['kindergarten'] = {
    'enabled': True,
    'api_url': 'http://127.0.0.1:3000/device/turns',
    'registration_url': 'http://127.0.0.1:3000/device/registration',
}
```

Before calling upstream `OTAHandler.handle_post`, run `registration_status` via `asyncio.to_thread`. Return `403 {"error":"device_pending"}` or `403 {"error":"device_disabled"}` for those states and `503 {"error":"platform_unavailable"}` on bridge failure. Only enabled devices receive the sanitized connection-only OTA response.

- [ ] **Step 6: Replace WebSocket and connection static checks**

In kindergarten mode, `WebSocketServer._handle_auth` performs existing HMAC token verification and then awaits the same status check via `asyncio.to_thread`; anything other than `enabled` raises `AuthenticationError("Device is not enabled")`.

Remove `kindergarten_device_ids` construction and membership checks from `ConnectionHandler`. Keep the final `/device/turns` authorization unchanged, and change `_chat_with_kindergarten` to require only a nonblank normalized device ID plus the current cancellation checks.

- [ ] **Step 7: Run Python focused and full tests**

```bash
.venv/bin/python -m unittest tests.test_kindergarten_bridge tests.test_kindergarten_local -v
.venv/bin/python -m unittest discover -s tests -v
.venv/bin/python -m compileall -q scripts tests main/xiaozhi-server/core/integrations/kindergarten.py main/xiaozhi-server/core/websocket_server.py main/xiaozhi-server/core/connection.py
```

Expected: all local integration tests pass and compilation exits zero.

- [ ] **Step 8: Commit Task 4**

Commit only Task 4 files in the voice repository with message `feat: authorize discovered devices through platform`.

---

### Task 5: Normal development runtime and end-to-end acceptance

**Files:**

- Modify: `xiaozhi-esp32-server/docs/kindergarten-local.md`
- Create ignored: `xiaozhi-esp32-server/.runtime/rails-development.ru`
- Create ignored: `xiaozhi-esp32-server/.runtime/device-management-acceptance-2026-09-06.md`
- Modify: `kindergarten-management-system/docs/superpowers/plans/2026-09-06-device-management.md` checkboxes only after evidence exists.

**Interfaces:**

- Consumes: Tasks 1–4, the named Keychain DeepSeek credential, ignored bridge token, normal Rails development database, current board `ac:a7:04:22:9e:80`, ports 3000/4000/8000/8003.
- Produces: one documented normal-development startup path and verified browser/board workflow.

- [ ] **Step 1: Back up and migrate the normal development database**

Identify the resolved development SQLite path without printing records. Copy that exact file to a timestamped ignored `.runtime/backups` path if it exists, then run:

```bash
PATH=/opt/homebrew/opt/ruby@3.1/bin:$PATH bundle exec rails db:migrate RAILS_ENV=development
```

Verify the schema contains `device_discoveries`; do not alter or delete the isolated protocol database.

- [ ] **Step 2: Create and syntax-check the ignored Rails runtime**

Create `.runtime/rails-development.ru` using the same Keychain lookup and source-location assertion as `.runtime/rails-live.ru`, but omit `SQLITE_DB_PATH` and the synthetic JWT secret. Load `XIAOZHI_BRIDGE_TOKEN` from `.runtime/kindergarten-bridge.token`, set the official DeepSeek base/model, load the normal Rails environment, and run `Rails.application`. Verify the file is ignored and `ruby -c` reports `Syntax OK` without printing the credential.

- [ ] **Step 3: Run all automated verification before switching services**

Platform backend:

```bash
PATH=/opt/homebrew/opt/ruby@3.1/bin:$PATH PARALLEL_WORKERS=1 bundle exec rails test
```

Platform frontend:

```bash
NODE_OPTIONS=--no-experimental-webstorage npm test -- --run
npm run build
```

Voice server:

```bash
.venv/bin/python -m unittest discover -s tests -v
```

Record exact pass/fail counts. Existing warnings may be reported separately but no changed-feature failure is accepted.

- [ ] **Step 4: Switch local services without killing unrelated processes**

Resolve listeners on 3000, 4000, 8000, and 8003. Stop only the previously identified platform/voice process IDs. Start Rails from `.runtime/rails-development.ru`, Vue from the active frontend, and the voice launcher without `--device`. Verify all four listeners and HTTP health endpoints.

- [ ] **Step 5: Verify browser management against normal development data**

Log in with an existing normal development administrator. Confirm “设备管理” is visible, current platform children load, pending/empty states render, and non-admin tokens are rejected. Do not create a hidden synthetic administrator or child.

- [ ] **Step 6: Complete physical pairing with the user present**

Ask the user to restart the current board. Verify `ac:a7:04:22:9e:80` appears pending without a chat record. The user selects a development-only child in the page and confirms binding, then restarts/reconnects the board.

- [ ] **Step 7: Complete physical conversation and lifecycle checks**

Have the user make two related spoken turns and confirm audible playback. Verify the normal database records real `deepseek-v4-flash` replies for the selected child. From the UI, test chat link, disable/rejection, re-enable/recovery, and—using a second development-only child—rebind/context isolation. Never manufacture physical-device turns through the API.

- [ ] **Step 8: Update documentation and non-secret evidence**

Document the normal-development commands, pairing steps, test-mode distinction, restore path, external data flows, and trusted-LAN limitation in `docs/kindergarten-local.md`. Write only counts, status, model name, device ID, timestamps, and process/listener metadata to the ignored acceptance file; omit tokens, JWTs, transcripts, child details, and API keys.

- [ ] **Step 9: Final diff and commit**

Run `git diff --check` in both repositories, review `git status`, and commit the tracked voice documentation with message `docs: add development device pairing workflow`. Do not stage the platform's pre-existing Gemfile changes or unrelated documentation, and do not push either repository.
