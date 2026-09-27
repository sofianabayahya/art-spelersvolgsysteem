// Accountbeheer voor de hoofdtrainer: accounts aanmaken, wachtwoord resetten, account aan/uit zetten.
// Draait in Supabase (Edge Function) omdat hiervoor de service-role-sleutel nodig is,
// die nooit in de website mag staan. Elke aanroep controleert eerst of de beller hoofdtrainer is.
import { createClient } from "npm:@supabase/supabase-js@2";

const USERNAME_DOMAIN = "artsvs.nl";
const ALLOWED_ROLES = ["trainer", "scout"];
const WORDS = [
  "bal", "doel", "hoek", "pass", "sprint", "keeper", "veld", "net", "lat", "paal",
  "kopbal", "dribbel", "assist", "corner", "vrije", "schot", "bocht", "flank", "spits", "libero",
];

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}

function randomInt(max: number) {
  const buf = new Uint32Array(1);
  crypto.getRandomValues(buf);
  return buf[0] % max;
}

// Makkelijk over te typen, bv. "Kopbal-Flank-47"
function generatePassword() {
  const cap = (w: string) => w[0].toUpperCase() + w.slice(1);
  return cap(WORDS[randomInt(WORDS.length)]) + "-" + cap(WORDS[randomInt(WORDS.length)]) + "-" + (10 + randomInt(90));
}

function usernameFromEmail(email: string | undefined) {
  if (!email) return "";
  const suffix = "@" + USERNAME_DOMAIN;
  return email.endsWith(suffix) ? email.slice(0, -suffix.length) : email;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Alleen POST" }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Wie roept aan, en is dat de hoofdtrainer?
  const jwt = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  const { data: caller, error: callerErr } = await admin.auth.getUser(jwt);
  if (callerErr || !caller?.user) return json({ error: "Niet ingelogd" }, 401);
  const { data: callerProfile } = await admin.from("profiles").select("role").eq("id", caller.user.id).maybeSingle();
  if (callerProfile?.role !== "hoofdtrainer") return json({ error: "Alleen de hoofdtrainer mag accounts beheren" }, 403);

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ error: "Ongeldig verzoek" }, 400); }
  const action = body.action;

  // Beveiliging: nooit jezelf of een andere hoofdtrainer uitzetten/resetten via deze functie.
  async function assertManageable(id: string) {
    if (id === caller.user.id) throw new Error("Je kunt je eigen account hier niet wijzigen");
    const { data: p } = await admin.from("profiles").select("role").eq("id", id).maybeSingle();
    if (p?.role === "hoofdtrainer") throw new Error("Een hoofdtrainer-account kan hier niet gewijzigd worden");
  }

  try {
    if (action === "list") {
      const { data, error } = await admin.auth.admin.listUsers({ perPage: 1000 });
      if (error) throw error;
      return json({
        users: data.users.map((u) => ({
          id: u.id,
          username: usernameFromEmail(u.email),
          disabled: !!u.banned_until && new Date(u.banned_until) > new Date(),
          last_sign_in_at: u.last_sign_in_at,
        })),
      });
    }

    if (action === "create") {
      const naam = String(body.naam || "").trim();
      const username = String(body.username || "").trim().toLowerCase();
      const role = String(body.role || "");
      if (!naam) return json({ error: "Vul een naam in" }, 400);
      if (!/^[a-z0-9._-]{2,30}$/.test(username)) {
        return json({ error: "Gebruikersnaam: 2-30 tekens, alleen letters, cijfers, punt, streepje" }, 400);
      }
      if (!ALLOWED_ROLES.includes(role)) return json({ error: "Rol moet trainer of scout zijn" }, 400);

      const password = generatePassword();
      const { data, error } = await admin.auth.admin.createUser({
        email: `${username}@${USERNAME_DOMAIN}`,
        password,
        email_confirm: true,
        user_metadata: { naam },
      });
      if (error) {
        if (/already|exists|registered/i.test(error.message)) return json({ error: "Deze gebruikersnaam bestaat al" }, 409);
        throw error;
      }
      const { error: profErr } = await admin.from("profiles").insert({ id: data.user.id, naam, role });
      if (profErr) {
        await admin.auth.admin.deleteUser(data.user.id);
        throw profErr;
      }
      return json({ id: data.user.id, username, password });
    }

    if (action === "reset_password") {
      const id = String(body.id || "");
      await assertManageable(id);
      const password = generatePassword();
      const { data, error } = await admin.auth.admin.updateUserById(id, { password });
      if (error) throw error;
      return json({ username: usernameFromEmail(data.user.email), password });
    }

    if (action === "set_disabled") {
      const id = String(body.id || "");
      await assertManageable(id);
      const disabled = !!body.disabled;
      const { error } = await admin.auth.admin.updateUserById(id, { ban_duration: disabled ? "876000h" : "none" });
      if (error) throw error;
      return json({ id, disabled });
    }

    return json({ error: "Onbekende actie" }, 400);
  } catch (e) {
    return json({ error: (e as Error).message || "Er ging iets mis" }, 400);
  }
});
