import { useEffect, useState } from "react";
import type { Address, Profile as ProfileT } from "../../shared/types";
import { api, ApiError } from "../api";
import { useReportError } from "../errors";

const newAddress = (): Address => ({ street: "", city: "", state: "TX", zip: "", current: false });

function clean(p: ProfileT): ProfileT {
  const list = (xs: string[]) => xs.map((x) => x.trim()).filter(Boolean);
  return {
    fullName: p.fullName.trim(),
    aliases: list(p.aliases),
    phones: list(p.phones),
    emails: list(p.emails),
    addresses: p.addresses
      .map((a) => ({ ...a, street: a.street.trim(), city: a.city.trim(), state: a.state.trim(), zip: a.zip.trim() }))
      .filter((a) => a.street || a.city || a.zip),
  };
}

function ListField({
  title,
  item,
  values,
  type = "text",
  onChange,
}: {
  title: string;
  item: string;
  values: string[];
  type?: string;
  onChange(v: string[]): void;
}) {
  return (
    <div className="list-field">
      <h2>{title}</h2>
      {values.map((v, i) => (
        <div className="row" key={i}>
          <input
            type={type}
            aria-label={`${item} ${i + 1}`}
            value={v}
            onChange={(e) => onChange(values.map((x, j) => (j === i ? e.target.value : x)))}
          />
          <button
            type="button"
            aria-label={`Remove ${item.toLowerCase()} ${i + 1}`}
            onClick={() => onChange(values.filter((_, j) => j !== i))}
          >
            Remove
          </button>
        </div>
      ))}
      <button type="button" onClick={() => onChange([...values, ""])}>
        Add {item.toLowerCase()}
      </button>
    </div>
  );
}

export default function Profile() {
  const report = useReportError();
  const [profile, setProfile] = useState<ProfileT | null>(null);
  const [state, setState] = useState<{ kind: "idle" | "saving" | "saved" } | { kind: "error"; message: string }>({
    kind: "idle",
  });

  useEffect(() => {
    api.getProfile().then(setProfile).catch(report);
  }, [report]);

  if (!profile) return <p className="muted">Loading…</p>;

  const set = (patch: Partial<ProfileT>) => {
    setProfile({ ...profile, ...patch });
    setState({ kind: "idle" });
  };
  const setAddress = (i: number, patch: Partial<Address>) =>
    set({ addresses: profile.addresses.map((a, j) => (j === i ? { ...a, ...patch } : a)) });

  const save = async (e: React.FormEvent) => {
    e.preventDefault();
    setState({ kind: "saving" });
    try {
      const saved = await api.saveProfile(clean(profile));
      setProfile(saved);
      setState({ kind: "saved" });
    } catch (err) {
      if (err instanceof ApiError && (err.code === "UNREACHABLE" || err.code === "DATA_CORRUPT")) report(err);
      setState({ kind: "error", message: err instanceof Error ? err.message : String(err) });
    }
  };

  return (
    <form onSubmit={save}>
      <section className="card">
        <h1>Your details</h1>
        <p className="muted">
          Unlist fills your removal requests with these details. They stay in a file on this computer.
        </p>
        <div className="field" style={{ maxWidth: "28rem" }}>
          <label htmlFor="p-name">Full name</label>
          <input id="p-name" type="text" value={profile.fullName} onChange={(e) => set({ fullName: e.target.value })} />
        </div>
        <ListField title="Other names" item="Other name" values={profile.aliases} onChange={(aliases) => set({ aliases })} />
      </section>

      <section className="card">
        <h2>Addresses</h2>
        <p className="muted" style={{ marginTop: 0 }}>
          Add past addresses too. Brokers often list old ones.
        </p>
        {profile.addresses.map((a, i) => (
          <fieldset key={i} className="address-row" style={{ border: 0, padding: 0, margin: "0 0 0.4rem" }}>
            <legend className="muted" style={{ position: "absolute", left: "-9999px" }}>
              Address {i + 1}
            </legend>
            <label style={{ display: "flex", gap: "0.3rem", margin: 0, alignItems: "center" }}>
              <input
                type="radio"
                name="current-address"
                checked={a.current}
                onChange={() => set({ addresses: profile.addresses.map((x, j) => ({ ...x, current: j === i })) })}
              />
              Current
            </label>
            <input aria-label="Street" placeholder="Street" value={a.street} onChange={(e) => setAddress(i, { street: e.target.value })} />
            <input aria-label="City" placeholder="City" value={a.city} onChange={(e) => setAddress(i, { city: e.target.value })} />
            <input aria-label="State" placeholder="State" value={a.state} onChange={(e) => setAddress(i, { state: e.target.value })} />
            <input aria-label="ZIP" placeholder="ZIP" value={a.zip} onChange={(e) => setAddress(i, { zip: e.target.value })} />
            <button
              type="button"
              aria-label={`Remove address ${i + 1}`}
              onClick={() => set({ addresses: profile.addresses.filter((_, j) => j !== i) })}
            >
              Remove
            </button>
          </fieldset>
        ))}
        <button type="button" onClick={() => set({ addresses: [...profile.addresses, newAddress()] })}>
          Add address
        </button>
      </section>

      <section className="card">
        <ListField title="Phone numbers" item="Phone" type="tel" values={profile.phones} onChange={(phones) => set({ phones })} />
        <ListField title="Email addresses" item="Email" type="email" values={profile.emails} onChange={(emails) => set({ emails })} />
      </section>

      <div className="row">
        <button type="submit" className="primary" disabled={state.kind === "saving"}>
          Save
        </button>
        {state.kind === "saved" && <span className="status-text">Saved</span>}
        {state.kind === "error" && (
          <span className="status-text error" role="alert">
            {state.message}
          </span>
        )}
      </div>
    </form>
  );
}
