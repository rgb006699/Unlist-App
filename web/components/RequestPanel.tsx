import { useState } from "react";
import { fillTemplate, mailtoLink, type TemplateId } from "../../shared/templates";
import type { Broker, Profile } from "../../shared/types";

const TEMPLATES: { id: TemplateId; label: string }[] = [
  { id: "tdpsa", label: "Texas (TDPSA)" },
  { id: "general", label: "General" },
];

export function RequestPanel({ broker, profile, listingUrl }: { broker: Broker; profile: Profile; listingUrl: string }) {
  const [template, setTemplate] = useState<TemplateId>("tdpsa");
  const [copied, setCopied] = useState<"idle" | "copied" | "failed">("idle");
  const { subject, body } = fillTemplate(template, profile, broker, listingUrl);

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(`${subject}\n\n${body}`);
      setCopied("copied");
    } catch {
      setCopied("failed");
    }
  };

  return (
    <section className="card" aria-labelledby="request-heading">
      <h2 id="request-heading">Removal request</h2>
      <div className="segmented" role="group" aria-label="Template">
        {TEMPLATES.map((t) => (
          <button
            key={t.id}
            type="button"
            aria-pressed={template === t.id}
            onClick={() => {
              setTemplate(t.id);
              setCopied("idle");
            }}
          >
            {t.label}
          </button>
        ))}
      </div>
      <p className="muted" style={{ margin: "0.75rem 0 0" }}>
        <strong>Subject:</strong> {subject}
      </p>
      <pre className="preview">{body}</pre>
      <div className="row">
        <button type="button" className="primary" onClick={copy}>
          Copy
        </button>
        <a className="button" href={mailtoLink(broker.optOutEmail, subject, body)}>
          Open in Mail
        </a>
        {copied === "copied" && <span className="status-text">Copied</span>}
        {copied === "failed" && <span className="status-text error">Couldn't copy — select the text instead</span>}
      </div>
      <p className="muted" style={{ fontSize: "0.85rem", marginBottom: 0 }}>
        Unlist never sends anything. You review and send the request yourself.
        {!broker.optOutEmail && " This broker has no opt-out email, so add the recipient yourself."}
      </p>
    </section>
  );
}
