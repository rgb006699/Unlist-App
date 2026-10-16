import { Circle, CircleCheck, Clock, ExternalLink, Search, Send, TriangleAlert, type LucideIcon } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import type { BrokerRow } from "../../shared/merge";
import { progress } from "../../shared/status";
import type { Method, RecordPatch, ViewStatus } from "../../shared/types";
import { api } from "../api";
import { LoadFailed } from "../components/LoadFailed";
import { MethodTag, StatusPill } from "../components/StatusPill";
import { useReportError } from "../errors";
import { formatDate, relativeDays } from "../format";
import { METHOD_LABEL, nextStep, STATUS_LABEL } from "../labels";

type Group = "removed" | "progress" | "due" | "not_checked";

// Summary tiles; each one filters the list to its statuses.
const TILES: { group: Group; label: string; icon: LucideIcon; statuses: ViewStatus[]; count: keyof ReturnType<typeof progress> }[] = [
  { group: "removed", label: "Removed", icon: CircleCheck, statuses: ["removed"], count: "removed" },
  { group: "progress", label: "In progress", icon: Send, statuses: ["found", "request_sent", "relisted"], count: "pending" },
  { group: "due", label: "Need recheck", icon: Clock, statuses: ["due"], count: "due" },
  { group: "not_checked", label: "Not checked yet", icon: Circle, statuses: ["not_checked"], count: "notChecked" },
];

const METER: { key: "removed" | "pending" | "due"; color: string }[] = [
  { key: "removed", color: "var(--st-removed)" },
  { key: "due", color: "var(--st-due)" },
  { key: "pending", color: "var(--st-request_sent)" },
];

