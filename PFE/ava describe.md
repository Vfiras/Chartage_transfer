# AVA Architecture

## Slide Version (One Slide)

**AVA = LangGraph supervisor + 6 specialized sub-agents + RAG + BI analytics + safety gates**

**1. LangGraph Supervisor Pipeline**
- `START`
- `classify` -> Gemini intent routing across 6 domains
- `gate` -> role gate blocks client access to admin domains (`operations`, `insights`)
- `dispatch` -> sends request to the selected sub-agent graph
- `safety` -> verifies that any success claim is backed by a real tool execution
- `session_write` -> stores the turn in chat history and emits final response / analytics payload
- `END`

**2. Six Sub-Agents**
- `Booking` -> trip history, vehicle recommendation, create/update/cancel booking, booking disambiguation, confirmation before write actions
- `Support` -> RAG over company policy/FAQ/vehicles/destinations, grounded answers only
- `Loyalty` -> points, tier, next-tier gap, active promo codes
- `Feedback` -> complaint/claim submission with confirmation gate
- `Operations` -> admin fleet, pricing rules, suppliers, promotions, booking-status management
- `Insights` -> admin dashboards, all bookings, users, business analysis, analytics card payloads

**3. RAG Pipeline**
- 5 company documents in `knowledge/`
- chunking -> HuggingFace embeddings (`all-MiniLM-L6-v2`) -> ChromaDB vector store
- retrieve top `k=3` chunks with relevance scoring
- drop chunks below relevance floor `0.25`
- if best score < `0.50`, run query expansion for vocabulary mismatch, merge + dedupe results
- Gemini synthesizes only from retrieved context

**4. Confirmation Gate**
- LLM proposes action
- AVA converts it into natural-language confirmation
- user replies `yes` / `no`
- on `yes`: execute tool + humanized success message
- on `no`: cancel action
- used for state-changing flows: booking actions, complaints, admin write actions

**5. Business Analytics Pipeline**
- Admin analytics request
- Supervisor `Guard 0` detects analysis phrases deterministically
- routes directly to `insights`
- `run_business_analysis`
- real MongoDB aggregations in `analytics_service`
- deterministic KPI + chart specs
- 1 dedicated Gemini analyst call for narrative
- SSE emits `analytics` payload -> Flutter `AnalyticsCard`

**6. Safety Measures**
- role gate for admin-only domains
- audit log for denied access, admin tool calls, safety overrides
- 3-layer error handling: model/router fallback, assistant stream catch-all, supervisor-build catch-all
- identity binding: `user_id` is pre-bound into client tools and hidden from the LLM schema

---

## Detailed Version (Diagram / Jury Slide Notes)

### A. Top-Level Architecture

`User/App` -> `FastAPI /assistant/chat (SSE)` -> `LangGraph Supervisor` -> `Selected Sub-Agent` -> `Tools / MongoDB / ChromaDB / Gemini` -> `Safety + Session Write` -> `SSE response / Analytics card`

### B. LangGraph Supervisor: Every Node in Order

**1. `classify`**
- Reads latest user message
- Sticky confirmation rule: if previous AVA message was a confirmation prompt, it reuses the current domain instead of reclassifying `yes/no`
- Admin `Guard 0`: business-analysis phrases skip normal classification and route directly to `insights`
- Otherwise Gemini classifies into exactly one domain:
  - `booking`
  - `support`
  - `loyalty`
  - `feedback`
  - `operations`
  - `insights`
- Defensive keyword guards correct misroutes for booking/support/admin edge cases

**2. `gate`**
- Checks role against domain
- Clients cannot access `operations` or `insights`
- On denial:
  - writes `access_denied` to `audit_log`
  - returns a polite refusal
  - jumps directly to `session_write`

**3. `dispatch`**
- Loads the correct compiled sub-agent
- Uses per-domain thread isolation: `{supervisor_thread_id}_{domain}`
- Passes only the latest human message; the sub-agent keeps its own MemorySaver history
- Captures:
  - new sub-agent messages
  - final assistant text
  - optional analytics payload from `insights`

