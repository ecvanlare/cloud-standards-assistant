(() => {
  const thread = document.getElementById("thread");
  const form = document.getElementById("askForm");
  const questionEl = document.getElementById("question");
  const sendBtn = document.getElementById("send");
  const sessionIdEl = document.getElementById("sessionId");
  const newSessionBtn = document.getElementById("newSession");

  const ASK_TIMEOUT_MS = 180000;
  let sessionId = localStorage.getItem("csa_session_id") || "";
  let pendingEl = null;

  function renderEmpty() {
    if (thread.children.length) return;
    thread.innerHTML = `
      <div class="empty">
        <strong>Ask a cloud standards question</strong>
        WAF pillars, ASB/MCSB controls, NIST CSF, or Terraform azurerm versions.
        Each browser session maps to one Foundry conversation.
      </div>`;
  }

  function setSession(id) {
    sessionId = id;
    localStorage.setItem("csa_session_id", id);
    sessionIdEl.textContent = id.slice(0, 8) + "…";
    sessionIdEl.title = id;
  }

  function addBubble(role, text, meta) {
    const empty = thread.querySelector(".empty");
    if (empty) empty.remove();
    const div = document.createElement("div");
    div.className = `bubble ${role}`;
    const body = document.createElement("div");
    body.className = "bubble-body";
    body.textContent = text;
    div.appendChild(body);
    if (meta) {
      const m = document.createElement("span");
      m.className = "meta";
      m.textContent = meta;
      div.appendChild(m);
    }
    thread.appendChild(div);
    thread.scrollTop = thread.scrollHeight;
    return div;
  }

  function setPending(on) {
    if (on) {
      if (pendingEl) return;
      pendingEl = addBubble("assistant pending", "Working with Foundry…");
      pendingEl.setAttribute("aria-busy", "true");
      return;
    }
    if (pendingEl) {
      pendingEl.remove();
      pendingEl = null;
    }
  }

  function formatDetail(detail) {
    if (!detail) return "Request failed";
    if (typeof detail === "string") return detail;
    if (Array.isArray(detail)) {
      return detail
        .map((d) => (typeof d === "string" ? d : d.msg || JSON.stringify(d)))
        .join("; ");
    }
    if (typeof detail === "object" && detail.msg) return detail.msg;
    try {
      return JSON.stringify(detail);
    } catch {
      return String(detail);
    }
  }

  async function ensureSession() {
    if (sessionId) {
      setSession(sessionId);
      return;
    }
    const res = await fetch("/api/session", { method: "POST" });
    if (!res.ok) throw new Error("Could not create session");
    const data = await res.json();
    setSession(data.session_id);
  }

  async function askOnce(question) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), ASK_TIMEOUT_MS);
    try {
      const res = await fetch("/api/ask", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ question, session_id: sessionId }),
        signal: controller.signal,
      });
      const data = await res.json().catch(() => ({}));
      return { res, data };
    } finally {
      clearTimeout(timer);
    }
  }

  newSessionBtn.addEventListener("click", async () => {
    localStorage.removeItem("csa_session_id");
    sessionId = "";
    setPending(false);
    thread.innerHTML = "";
    renderEmpty();
    try {
      await ensureSession();
    } catch {
      sessionIdEl.textContent = "offline";
    }
  });

  questionEl.addEventListener("keydown", (e) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      form.requestSubmit();
    }
  });

  form.addEventListener("submit", async (e) => {
    e.preventDefault();
    const question = questionEl.value.trim();
    if (!question || sendBtn.disabled) return;

    sendBtn.disabled = true;
    addBubble("user", question);
    questionEl.value = "";
    setPending(true);

    try {
      await ensureSession();
      let { res, data } = await askOnce(question);

      // In-memory session map is lost after scale-to-zero / new replica — retry once with a fresh session.
      if (!res.ok && res.status >= 500) {
        localStorage.removeItem("csa_session_id");
        sessionId = "";
        await ensureSession();
        ({ res, data } = await askOnce(question));
      }

      setPending(false);
      if (!res.ok) {
        addBubble("error", formatDetail(data.detail) || `Error ${res.status}`);
      } else {
        setSession(data.session_id);
        const bits = [data.tool_path, data.status];
        if (data.trace_id) bits.push(`trace ${data.trace_id.slice(0, 8)}…`);
        const meta = bits.filter(Boolean).join(" · ");
        addBubble("assistant", data.answer || "(empty)", meta || undefined);
      }
    } catch (err) {
      setPending(false);
      const msg =
        err && err.name === "AbortError"
          ? "Timed out waiting for Foundry (3 min). Try New session, then ask again."
          : err.message || "Request failed";
      addBubble("error", msg);
    } finally {
      sendBtn.disabled = false;
      questionEl.focus();
    }
  });

  renderEmpty();
  ensureSession().catch(() => {
    sessionIdEl.textContent = "offline";
  });
})();
