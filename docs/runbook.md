# RustDesk Server Pro — Operational Runbook

Internal runbook for running the Artorias remote-support service. Assumes the
deployment described in this repo (single instance, `remote.artoriastechlab.com`,
hbbs + hbbr + Caddy, data on a snapshotted EBS volume).

---

## 1. Mental model (read this first)

RustDesk Server Pro separates **people** from **machines**:

| Concept | What it is | One thing to remember |
|---|---|---|
| **User** | A login (you, a client's boss, a tech) | A user belongs to one *user group* |
| **User Group** | A bucket of people (e.g. "Acme Corp") | Created under **Users / Groups** |
| **Device** | A managed machine (endpoint) | Belongs to **at most one** *device group* |
| **Device Group** | A bucket of machines (e.g. "Acme — Devices") | Created under **Device Groups** |
| **Access** | "this user group may reach this device group" | Configured via cross-group access |
| **Control Role** | What you can *do in-session* (file transfer, etc.) | Separate from access |
| **Strategy** | Bulk client policy (security settings) | Pushed to devices/users |

**The whole multi-tenant model is:** create a user group + a device group per
client, add the client's people to the user group, add their machines to the
device group, and grant the user group access to *only* that device group.

---

## 2. Prerequisites

- **License tier ≥ Basic** ($23.88/mo). Required for two features we depend on:
  - *Custom client generator* (white-label branding)
  - *Creating non-admin users* (the client's "boss" accounts) — the Individual
    plan cannot do this.
- **SMTP configured** (Settings → SMTP) so invitation + verification emails work.
  See the Google Workspace relay setup notes elsewhere.
- **Admin account hygiene**: change the default `admin` password, enable email
  login verification, and create a second admin before decommissioning `admin`.

---

## 3. One-time setup

1. **Brand the client** — in the console's custom-client generator, set the
   Artorias name + logo. This produces the branded installer/config you hand to
   every device (client machines *and* the boss's laptop).
   *(If you don't see the generator, confirm the license is Basic or higher.)*
2. **Confirm SMTP** — send a test email from Settings → SMTP.
3. **Decide your control roles / strategies** — create a default strategy that
   reflects your security posture before rolling out devices.

---

## 4. Client onboarding checklist

Repeat per client (example: **Acme Corp**).

- [ ] **Create the user group** — Users / Groups → *Acme Corp*.
- [ ] **Create the device group** — Device Groups → *Acme — Devices*.
- [ ] **Create the boss's user** — Users → New user:
      - username e.g. `acme-boss`
      - assign to user group *Acme Corp*
      - **do NOT** check "administrator"
      - set a temporary password + email (they'll get an invitation/verification)
- [ ] **Grant access** — Device Groups → *Acme — Devices* → Edit → allow the
      *Acme Corp* user group to access it (cross-group access).
- [ ] **Install the custom client on the machines** you manage for them.
- [ ] **Assign each machine to the device group** — Devices → Edit → Group →
      *Acme — Devices* (or batch via command line, see §7).
- [ ] **Verify isolation** — log in as `acme-boss`: they should see *only* Acme's
      devices. Log in as admin: you should see everything.
- [ ] **(Optional) trim the boss's control role** — restrict in-session
      capabilities if you don't want them doing file transfer/port forwarding.

### Offboarding a client

- [ ] Disable the client's users (Users → disable).
- [ ] Uninstall the client from their machines (or disable the devices).
- [ ] Remove/empty the device group and user group once devices are gone.
- [ ] Keep the audit logs (do not delete — billing/legal trail).

---

## 5. Device installation & assignment

**Install** — hand the branded client to the endpoint and run it.

**Assign to a device group** — two ways:

- **Console:** Devices → find device → Edit → change Group.
- **Command line (batch-friendly):**
  ```powershell
  "C:\Program Files\RustDesk\rustdesk.exe" --assign --token <token> --device_group_name "Acme — Devices"
  ```
  Requires an API token (Settings → Tokens → Create) with Device write
  permission. Also supports `--user_name`, `--strategy_name`, `--device_name`,
  `--note`, etc.

**Require-deployment gate (optional):** if you enable "Require deployment for
new devices", brand-new clients won't register until you approve them — useful
to stop rogue endpoints from joining. Approve via `--deploy` (needs a token with
Device read/write).

---

## 6. Access-control reference

- A device can be assigned to **one user**, **one device group**, or both.
- A device assigned to a user is reachable by that user, their user group, or
  cross-user-group settings.
- A device assigned to a device group is reachable via cross-group settings.
- **Access is cumulative** — access is granted if *either* user-group or
  device-group permissions allow it.
- Disabled users / disabled devices are **never** reachable.

Practical rule for our model: use **device-group-based access** (assign machines
to a device group, grant the client's user group access to it). It scales better
than per-device user assignment.

---

## 7. License & billing monitoring

- The license caps **login users** and **managed devices**. Watch both in the
  console as you onboard clients.
- Basic = 10 users / 100 devices. Cross it → upgrade to Customized
  (+$1.20/user, +$0.12/device, annual).
- **No auto-renew** — set a calendar reminder; renewal notice arrives ~14 days
  before expiry.

---

## 8. Monthly activity report (client-facing value)

Use the **audit logs** (connection, file transfer, alarms) to produce a
per-client activity summary — a strong retention/upsell artifact:

- Connection audits: who connected, to what, when.
- File-transfer audits: what moved.
- Alarm audits: device offline/online events.

Filter by client's device group / user and summarize. (CLI: `audits.py view-conn
--days-ago 30`, etc., via API token.)

---

## 9. Troubleshooting quick reference

| Symptom | Likely cause | Fix |
|---|---|---|
| Device not reachable | Device disabled, or user disabled | Re-enable in console |
| Boss sees no devices | Cross-group access not set | Device Groups → Edit → grant user group |
| Boss sees *wrong* devices | Access too broad | Remove cross-group grants; keep per-client |
| New device won't register | "Require deployment" on | Approve via `--deploy` + token |
| Email invite not sent | SMTP misconfigured | Settings → SMTP → test send |
| Relay-only (slow) session | Direct P2P blocked by NAT | Expected; add regional relay if clients far away |
| Can't create non-admin user | Individual plan | Upgrade to Basic |

---

## 10. Key console locations

- **Users** — create/disable users, set group + admin flag
- **Groups** (user groups) — create groups, set cross-group access
- **Devices** — browse, assign, disable devices
- **Device Groups** — create device groups, grant access
- **Strategies** — bulk client security policy
- **Control Roles** — in-session permissions
- **Settings → SMTP** — email
- **Settings → Tokens** — API tokens for CLI automation
- **Logs** — connection / file / console / alarm audits