**4. `safety`**
- Checks whether the final response claims success with words like `confirmed`, `completed`, `created`, `updated`, `submitted`
- Verifies that a real successful `ToolMessage` exists
- If not, AVA overrides the reply with a safe generic failure
- Logs `safety_override` in `audit_log`

**5. `session_write`**
- Persists `(human, assistant, timestamp)` into `chat_sessions`
- Adds the final AI message back into supervisor state
- Passes analytics payload through for SSE streaming

**6. `END`**

### C. The 6 Sub-Agents: Tools + Capabilities

**1. Booking Agent**
- Internal graph:
  - `classify`
  - `lookup`
  - `disambiguate`
  - `resolve_selection`
  - `action`
- Tools:
  - `get_trip_history`
  - `recommend_vehicle`
  - `create_booking`
  - `update_booking`
  - `cancel_booking`
- What it can do:
  - show upcoming/past trips
  - track current rides from actual booking data
  - recommend real vehicles from live fleet data
  - create, modify, cancel bookings
  - resolve ambiguous booking references before write actions
  - require confirmation before create/update/cancel

**2. Support Agent**
- Tool:
  - `search_knowledge_base`
- What it can do:
  - answer FAQs and company-policy questions
  - explain pricing rules, terms, destinations, vehicle info
  - stay grounded in retrieved knowledge only
  - offer action handoff like cancellation/help request without fabricating facts

**3. Loyalty Agent**
- Tool:
  - `get_user_promos`
- What it can do:
  - show points balance
  - show loyalty tier
  - compute next-tier gap in points and trips
  - list active promo codes
  - fall back to deterministic exact responses if Gemini is unavailable

**4. Feedback Agent**
- Tool:
  - `submit_claim`
- What it can do:
  - collect user complaints/feedback
  - optionally link complaint to a booking
  - require confirmation before database write

**5. Operations Agent**
- Tools:
  - `manage_fleet`
  - `manage_pricing_rules`
  - `manage_suppliers`
  - `manage_promotions`
  - `update_booking_status`
- What it can do:
  - list/create/update/delete fleet entries
  - toggle vehicle availability
  - read/update pricing rules
  - list/create/update/delete suppliers
  - list/create/update/toggle/delete promotions
  - update booking status directly
- Execution model:
  - read-only admin actions execute immediately and are synthesized into prose
  - state-changing admin actions go through confirmation gate

**6. Insights Agent**
- Tools:
  - `get_dashboard_analytics`
  - `get_admin_overview`
  - `list_all_bookings`
  - `list_users`
  - `run_business_analysis`
- What it can do:
  - answer admin-wide reporting questions
  - show dashboard analytics
  - list all bookings and users
  - run full business review, revenue, seasonal, pricing-impact, or vehicle-performance analysis
  - attach structured analytics payloads for the frontend card renderer

### D. RAG Pipeline

**Knowledge Base**
- 5 text documents:
  - `faq.txt`
  - `pricing_policy.txt`
  - `terms_and_conditions.txt`
  - `vehicles.txt`
  - `destinations.txt`

**Indexing**
- loader reads all `.txt` files
- chunking with `RecursiveCharacterTextSplitter`
  - chunk size `500`
  - overlap `50`
- embeddings: `sentence-transformers/all-MiniLM-L6-v2`
- storage: ChromaDB persistent vector store
- freshness guard:
  - manifest stores file hashes
  - startup warns if index is stale vs knowledge files

**Retrieval**
- `search_knowledge_base(query)`
- similarity search with relevance scores
- top `k=3` chunks
- keep only chunks with score `>= 0.25`

**Query Expansion**
- if top score `< 0.50`, AVA treats it as low-confidence vocabulary mismatch
- example trigger: `airport`
- expanded retrieval uses KB-native phrasing such as:
  - driver sign
  - free waiting time
  - flight delayed / arrives early
