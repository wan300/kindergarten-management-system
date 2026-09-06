# Xiaozhi Local Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect the existing 3.5-inch Spotpear firmware protocol to the local kindergarten chat backend through the reused Xiaozhi voice server, then distinguish software verification from pending physical-board acceptance.

**Architecture:** Python retains upstream OTA/WebSocket/ASR/TTS. A narrow connection-aware bridge calls a device-authenticated Rails turn endpoint, which owns child binding, conversation history, model generation and persistence. The existing frontend shows those conversations with a device-source label.

**Tech Stack:** Python 3.10, upstream Xiaozhi server at 8a3c2c5, Ruby 3.1/Rails 7/SQLite, Vue 3, local FunASR/Silero, EdgeTTS for synthetic demonstrations only.

## Global Constraints

- 本机、一台已能使用小智官方服务的玩偶；不租服务器、不更新远程网站、不推送 Git、不刷机。
- 使用独立 Python 3.10 环境，不修改现有机器人项目环境或全局包源。
- 不使用 Docker。
- 第一版仅用于成人演示及虚构儿童身份，不作为真实儿童数据的生产系统。
- 小智后台负责语音，Rails 是儿童身份、对话上下文和消息记录的唯一业务来源。
- 平台保留已有 4000 / 3000 配置；缺少真实模型配置时不得假装真实 AI 已运行。
- 保留 backend/Gemfile、Gemfile.lock 的已有本地改动和所有无关文件。
- 首选不刷机切换；实物未连电脑之前不能宣称烧录或连接验收通过。

## Working locations and verification

Platform root: `/Users/kiyoku/澳科大课题组工作/Pingxing_XiaoZhi/kindergarten-management-system` (existing local dev branch).
Voice root: `/Users/kiyoku/澳科大课题组工作/Pingxing_XiaoZhi/xiaozhi-esp32-server` (create local integration branch before code changes).
Continue in the user's existing local checkouts to preserve the running preview and local dependency setup; do not move or reset the repositories.

Ruby command prefix: `PATH=/opt/homebrew/opt/ruby@3.1/bin:$PATH PARALLEL_WORKERS=1 bundle exec` from the backend directory. Test data must stay in the Rails test database.

## Task 1: Rails device turns and source display

Files (relative to platform root):
- Create backend `app/models/child_device.rb`, `app/models/device_chat_turn.rb`, migration for those records and device metadata on chat sessions.
- Create backend `app/services/child_chat_reply.rb`, `app/services/device_chat_exchange.rb`, `app/controllers/device_api/turns_controller.rb`.
- Modify backend `app/controllers/child_api/chat_messages_controller.rb`, `app/models/child_chat_session.rb`, `app/serializers/child_chat_session_serializer.rb`, `config/routes.rb`, `config/initializers/filter_parameter_logging.rb`.
- Add backend `lib/tasks/xiaozhi.rake` for explicit bind/disable, requiring device ID and explicit student ID; no fixture auto-selection.
- Modify active frontend `src-vue/views/ChildChatAdminView.vue` and `src-vue/views/ChildChatAdminView.test.js` for source display. `index.html` boots `src-vue/main.js`; do not change the obsolete React tree.
- Add backend `test/controllers/device_chat_turns_test.rb` and focused service/model tests as needed.

Interfaces:
- `POST /device/turns`, `Authorization: Bearer <XIAOZHI_BRIDGE_TOKEN>`; only direct loopback requests (use socket peer, not proxy-supplied forwarding headers). Config missing fails closed.
- Input: `{device_id: string, session_id: string, turn_id: string, content: string}`. Nonblank IDs max 128 chars, content 1..4000 chars; valid JSON strings only. Device IDs normalized case-insensitively.
- Output 201 new / 200 replay: `{chat_session_id: integer, turn_id: string, user_message: {id,role,content,...}, assistant_message: {id,role,content,model,...}}`.
- 401 invalid token; 403 non-loopback; 404 unknown/disabled binding; 422 invalid input; 409 input conflict, active turn or invalid retry state; 502 model failure. Error responses contain stable machine-readable `error` codes, not provider bodies or secrets.
- Store a binding ID and binding epoch/version in device sessions; rebind begins new history, even if external session ID is reused. Device metadata optional for legacy web sessions.
- Use a durable turn with `processing/completed/failed` status, unique session+turn ID, message references, attempt count and input. Reserve under short DB transaction; do not hold a SQLite write transaction over network I/O. Same session cannot start competing turns while one is processing. Same successful input replays without LLM call; mismatched input conflicts. Explicit same-ID retry after known failure max 2 attempts, reuses user message; ambiguous/crashed processing does not automatically restart a model call.
- `ChildChatReply` centralizes original prompt/history/serialization without changing web response contract. Do not persist user message twice when retrying a device turn.
- Local bind command must reject missing child/ID and display no secrets. Binding is operator-controlled, not a public registration endpoint.

Test-first steps:
- [x] Add failing Rails integration tests exercising the endpoint, real DB and fake only `DeepseekClient` at its external boundary.

```ruby
post '/device/turns', params: {device_id: 'test-device', session_id: 's1', turn_id: 't1', content: '你好'},
  headers: {'Authorization' => "Bearer #{ENV.fetch('XIAOZHI_BRIDGE_TOKEN')}"}, as: :json
assert_response :created
assert_equal '你好', response.parsed_body.dig('user_message', 'content')
assert_equal 2, ChildChatSession.find(response.parsed_body['chat_session_id']).child_chat_messages.count
```

