# User isolation (serving BFF)

## Goal

Two browser sessions must not share Foundry conversation state. A follow-up in session A must not see session B’s turns.

## How this app does it

1. The UI creates a **client session id** (`POST /api/session` or first `/api/ask`).
2. The BFF maps `session_id → Foundry conversation_id` in an **in-process** dict (`serving/app/main.py`).
3. Each `/api/ask` continues only the conversation bound to that `session_id`.
4. **New session** clears the client id so the next ask creates a new Foundry conversation.

Session ids are opaque UUIDs. The Container App injects `SESSION_PEPPER` from Key Vault (via managed identity) to prove secret wiring; it is not used as a Foundry API key (Foundry auth is Entra / UAMI).

## Multi-replica limit

The map is **not** shared across replicas. With `min_replicas > 1` or scale-out, a sticky client may hit another replica and lose the in-memory mapping (a new Foundry conversation starts). That still does **not** leak another user’s conversation: there is no cross-session lookup by design.

For production multi-replica sticky sessions, move the map to Redis or store the Foundry `conversation_id` in an HttpOnly cookie signed with the KV pepper. Out of scope for AZP-4.

## What we do not do

- No shared global conversation id
- No API keys for Foundry in source or env plaintext (MI only)
- No downloading third-party chat templates
