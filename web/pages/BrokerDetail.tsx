import { ArrowLeft, ExternalLink, History, Info, ListChecks, Search, ShieldAlert, type LucideIcon } from "lucide-react";
import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import type { BrokerRow } from "../../shared/merge";
import type { HistoryEntry, Profile, RecordPatch, Status } from "../../shared/types";
import { api } from "../api";
import { LoadFailed } from "../components/LoadFailed";
import { RequestPanel } from "../components/RequestPanel";
import { METHOD_ICON, StatusPill } from "../components/StatusPill";
import { useReportError } from "../errors";
import { formatDate, relativeDays } from "../format";
import { METHOD_LABEL, STATUS_HELP, STATUS_LABEL } from "../labels";

const STATUSES: Status[] = ["found", "request_sent", "removed", "relisted"];

const historyLabel = (s: HistoryEntry["status"]) => (s === "rechecked" ? "Rechecked — still removed" : STATUS_LABEL[s]);

const RISK_LABEL = { low: "Rarely re-lists", medium: "Sometimes re-lists", high: "Often re-lists" };

function CardHead({ icon: Icon, id, children }: { icon: LucideIcon; id?: string; children: string }) {
  return (
    <div className="card-head">
      <Icon size={20} aria-hidden="true" />
      <h2 id={id}>{children}</h2>
    </div>
  );
}

export default function BrokerDetail() {
  const { id } = useParams();
  const report = useReportError();
  const [row, setRow] = useState<BrokerRow | null | undefined>(undefined);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [today, setToday] = useState("");
  const [notes, setNotes] = useState("");
  const [listingUrl, setListingUrl] = useState("");
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    Promise.all([api.getBrokers(), api.getProfile()])
      .then(([b, p]) => {
        const found = b.rows.find((r) => r.broker.id === id) ?? null;
        setRow(found);
        setToday(b.today);
        setNotes(found?.record?.notes ?? "");
        setListingUrl(found?.record?.listingUrl ?? "");
        setProfile(p);
      })
      .catch((e) => {
        setFailed(true);
        report(e);
      });
  }, [id, report]);

  if (row === undefined) return failed ? <LoadFailed /> : <p className="muted">Loading…</p>;
  if (row === null) {
    return (
      <section className="card">
        <h1>Broker not found</h1>
        <p className="muted">This broker isn't in Unlist's list.</p>
        <Link to="/">Back to dashboard</Link>
      </section>
    );
  }

  const { broker, record } = row;
  const MethodIcon = METHOD_ICON[broker.method];

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
    record?.requestSentAt && (["Request sent", record.requestSentAt] as const),
    // An earlier removal stays in History; here it would read as current.
    record?.status === "removed" && record.removedAt && (["Removed", record.removedAt] as const),
    record?.recheckAt && (["Recheck", record.recheckAt] as const),
  ].filter(Boolean) as (readonly [string, string])[];

  return (
    <>
      <Link to="/" className="back">
        <ArrowLeft size={18} aria-hidden="true" />
        All brokers
      </Link>

      <section className="card broker-head">
        <div className="title-row">
          <h1>{broker.name}</h1>
          <StatusPill status={row.view} />
        </div>
        <div className="meta">
          <span>
            <MethodIcon size={16} aria-hidden="true" />
            Removal by {METHOD_LABEL[broker.method].toLowerCase()}
          </span>
          <span>
            <History size={16} aria-hidden="true" />
            {RISK_LABEL[broker.relistRisk]}
          </span>
          <span>
            <ShieldAlert size={16} aria-hidden="true" />
            {broker.lastVerified ? `Info checked ${formatDate(broker.lastVerified)}` : "Opt-out info not yet verified"}
          </span>
        </div>
        {badges.length > 0 && (
          <div className="row" style={{ marginBottom: "1.1rem" }}>
            <span className="muted small">This site asks for:</span>
            {badges.map((b) => (
              <span key={b} className="badge">
                {b}
              </span>
            ))}
          </div>
        )}
        <div className="row">
          <a className="button" href={broker.searchUrl} target="_blank" rel="noreferrer">
            <Search size={16} aria-hidden="true" />
            Open search page
          </a>
          <a className="button primary" href={broker.optOutUrl} target="_blank" rel="noreferrer">
            <ExternalLink size={16} aria-hidden="true" />
            Open opt-out page
          </a>
        </div>
      </section>

      <div className="detail-grid">
        <div>
          <section className="card">
            <CardHead icon={ListChecks}>Your progress</CardHead>
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
              <p className="status-help">
                <Info size={16} aria-hidden="true" />
                <span>{STATUS_HELP[row.view]}</span>
              </p>
            </div>
            {dates.length > 0 && (
              <ul className="dates" aria-label="Dates">
                {dates.map(([label, iso]) => (
                  <li key={label}>
                    <span>{label}</span>
                    <span className="num">
                      {formatDate(iso)}
                      {today && <span className="muted"> · {relativeDays(iso, today)}</span>}
                    </span>
                  </li>
                ))}
              </ul>
            )}
            <div className="field">
              <label htmlFor="d-url">Listing URL</label>
              <input
                id="d-url"
                type="url"
                inputMode="url"
                value={listingUrl}
                placeholder="https://…"
                onChange={(e) => setListingUrl(e.target.value)}
                onBlur={() => listingUrl !== (record?.listingUrl ?? "") && save({ listingUrl })}
              />
              <p className="help">Paste the address of the page that shows your information.</p>
            </div>
            <div className="field">
              <label htmlFor="d-notes">Notes</label>
              <textarea
                id="d-notes"
                value={notes}
                placeholder="e.g. Called on Oct 3, they said 7 days"
                onChange={(e) => setNotes(e.target.value)}
                onBlur={() => notes !== (record?.notes ?? "") && save({ notes })}
              />
              <p className="help">Saved automatically when you leave the field.</p>
            </div>
          </section>

          {record && record.history.length > 0 && (
            <section className="card">
              <CardHead icon={History} id="history-heading">
                History
              </CardHead>
              <ul className="history" aria-labelledby="history-heading">
                {[...record.history].reverse().map((h, i) => (
                  <li key={i}>
                    <time dateTime={h.at}>{formatDate(h.at)}</time>
                    <span>{historyLabel(h.status)}</span>
                  </li>
                ))}
              </ul>
            </section>
          )}
        </div>

        <div>
          <section className="card">
            <CardHead icon={ListChecks}>How to opt out</CardHead>
            <ol className="steps" aria-label="Opt-out steps">
              {broker.steps.map((s, i) => (
                <li key={i}>
                  <span>{s}</span>
                </li>
              ))}
            </ol>
          </section>
          {profile && <RequestPanel broker={broker} profile={profile} listingUrl={listingUrl} />}
        </div>
      </div>
    </>
  );
}