- [x] Run `rails test test/controllers/device_chat_turns_test.rb`; establish failures due to missing route/feature, then implement the interface above in focused files.
- [x] Add replay/no-second-LLM-call, bad token, non-loopback, missing config, disabled device, mismatched input, failed retry, active turn, rebound device, and other-child access cases. Test concurrent reservation deterministically using held processing state plus a focused concurrent service test where practical.
- [x] Run `rails test test/controllers/device_chat_turns_test.rb test/controllers/child_learning_test.rb`, then full Rails suite once; report pre-existing failures separately.
- [x] Add source indicator test, run `NODE_OPTIONS=--no-experimental-webstorage npm test`, then `npm run build` in frontend.
- [x] Self-review and commit only task files locally. Report exact commands, RED/GREEN evidence, commit and limitations to `.superpowers/sdd/task-1-report.md`.

## Task 2: Voice bridge preserving upstream protocol

Files (relative to voice root):
- Create `main/xiaozhi-server/core/integrations/kindergarten.py` and `tests/test_kindergarten_bridge.py`.
- Modify `main/xiaozhi-server/core/connection.py` at initialization and top-level chat generation only; inspect exact `chat`/abort/queue lifecycle before patching.
- Add non-secret example configuration `docs/kindergarten-local.example.yaml`.

Interfaces:
- Read configuration `kindergarten.enabled`, `kindergarten.api_url` (default `http://127.0.0.1:3000/device/turns`) and secret from `XIAOZHI_BRIDGE_TOKEN` environment only.
- `KindergartenBridge.exchange(device_id, session_id, turn_id, content)` returns response text; request uses Task 1 JSON contract with finite connect/read timeout and no automatic POST retry.
- Per-connection context, new unique turn ID for each user turn, reused only for explicit retry. Never use shared mutable current-device state.
- When enabled, always use Rails for the conversation, no upstream LLM/tool/memory fallback; short safe errors on unavailable platform. Preserve TTS FIRST/MIDDLE/LAST queue lifecycle, abort behavior, subtitles and device audio protocol. Blank inputs or disconnected stale turns do not trigger background responses.
- Do not pass model-selected or browser-supplied student IDs. Bound device ID comes from connection handshake; local test network restriction remains explicit.

Test-first steps:
- [x] Write a unittest around an actual local fake HTTP boundary that checks correct headers/body, response parsing, bad/missing credentials, timeout/failure redaction and no automatic retry. Run `python -m unittest discover -s tests -p 'test_kindergarten_bridge.py' -v` to establish RED.
- [x] Implement the small bridge and connection hook; test lifecycle with lightweight fake queues and connection dependencies, asserting FIRST/text/LAST and cancellation/error behavior rather than mock call existence.
- [x] Run Python focused tests and syntax compilation. Keep upstream provider code unchanged unless essential for bridge isolation.
- [x] Self-review and commit only code/tests/nonsecret config. Report to ignored `tmp/task-2-report.md`.

## Task 3: Isolated environment, real protocol test and handoff

Files:
- Voice root `scripts/kindergarten_local.py`: launcher/preflight generating effective local config, environment-based secrets, loopback default and explicit LAN opt-in; no global configuration edits.
- Voice root `scripts/kindergarten_smoke.py`: synthetic OTA/hello/text round trip diagnostic with credentials never printed.
- Voice root `docs/kindergarten-local.md`: exact setup, start/stop, endpoints, hardware switch and restore instructions.
- Platform root approved spec and plan checkboxes/report updated to actual completion status.

Steps:
- [x] Create Python 3.10 runtime/venv and package cache under voice root ignored `.runtime`/`.venv`; check model download size/source and disk before downloading SenseVoiceSmall weights. Reuse installed libopus/ffmpeg or isolate required libraries.
- [x] Test launcher URL validation and config before implementing. Disabled tools/vision/voiceprint/memory; local ASR; EdgeTTS only for synthetic sample. Console/file logs must not capture transcripts or credentials. Inspect audio artifacts cleanup on failures.
- [x] Start against an isolated real Rails endpoint with a synthetic model boundary to test real upstream OTA, WebSocket hello, text response and audio encoding. Label this mock-model test; do not modify production code with fake-reply switches.
- [x] Run adapter against real Rails test app/database with fake model only at the provider boundary, assert messages persisted and returned via admin API. Never impersonate an existing real user or attach synthetic turns to a real child's identity.
- [x] Check actual platform model configuration for presence without printing values; if unavailable, leave model integration explicitly unverified and explain safe setup.
- [x] Before LAN use, validate WebSocket authentication, restrict enabled test devices and prevent unauthenticated OTA token issuance from being called production-grade device identity.
- [x] Confirm absence/presence of USB board; if present, read-only version/log inspection first. No erase/flash without separately confirmed target and recovery path.
- [x] Final reviews for Tasks 1/2/3; re-run changed tests and frontend build. Leave physical-board test pending if hardware is absent. Hand off one clear startup path and exact pending physical steps, not a guarantee unsupported by evidence.

## Progress ledger

- [x] Spec approved by user, with explicit requirement for physical connection acceptance.
- [x] Task 1 implemented and reviewed (a1f4e40, independent/final review clean; 70 Rails tests / 467 assertions).
- [x] Task 2 implemented and reviewed (834f5e4, independent review clean).
- [x] Task 3 environment/protocol tests and documentation reviewed (a4aaf3c, final review clean; 24 Python tests plus Rails harness regression, both real protocol modes passed with admin records).
- [ ] Physical device connected, response played and corresponding platform record verified.

Real model credentials are also pending. Current end-to-end tests deliberately use a synthetic provider boundary. No firmware edits/flashing, remote deployment, merge or push occurred. Temporary test services are stopped after verification; startup and real-board acceptance steps are documented in the sibling voice repository at `docs/kindergarten-local.md`.
