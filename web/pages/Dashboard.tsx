import { useEffect, useMemo, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import type { BrokerRow } from "../../shared/merge";
import { progress } from "../../shared/status";
import type { Method, RecordPatch, ViewStatus } from "../../shared/types";
import { api } from "../api";
import { LoadFailed } from "../components/LoadFailed";
import { useReportError } from "../errors";
import { METHOD_LABEL, nextDateLabel, STATUS_LABEL } from "../labels";

const METER: { key: "removed" | "pending" | "due" | "notChecked"; color: string }[] = [
  { key: "removed", color: "var(--st-removed)" },
  { key: "due", color: "var(--st-due)" },
  { key: "pending", color: "var(--st-request)" },
];

export default function Dashboard() {
  const report = useReportError();
  const navigate = useNavigate();
  const [rows, setRows] = useState<BrokerRow[] | null>(null);
  const [status, setStatus] = useState<ViewStatus | "">("");
  const [method, setMethod] = useState<Method | "">("");
  const [query, setQuery] = useState("");
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    api
      .getBrokers()
      .then((r) => setRows(r.rows))
      .catch((e) => {
        setFailed(true);
        report(e);
      });
  }, [report]);

  const counts = useMemo(() => progress((rows ?? []).map((r) => r.view)), [rows]);

  const visible = useMemo(() => {
    const q = query.trim().toLowerCase();
    return (rows ?? []).filter(
      (r) =>
        (!status || r.view === status) &&
        (!method || r.broker.method === method) &&
        (!q || r.broker.name.toLowerCase().includes(q)),
    );
  }, [rows, status, method, query]);

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

  return (
    <>
      <section className="card">
        <h1>Your removals</h1>
        <p className="progress-line">
          {counts.removed} of {counts.total} removed · {counts.pending} pending · {counts.due} need recheck
        </p>
        {counts.total > 0 && (
          <div className="meter" aria-hidden="true">
            {METER.map(({ key, color }) =>
              counts[key] ? <span key={key} style={{ flex: counts[key], background: color }} /> : null,
            )}
            {counts.notChecked ? <span style={{ flex: counts.notChecked }} /> : null}
          </div>
        )}
      </section>

      {due.length > 0 && (
        <section className="card due-panel" aria-labelledby="due-heading">
          <h2 id="due-heading">Due for recheck</h2>
          <ul>
            {due.map((r) => (
              <li key={r.broker.id}>
                <span className="name">
                  <Link to={`/broker/${r.broker.id}`}>{r.broker.name}</Link>{" "}
                  <span className="muted">removed {r.record?.removedAt}</span>
                </span>
                <a className="button" href={r.broker.searchUrl} target="_blank" rel="noreferrer">
                  Search again
                </a>
                <button type="button" onClick={() => patch(r.broker.id, { recheck: true })}>
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

      <div className="row filters">
        <div>
          <label htmlFor="f-status">Status</label>
          <select id="f-status" value={status} onChange={(e) => setStatus(e.target.value as ViewStatus | "")}>
            <option value="">All</option>
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
            <option value="">All</option>
            {Object.entries(METHOD_LABEL).map(([v, l]) => (
              <option key={v} value={v}>
                {l}
              </option>
            ))}
          </select>
        </div>
        <div>
          <label htmlFor="f-search">Search</label>
          <input id="f-search" type="search" value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Broker name" />
        </div>
      </div>

      <table className="brokers">
        <thead>
          <tr>
            <th>Name</th>
            <th>Method</th>
            <th>Status</th>
            <th>Next date</th>
          </tr>
        </thead>
        <tbody>
          {visible.map((r) => (
            <tr key={r.broker.id} onClick={() => navigate(`/broker/${r.broker.id}`)}>
              <td>
                <Link to={`/broker/${r.broker.id}`} onClick={(e) => e.stopPropagation()}>
                  {r.broker.name}
                </Link>
              </td>
              <td>{METHOD_LABEL[r.broker.method]}</td>
              <td>
                <span className={`pill pill-${r.view}`}>{STATUS_LABEL[r.view]}</span>
              </td>
              <td>{nextDateLabel(r)}</td>
            </tr>
          ))}
        </tbody>
      </table>
      {visible.length === 0 && <p className="empty">No brokers match these filters.</p>}
    </>
  );
}