export default function Dashboard() {
  const report = useReportError();
  const navigate = useNavigate();
  const [rows, setRows] = useState<BrokerRow[] | null>(null);
  const [today, setToday] = useState("");
  const [group, setGroup] = useState<Group | "">("");
  const [status, setStatus] = useState<ViewStatus | "">("");
  const [method, setMethod] = useState<Method | "">("");
  const [query, setQuery] = useState("");
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    api
      .getBrokers()
      .then((r) => {
        setRows(r.rows);
        setToday(r.today);
      })
      .catch((e) => {
        setFailed(true);
        report(e);
      });
  }, [report]);

  const counts = useMemo(() => progress((rows ?? []).map((r) => r.view)), [rows]);

  const visible = useMemo(() => {
    const q = query.trim().toLowerCase();
    const groupStatuses = TILES.find((t) => t.group === group)?.statuses;
    return (rows ?? []).filter(
      (r) =>
        (!groupStatuses || groupStatuses.includes(r.view)) &&
        (!status || r.view === status) &&
        (!method || r.broker.method === method) &&
        (!q || r.broker.name.toLowerCase().includes(q)),
    );
  }, [rows, group, status, method, query]);

  const patch = async (id: string, body: RecordPatch) => {
    try {
      const updated = await api.patchBroker(id, body);
      setRows((rs) => rs && rs.map((r) => (r.broker.id === id ? updated : r)));
    } catch (e) {
      report(e);
    }
  };

  if (!rows) return failed ? <LoadFailed /> : <p className="muted">Loading…</p>;

  const due = rows.filter((r) => r.view === "due");
  const nothingStarted = counts.total > 0 && counts.notChecked === counts.total;

  return (
    <>
      <section className="card summary">
        <div>
          <h1>Your removals</h1>
          <p className="headline">
            <strong className="num">
              {counts.removed} of {counts.total}
            </strong>{" "}
            sites have removed you
          </p>
        </div>
        {counts.total > 0 && (
          <div className="meter" aria-hidden="true">
            {METER.map(({ key, color }) =>
              counts[key] ? <span key={key} style={{ flex: counts[key], background: color }} /> : null,
            )}
            {counts.notChecked ? <span style={{ flex: counts.notChecked }} /> : null}
          </div>
        )}
        <div className="tiles" role="group" aria-label="Filter by progress">
          {TILES.map(({ group: g, label, icon: Icon, count }) => (
            <button
              key={g}
              type="button"
              className={`tile tile-${g}`}
              aria-pressed={group === g}
              onClick={() => {
                setGroup(group === g ? "" : g);
                setStatus("");
              }}
            >
              <Icon size={22} aria-hidden="true" />
              <span className="count">{counts[count]}</span>
              <span className="what">{label}</span>
            </button>
          ))}
        </div>
      </section>

      {nothingStarted && (
        <section className="card how-to" aria-labelledby="how-heading">
          <h2 id="how-heading">How Unlist works</h2>
          <ol>
            <li>
              <strong>Search each site</strong>
              Open a broker below and look yourself up on their site.
            </li>
            <li>
              <strong>Ask for removal</strong>
              Follow the steps, or send the request Unlist writes for you.
            </li>
            <li>
              <strong>Check back</strong>
              Unlist reminds you after 90 days in case your listing returns.
            </li>
          </ol>
        </section>
      )}

      {due.length > 0 && (
        <section className="card due-panel" aria-labelledby="due-heading">
          <div className="card-head">
            <TriangleAlert size={20} aria-hidden="true" />
            <h2 id="due-heading">Due for recheck</h2>
          </div>
          <p className="muted small">Search these sites again to make sure your listing hasn't come back.</p>
          <ul>
            {due.map((r) => (
              <li key={r.broker.id}>
                <span className="name">
                  <Link to={`/broker/${r.broker.id}`}>{r.broker.name}</Link>
                  {r.record?.removedAt && (
                    <span className="muted">
                      Removed {formatDate(r.record.removedAt)}
                      {today && ` · ${relativeDays(r.record.removedAt, today)}`}
                    </span>
                  )}
                </span>
                <a className="button" href={r.broker.searchUrl} target="_blank" rel="noreferrer">
                  <ExternalLink size={16} aria-hidden="true" />
                  Search again
                </a>
                <button type="button" className="primary" onClick={() => patch(r.broker.id, { recheck: true })}>
                  <CircleCheck size={16} aria-hidden="true" />
                  Still removed
                </button>
                <button type="button" onClick={() => patch(r.broker.id, { status: "relisted" })}>
                  Re-listed
                </button>
              </li>
            ))}
          </ul>
        </section>
      )}

      <div className="toolbar">
        <div className="search-field">
          <label htmlFor="f-search">Search</label>
          <Search size={18} aria-hidden="true" />
          <input
            id="f-search"
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Find a broker by name"
          />
        </div>
        <div>
          <label htmlFor="f-status">Status</label>
          <select
            id="f-status"
            value={status}
            onChange={(e) => {
              setStatus(e.target.value as ViewStatus | "");
              setGroup("");
            }}
          >
            <option value="">All statuses</option>
            {Object.entries(STATUS_LABEL).map(([v, l]) => (
              <option key={v} value={v}>
                {l}
              </option>
            ))}
          </select>
        </div>
        <div>
          <label htmlFor="f-method">Method</label>
          <select id="f-method" value={method} onChange={(e) => setMethod(e.target.value as Method | "")}>
            <option value="">All methods</option>
            {Object.entries(METHOD_LABEL).map(([v, l]) => (
              <option key={v} value={v}>
                {l}
              </option>
            ))}
          </select>
        </div>
      </div>

      <table className="brokers">
        <thead>
          <tr>
            <th>Broker</th>
            <th>Status</th>
            <th>Next step</th>
          </tr>
        </thead>
        <tbody>
          {visible.map((r) => (
            <tr key={r.broker.id} onClick={() => navigate(`/broker/${r.broker.id}`)}>
              <td>
                <Link className="broker-name" to={`/broker/${r.broker.id}`} onClick={(e) => e.stopPropagation()}>
                  {r.broker.name}
                </Link>
                <MethodTag method={r.broker.method} />
              </td>
              <td>
                <StatusPill status={r.view} />
              </td>
              <td className="next-step">{nextStep(r)}</td>
            </tr>
          ))}
        </tbody>
      </table>
      {visible.length === 0 && <p className="empty">No brokers match these filters.</p>}
    </>
  );
}
