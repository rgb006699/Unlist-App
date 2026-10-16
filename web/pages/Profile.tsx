import { CircleAlert, CircleCheck, Lock, Plus, Save, Trash2 } from "lucide-react";
import { useEffect, useState } from "react";
import type { Address, Profile as ProfileT } from "../../shared/types";
import { api, ApiError } from "../api";
import { LoadFailed } from "../components/LoadFailed";
import { useReportError } from "../errors";
import { useUnsavedChanges } from "../unsaved";

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
  help,
  item,
  values,
  type = "text",
  onChange,
}: {
  title: string;
  help?: string;
  item: string;
  values: string[];
  type?: string;
  onChange(v: string[]): void;
}) {
  return (
    <div className="list-field">
      <span className="label">{title}</span>
      {help && <p className="help" style={{ margin: "-0.2rem 0 0.6rem" }}>{help}</p>}
      {values.map((v, i) => (
        <div className="list-row" key={i}>
          <input
            type={type}
            aria-label={`${item} ${i + 1}`}
            value={v}
            onChange={(e) => onChange(values.map((x, j) => (j === i ? e.target.value : x)))}
          />
          <button
            type="button"
            className="ghost icon-only"
            aria-label={`Remove ${item.toLowerCase()} ${i + 1}`}
            title="Remove"
            onClick={() => onChange(values.filter((_, j) => j !== i))}
          >
            <Trash2 size={18} aria-hidden="true" />
          </button>
        </div>
      ))}
      <button type="button" className="add" onClick={() => onChange([...values, ""])}>
        <Plus size={16} aria-hidden="true" />
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

  const [failed, setFailed] = useState(false);
  const [saved, setSaved] = useState<ProfileT | null>(null);
  const dirty = profile !== null && JSON.stringify(profile) !== JSON.stringify(saved);
  useUnsavedChanges(dirty);

  useEffect(() => {
    api
      .getProfile()
      .then((p) => {
        setProfile(p);
        setSaved(p);
      })
      .catch((e) => {
        setFailed(true);
        report(e);
      });
  }, [report]);

  if (!profile) return failed ? <LoadFailed /> : <p className="muted">Loading…</p>;

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
      const result = await api.saveProfile(clean(profile));
      setProfile(result);
      setSaved(result);
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
        <p className="intro muted">
          <Lock size={18} aria-hidden="true" />
          <span>
            Unlist uses these details to fill in your removal requests. They're saved only in a file on this computer.
          </span>
        </p>
        <div className="field" style={{ maxWidth: "30rem" }}>
          <label htmlFor="p-name">Full name</label>
          <input
            id="p-name"
            type="text"
            autoComplete="name"
            value={profile.fullName}
            onChange={(e) => set({ fullName: e.target.value })}
          />
          <p className="help">Your legal name, the way people-search sites would show it.</p>
        </div>
        <ListField
          title="Other names"
          help="Maiden names, nicknames or other spellings sites might use."
          item="Other name"
          values={profile.aliases}
          onChange={(aliases) => set({ aliases })}
        />
      </section>

      <section className="card">
        <h2>Addresses</h2>
        <p className="help" style={{ margin: "-0.4rem 0 1rem" }}>
          Add past addresses too — brokers often list old ones. Mark the one you live at now as current.
        </p>
        {profile.addresses.map((a, i) => (
          <fieldset key={i} className="address-row">
            <legend className="visually-hidden">Address {i + 1}</legend>
            <label className="addr-current">
              <input
                type="radio"
                name="current-address"
                checked={a.current}
                onChange={() => set({ addresses: profile.addresses.map((x, j) => ({ ...x, current: j === i })) })}
              />
              Current
            </label>
            <button
              className="addr-remove ghost icon-only"
              type="button"
              aria-label={`Remove address ${i + 1}`}
              title="Remove address"
              onClick={() => set({ addresses: profile.addresses.filter((_, j) => j !== i) })}
            >
              <Trash2 size={18} aria-hidden="true" />
            </button>
            <div className="field addr-street">
              <label htmlFor={`a${i}-street`}>Street</label>
              <input id={`a${i}-street`} autoComplete="address-line1" value={a.street} onChange={(e) => setAddress(i, { street: e.target.value })} />
            </div>
            <div className="field addr-city">
              <label htmlFor={`a${i}-city`}>City</label>
              <input id={`a${i}-city`} autoComplete="address-level2" value={a.city} onChange={(e) => setAddress(i, { city: e.target.value })} />
            </div>
            <div className="field addr-state">
              <label htmlFor={`a${i}-state`}>State</label>
              <input id={`a${i}-state`} autoComplete="address-level1" value={a.state} onChange={(e) => setAddress(i, { state: e.target.value })} />
            </div>
            <div className="field addr-zip">
              <label htmlFor={`a${i}-zip`}>ZIP</label>
              <input
                id={`a${i}-zip`}
                inputMode="numeric"
                autoComplete="postal-code"
                value={a.zip}
                onChange={(e) => setAddress(i, { zip: e.target.value })}
              />
            </div>
          </fieldset>
        ))}
        <button type="button" className="add" onClick={() => set({ addresses: [...profile.addresses, newAddress()] })}>
          <Plus size={16} aria-hidden="true" />
          Add address
        </button>
      </section>

      <section className="card">
        <h2>Contact details</h2>
        <p className="help" style={{ margin: "-0.4rem 0 0" }}>
          People-search sites often show these too, and removal requests use them to find your records.
        </p>
        <ListField title="Phone numbers" item="Phone" type="tel" values={profile.phones} onChange={(phones) => set({ phones })} />
        <ListField title="Email addresses" item="Email" type="email" values={profile.emails} onChange={(emails) => set({ emails })} />
      </section>

      <div className="savebar">
        <span
          className={`state ${state.kind === "error" ? "error" : state.kind === "saved" && !dirty ? "ok" : dirty ? "dirty" : ""}`}
          role={state.kind === "error" ? "alert" : "status"}
        >
          {state.kind === "error" ? (
            <>
              <CircleAlert size={16} aria-hidden="true" />
              {state.message}
            </>
          ) : state.kind === "saved" && !dirty ? (
            <>
              <CircleCheck size={16} aria-hidden="true" />
              Saved
            </>
          ) : dirty ? (
            "Unsaved changes"
          ) : (
            "No unsaved changes"
          )}
        </span>
        <button type="submit" className="primary" disabled={state.kind === "saving"}>
          <Save size={16} aria-hidden="true" />
          Save
        </button>
      </div>
    </form>
  );
}
