import { Check, Copy, FileText, Lock, Mail } from "lucide-react";
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
      <div className="card-head">
        <FileText size={20} aria-hidden="true" />
        <h2 id="request-heading">Removal request</h2>
      </div>
      <p className="muted small">
        A ready-to-send email asking {broker.name} to delete your information. Texas residents can cite the Texas
        privacy law; the general version works anywhere.
      </p>
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
      <p className="subject">
        <span className="muted">Subject: </span>
        <strong>{subject}</strong>
      </p>
      <pre className="preview">{body}</pre>
      <div className="row">
        <button type="button" className="primary" onClick={copy}>
          <Copy size={16} aria-hidden="true" />
          Copy
        </button>
        <a className="button" href={mailtoLink(broker.optOutEmail, subject, body)}>
          <Mail size={16} aria-hidden="true" />
          Open in Mail
        </a>
        {copied === "copied" && (
          <span className="copied" role="status">
            <Check size={16} aria-hidden="true" />
            Copied
          </span>
        )}
        {copied === "failed" && (
          <span className="error-text" role="status">
            Couldn't copy — select the text instead
          </span>
        )}
      </div>
      <p className="note">
        <Lock size={15} aria-hidden="true" />
        <span>
          Unlist never sends anything. You review and send the request yourself.
          {!broker.optOutEmail && " This broker has no opt-out email, so add the recipient yourself."}
        </span>
      </p>
    </section>
  );
}
