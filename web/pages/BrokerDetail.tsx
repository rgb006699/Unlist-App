import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import type { BrokerRow } from "../../shared/merge";
import type { HistoryEntry, Profile, RecordPatch, Status } from "../../shared/types";
import { api } from "../api";
import { RequestPanel } from "../components/RequestPanel";
import { useReportError } from "../errors";
import { METHOD_LABEL, STATUS_LABEL } from "../labels";

const STATUSES: Status[] = ["found", "request_sent", "removed", "relisted"];

const historyLabel = (s: HistoryEntry["status"]) => (s === "rechecked" ? "Rechecked — still removed" : STATUS_LABEL[s]);

export default function BrokerDetail() {
  const { id } = useParams();
  const report = useReportError();
  const [row, setRow] = useState<BrokerRow | null | undefined>(undefined);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [notes, setNotes] = useState("");
  const [listingUrl, setListingUrl] = useState("");

  useEffect(() => {
    Promise.all([api.getBrokers(), api.getProfile()])
      .then(([b, p]) => {
        const found = b.rows.find((r) => r.broker.id === id) ?? null;
        setRow(found);
        setNotes(found?.record?.notes ?? "");
        setListingUrl(found?.record?.listingUrl ?? "");
        setProfile(p);
      })
      .catch(report);
  }, [id, report]);

  if (row === undefined) return <p className="muted">Loading…</p>;
  if (row === null) {
    return (
      <section className="card">
        <h1>Broker not found</h1>
        <Link to="/">Back to dashboard</Link>
      </section>
    );
  }

  const { broker, record } = row;

  const save = async (patch: RecordPatch) => {
    try {
      setRow(await api.patchBroker(broker.id, patch));
    } catch (e) {
      report(e);
    }
  };

  const badges = [
    broker.needsCaptcha && "CAPTCHA",
    broker.needsEmailConfirm && "Email confirmation",
    broker.needsId && "ID required",
  ].filter(Boolean) as string[];

  const dates = [
    record?.requestSentAt && `Request sent ${record.requestSentAt}`,
    record?.removedAt && `Removed ${record.removedAt}`,
    record?.recheckAt && `Recheck ${record.recheckAt}`,
  ].filter(Boolean) as string[];

  return (
    <>
      <p>
        <Link to="/">← All brokers</Link>
      </p>
      <section className="card">
        <div className="row" style={{ justifyContent: "space-between" }}>
          <h1>{broker.name}</h1>
          <span className={`pill pill-${row.view}`}>{STATUS_LABEL[row.view]}</span>
        </div>
        <p className="muted" style={{ marginTop: 0 }}>
          Removal by {METHOD_LABEL[broker.method].toLowerCase()} · re-list risk {broker.relistRisk}
          {broker.lastVerified ? ` · info checked ${broker.lastVerified}` : " · opt-out info not yet verified"}
        </p>
        {badges.length > 0 && (
          <div className="row" style={{ marginBottom: "1rem" }}>
            {badges.map((b) => (
              <span key={b} className="badge">
                {b}
              </span>
            ))}
          </div>
        )}
        <div className="row">
          <a className="button" href={broker.searchUrl} target="_blank" rel="noreferrer">
            Open search page
          </a>
          <a className="button primary" href={broker.optOutUrl} target="_blank" rel="noreferrer">
            Open opt-out page
          </a>
        </div>
      </section>

      <div className="detail-grid">
        <div>
          <section className="card">
            <h2>How to opt out</h2>
            <ol className="steps" aria-label="Opt-out steps">
              {broker.steps.map((s, i) => (
                <li key={i}>{s}</li>
              ))}
            </ol>
          </section>
          {profile && <RequestPanel broker={broker} profile={profile} listingUrl={listingUrl} />}
        </div>

        <div>
          <section className="card">
            <h2>Your progress</h2>
            <div className="field">
              <label htmlFor="d-status">Status</label>
              <select
                id="d-status"
                value={record?.status ?? ""}
                onChange={(e) => save({ status: e.target.value as Status })}
              >
                {!record && (
                  <option value="" disabled>
                    Not checked
                  </option>
                )}
                {STATUSES.map((s) => (
                  <option key={s} value={s}>
                    {STATUS_LABEL[s]}
                  </option>
                ))}
              </select>
            </div>
            {dates.length > 0 && (
              <ul className="history" style={{ marginBottom: "0.9rem" }}>
                {dates.map((d) => (
                  <li key={d}>{d}</li>
                ))}
              </ul>
            )}
            <div className="field">
              <label htmlFor="d-url">Listing URL</label>
              <input
                id="d-url"
                type="url"
                value={listingUrl}
                placeholder="Paste the page that shows you"
                onChange={(e) => setListingUrl(e.target.value)}
                onBlur={() => listingUrl !== (record?.listingUrl ?? "") && save({ listingUrl })}
              />
            </div>
            <div className="field">
              <label htmlFor="d-notes">Notes</label>
              <textarea
                id="d-notes"
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                onBlur={() => notes !== (record?.notes ?? "") && save({ notes })}
              />
            </div>
          </section>

          {record && record.history.length > 0 && (
            <section className="card">
              <h2 id="history-heading">History</h2>
              <ul className="history" aria-labelledby="history-heading">
                {[...record.history].reverse().map((h, i) => (
                  <li key={i}>
                    <time>{h.at}</time>
                    <span>{historyLabel(h.status)}</span>
                  </li>
                ))}
              </ul>
            </section>
          )}
        </div>
      </div>
    </>
  );
}