- merge + dedupe both retrieval passes
- keep best 3 results

**Answer Synthesis**
- Support agent sends retrieved chunks to Gemini
- persona rules forbid citing facts not present in retrieved text
- if nothing clears the floor, AVA should admit the KB does not contain the answer

### E. Confirmation Gate Workflow

**Shared pattern used by Booking, Feedback, and Operations write actions**

**Step 1. Proposal**
- model selects a tool call
- AVA converts raw tool intent into natural language
- example pattern: `I'd like to ... Reply yes to confirm or no to cancel.`

**Step 2. Pending State**
- stores:
  - pending tool name
  - filtered tool args
  - summary text
  - `awaiting_confirmation = true`

**Step 3. User Decision**
- `yes` -> execute tool
- `no` -> cancel cleanly
- ambiguous answer -> re-ask without another model/tool cycle

**Step 4. Execution**
- tool runs with safe filtered args
- internal `ToolMessage` is kept as evidence
- user sees only a humanized result message

**Why it matters**
- prevents unintended writes
- keeps tool names / JSON hidden from users
- gives the supervisor safety node verifiable evidence

### F. Business Analytics / BI Pipeline

**Full flow**
- Admin sends analytics question
- Supervisor `Guard 0` checks deterministic phrase triggers
- routes directly to `insights` without spending a classification call
- Insights fast path maps phrase -> `analysis_type`
  - `full_review`
  - `revenue`
  - `seasonal`
  - `pricing_impact`
  - `vehicles`
- `run_business_analysis` executes

**Inside `run_business_analysis`**
- calls real deterministic MongoDB analytics methods:
  - `get_revenue_by_month`
  - `get_revenue_by_vehicle_category`
  - `get_booking_volume_trend`
  - `get_seasonal_analysis`
  - `get_pricing_impact_analysis`
  - `get_kpi_summary`
- builds deterministic outputs:
  - KPI tiles
  - chart specs
  - fallback insights
- then makes exactly 1 dedicated Gemini analyst call for the narrative
- if Gemini fails, deterministic insights still render

**Frontend delivery**
- analytics payload stored in `AIMessage.additional_kwargs`
- supervisor passes payload through `session_write`
- SSE sends:
  - `analytics` event first
  - `done` event with narrative second
- Flutter renders interactive `AnalyticsCard`

### G. Safety Measures

**1. Role Gate**
- clients are blocked from admin-only domains before any admin tool is reached

**2. Audit Log**
- logs:
  - `access_denied`
  - admin `tool_call`
  - `safety_override`

**3. Three-Layer Error Handling**
- Layer 1: model/router fallback collapses provider failures to a friendly runtime error
- Layer 2: assistant streaming runner catches any supervisor/sub-agent exception and emits only a friendly SSE error
- Layer 3: even supervisor-build failure is caught before streaming starts, so no raw traceback reaches the app

**4. Identity Binding**
- client tools requiring `user_id` are pre-bound in `tool_registry`
- `user_id` is removed from the LLM-visible schema
- prevents the model from spoofing another user identity
- SSE thread IDs are namespaced with authenticated `user_id`

### H. Suggested Diagram Layout for the Jury

**Main diagram**
- `Frontend/App`
- `FastAPI SSE Endpoint`
- `LangGraph Supervisor`
- branch to `6 Sub-Agents`
- branch to:
  - `MongoDB`
  - `ChromaDB`
  - `Gemini`
- bottom strip: `Safety Layer`

**Inset 1: Supervisor**
- `classify -> gate -> dispatch -> safety -> session_write`

**Inset 2: RAG**
- `5 docs -> chunking -> embeddings -> ChromaDB -> retrieve -> relevance floor -> query expansion -> grounded answer`

**Inset 3: BI**
- `Guard 0 -> analytics_service aggregations -> KPI/chart specs -> Gemini narrative -> AnalyticsCard`
