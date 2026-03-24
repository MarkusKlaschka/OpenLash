# Updated Suggestions for OpenLash Improvements (2026-03-24 Review)

Re-analyzed the codebase after recent pulls and structure checks. The project focuses on Perl modules for memory, LLM integrations, providers (e.g., API configs for Anthropic, OpenAI), skills (e.g., shell, weather), and tests (strong on memory topics). No `start.pl` or `connections.json` found in root—server logic may be in `OpenLash/Server.pm` or absent. Providers are mostly LLM JSON configs + ChromaDB/Memory.pm. Updated suggestions to match current state: added issues for missing server script, tailored to existing files, and emphasized building on providers/ and t/ directories.

I can't directly add issues to GitHub (no auth access). Drafts below for copy-paste, or grant browser permission for assisted posting.

### 1. **Bugs (High Priority Fixes)**
Address Telegram absence and potential server gaps.

- **Issue Title: Add and Fix Telegram Provider Integration (Missing/Non-Functional)**
  - **Description:** No Telegram provider exists (e.g., no `providers/telegram.pm` or JSON config), leading to non-functional chat. User reports it not working—likely needs new module for API handling.
  - **Suggested Changes:**
    - Create `providers/telegram.pm` with Bot API wrappers (use `WWW::Telegram::BotAPI` or similar).
    - Add error handling/logging for API calls (e.g., with `Try::Tiny`).
    - Include a test script in `t/` for sending/receiving messages.
    - Load bot token from env vars or new config.
    - **Why?** Fixes the core reported issue and adds chat capability.
  - **Priority:** High. **Labels:** bug, integration.

- **Issue Title: Implement or Fix Server Startup Script (e.g., start.pl Equivalent)**
  - **Description:** No `start.pl` found for gateway-server/socket opening. If server logic is in `OpenLash/Server.pm`, expose it via a startup script; otherwise, binding/listening may fail silently.
  - **Suggested Changes:**
    - Create `start.pl` to initialize server (use `IO::Socket::INET` for binding, check port availability).
    - Add graceful shutdown and CLI flags (via `Getopt::Long`).
    - Integrate with existing modules like `OpenLash/Server.pm` if present.
    - **Why?** Enables reliable server startup as per project plan.
  - **Priority:** High. **Labels:** bug, server.

### 2. **Improvements (Code Quality and Maintainability)**
Tailored to current Memory.pm (simple key-value store) and scattered configs.

- **Issue Title: Refactor Memory.pm for Enhanced Error Handling and Modularity**
  - **Description:** Current `Memory.pm` is basic (in-memory hash) but lacks validation, persistence, or logging. Recent changes may need consistency checks.
  - **Suggested Changes:**
    - Add subs for persistence (e.g., save/load to JSON file).
    - Include input validation (e.g., key type checks) and logging (e.g., `Log::Log4perl`).
    - Expand tests in `t/memory_*.t` with 2-3 new cases for edge scenarios.
    - **Why?** Boosts reliability for memory-dependent features.
  - **Priority:** Medium. **Labels:** enhancement, refactor.

- **Issue Title: Standardize Provider Configuration Loading**
  - **Description:** Provider JSON files (e.g., openai.json) are in `providers/`, but no central loader. Loading may be inconsistent across modules.
  - **Suggested Changes:**
    - Create `Config.pm` for unified JSON loading/validation (use `JSON::XS`).
    - Update modules (e.g., in OpenLash/) to use it; support env var overrides for keys.
    - Add a test in `t/` for config parsing.
    - **Why?** Simplifies maintenance as providers grow.
  - **Priority:** Medium. **Labels:** enhancement, config.

- **Issue Title: Add Comprehensive Logging and Monitoring Across Modules**
  - **Description:** Minimal logging; hard to debug issues like potential provider failures.
  - **Suggested Changes:**
    - Integrate `Log::Log4perl` with levels (debug/info/error).
    - Log events in key modules (e.g., Memory.pm store/retrieve, provider loads).
    - Add a simple health check function exportable to scripts.
    - **Why?** Improves diagnostics for the entire system.
  - **Priority:** Medium. **Labels:** enhancement, logging.

### 3. **New Features (Future Enhancements)**
Build on existing providers/ and skills/.

- **Issue Title: Add WebSocket Support for Real-Time Features (e.g., Telegram Proxy)**
  - **Description:** Enhance potential gateway with WebSockets for live updates (e.g., chat events).
  - **Suggested Changes:**
    - In new/existing server script, add WebSocket handling (`Protocol::WebSocket` or `Mojolicious`).
    - Proxy events from providers like Telegram to clients.
    - Add example client in a new script.
    - **Why?** Enables real-time capabilities aligned with chat fixes.
  - **Priority:** Low (after bugs). **Labels:** feature, integration.

- **Issue Title: Expand Automated Testing and Add CI Pipeline**
  - **Description:** Good memory tests in `t/`, but coverage could extend to providers/skills; no CI.
  - **Suggested Changes:**
    - Add tests for providers (e.g., mock API calls) aiming for 80%+ coverage.
    - Create `.github/workflows/ci.yml` for GitHub Actions (run `prove t/` on push/PR).
    - Include `Perl::Critic` linting.
    - **Why?** Prevents bugs in growing codebase.
  - **Priority:** Low. **Labels:** feature, testing.

- **Issue Title: Enhance Provider Plugin System (Add Chat Providers like Telegram/Slack)**
  - **Description:** `providers/` has LLM JSONs and DB modules; extend for chat services.
  - **Suggested Changes:**
    - Define a plugin interface (e.g., load dynamically via config).
    - Add Slack/Discord examples as `.pm` files.
    - Update docs/MEMORY_COMPRESSION.md or add new doc for providers.
    - **Why?** Makes OpenLash a versatile integration hub.
  - **Priority:** Low. **Labels:** feature, extensibility.

### Overall Recommendations
- **Prioritization:** Fix bugs first (Telegram, server script) to unblock core functionality. Improvements next for stability; features last.
- **General Changes:** Focus on modularity (e.g., more submodules in OpenLash/), security (env vars for secrets), and docs (expand on providers/skills in docs/).
- **Next Steps:** On 'walter' branch—commit updates here. For GitHub issues, provide repo URL for assistance. Ready to implement one?
