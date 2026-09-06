# Task 1 report: Rails device turns and source display

## Outcome

Implemented the local, loopback-only Xiaozhi bridge endpoint at `POST /device/turns`, durable device bindings and turns, shared child-chat reply handling, operator-only bind/disable tasks, and admin source indicators. No server, SSH, push, or device flashing was performed.

## Contract and design

- Requires direct socket peer `REMOTE_ADDR` to be loopback; forwarded headers are ignored for this decision.
- Requires `Authorization: Bearer <XIAOZHI_BRIDGE_TOKEN>` and fails closed when the environment variable is absent.
- Validates all four JSON values as strings; IDs are nonblank and at most 128 characters, content is nonblank and at most 4000 characters.
- Device IDs are trimmed and lowercased. Rebinding rotates a UUID binding ID and increments an epoch, so an reused external session ID starts fresh history.
- Reservation occurs in a short database transaction, while the model call occurs after it. A partial unique database index enforces at most one processing turn per session.
- Completed matching turns replay with HTTP 200 and no model call. Mismatched input, active/ambiguous processing, invalid retry state, or exhausted retries return HTTP 409.
- A known failed model call may be retried once (two total attempts) using the original user message. Provider errors are reduced to `{"error":"model_failure"}`.
- Stable error codes: `bridge_not_configured`, `invalid_token`, `loopback_required`, `invalid_input`, `device_not_bound`, `turn_input_conflict`, `turn_processing`, `active_turn`, `invalid_retry_state`, `retry_exhausted`, and `model_failure`.
- Existing child web message response shape and provider-error behavior remain unchanged through `ChildChatReply`.
- `xiaozhi:bind` requires both `DEVICE_ID` and `STUDENT_ID`; `xiaozhi:disable` requires `DEVICE_ID`. Neither selects fixture/default students nor prints secrets.

## TDD evidence

RED:

```text
PATH=/opt/homebrew/opt/ruby@3.1/bin:$PATH PARALLEL_WORKERS=1 XIAOZHI_BRIDGE_TOKEN=test-bridge-token bundle exec rails test test/controllers/device_chat_turns_test.rb
ActionController::RoutingError: No route matches [POST] "/device/turns"
1 runs, 0 assertions, 0 failures, 1 errors
```

An intermediate focused run exposed a retry transaction bug (`Expected attempt_count 2, Actual 1`). Replacing a non-local return from the transaction block produced the final GREEN result.

GREEN and regression commands:

```text
PATH=/opt/homebrew/opt/ruby@3.1/bin:$PATH PARALLEL_WORKERS=1 XIAOZHI_BRIDGE_TOKEN=test-bridge-token bundle exec rails test test/controllers/device_chat_turns_test.rb
9 runs, 77 assertions, 0 failures, 0 errors

PATH=/opt/homebrew/opt/ruby@3.1/bin:$PATH PARALLEL_WORKERS=1 XIAOZHI_BRIDGE_TOKEN=test-bridge-token bundle exec rails test test/controllers/device_chat_turns_test.rb test/controllers/child_learning_test.rb
16 runs, 135 assertions, 0 failures, 0 errors

PATH=/opt/homebrew/opt/ruby@3.1/bin:$PATH PARALLEL_WORKERS=1 XIAOZHI_BRIDGE_TOKEN=test-bridge-token bundle exec rails test
62 runs, 412 assertions, 0 failures, 0 errors

NODE_OPTIONS=--no-experimental-webstorage npm test
8 files, 27 tests passed

npm run build
1638 modules transformed; build completed successfully

PATH=/opt/homebrew/opt/ruby@3.1/bin:$PATH bundle exec rails zeitwerk:check
All is good!
```

## Review notes and limitations

- Rails emits the pre-existing sandbox warning `sysctl ... Operation not permitted`; it does not affect results.
- Full Rails tests also print expected ffmpeg diagnostics for intentionally invalid fixture MP4 bytes; the suite passes.
- Vitest prints its existing Vite CJS deprecation warning; tests pass.
- Concurrency is covered deterministically by a held-processing integration case plus a database partial unique index. A timing-sensitive threaded SQLite test was intentionally avoided; SQLite serializes writes and would make that test environment-dependent.
- The source indicator and focused executable UI test cover the active Vue view used by the production build.

## Review fixes (2026-09-06)

The follow-up review established that the React tree is inactive; the source display now exists only in the production Vue view and its executable test. Additional coverage proves that rebinding uses the new child's prompt and excludes both the former child's name and prior history, and that another child cannot read a device-created session.

The review also found a concrete retry race: retrying a failed turn while a different turn was processing could hit the partial unique index and loop through an unconditional `RecordNotUnique` retry. A regression reproduced this as `Timeout::Error: execution expired`; reservation now detects the competing processing turn before updating and converts any database uniqueness race into one bounded `active_turn` conflict without calling the model.

Device binding is rechecked from the database after the model response and before any successful API response. If the device was disabled or rebound during the call, the old student's completed exchange remains auditable but the caller receives `409 {"error":"binding_changed"}` and no reply body. The bind task now requires `STUDENT_ID` to match a strict positive-integer format.

Review RED evidence:

```text
device rebound during model call: expected 409, received 201
failed turn with competing processing turn: Timeout::Error: execution expired
invalid STUDENT_ID=1abc: expected strict-positive-integer error, received "Student not found"
```

Review GREEN commands:

```text
PATH=/opt/homebrew/opt/ruby@3.1/bin:$PATH PARALLEL_WORKERS=1 XIAOZHI_BRIDGE_TOKEN=test-bridge-token bundle exec rails test test/controllers/device_chat_turns_test.rb
12 runs, 96 assertions, 0 failures, 0 errors

PATH=/opt/homebrew/opt/ruby@3.1/bin:$PATH PARALLEL_WORKERS=1 XIAOZHI_BRIDGE_TOKEN=test-bridge-token bundle exec rails test test/controllers/device_chat_turns_test.rb test/tasks/xiaozhi_rake_test.rb test/controllers/child_learning_test.rb
20 runs, 158 assertions, 0 failures, 0 errors

PATH=/opt/homebrew/opt/ruby@3.1/bin:$PATH PARALLEL_WORKERS=1 XIAOZHI_BRIDGE_TOKEN=test-bridge-token bundle exec rails test
66 runs, 435 assertions, 0 failures, 0 errors

NODE_OPTIONS=--no-experimental-webstorage npm test
8 files, 27 tests passed

npm run build
1638 modules transformed; build completed successfully
```

## Replay binding recheck (2026-09-06)

A second review identified that completed-turn replay returned before the live binding check. Deterministic tests change the binding immediately after the initial device lookup and before the old binding's session lookup. Both rebind and disable cases initially returned HTTP 200 with the old assistant body (RED). Replay and newly generated responses now share `binding_current?`; either path returns `409 {"error":"binding_changed"}` when the enabled binding ID, epoch, student, or device no longer matches. A third regression covers disabling during the model call and confirms the old student's exchange remains auditable without returning its reply.

Focused GREEN command:

```text
PATH=/opt/homebrew/opt/ruby@3.1/bin:$PATH PARALLEL_WORKERS=1 XIAOZHI_BRIDGE_TOKEN=test-bridge-token bundle exec rails test test/controllers/device_chat_turns_test.rb
15 runs, 116 assertions, 0 failures, 0 errors
```

Per review instruction, the full suites were not rerun for this narrowly scoped follow-up.
