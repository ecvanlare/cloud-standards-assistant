# User isolation (serving BFF)

Each browser session gets its own Foundry conversation. Session A’s follow-ups must not see session B’s turns.

## Mechanism

1. Client `session_id` from `POST /api/session` (or first `/api/ask`).
2. BFF maps `session_id → Foundry conversation_id` in memory (`serving/app/main.py`).
3. `/api/ask` continues only that conversation.
4. **New session** clears the client id → new Foundry conversation.

`SESSION_PEPPER` comes from Key Vault (MI) to prove secret wiring. Foundry auth is Entra / UAMI, not this pepper.

## Multi-replica

The map is per replica. After scale-out, a request may land on a replica without that mapping and start a **new** conversation — it still cannot open another user’s conversation.

For sticky multi-replica production: Redis, or a signed HttpOnly cookie holding `conversation_id`.
