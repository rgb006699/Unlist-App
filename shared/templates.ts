// Request email templates. Edit the wording freely; it is a starting point,
// not legal advice.
import type { Address, Broker, Profile } from "./types";

export type TemplateId = "tdpsa" | "general";

const formatAddress = (a: Address) =>
  [a.street, a.city, [a.state, a.zip].filter(Boolean).join(" ")].filter(Boolean).join(", ");

function detailLines(profile: Profile, listingUrl: string): string[] {
  const lines: string[] = [];
  const add = (label: string, values: string[]) => {
    const v = values.map((s) => s.trim()).filter(Boolean);
    if (v.length) lines.push(`${label}: ${v.join("; ")}`);
  };
  add("Full name", [profile.fullName]);
  add("Other names", profile.aliases);
  const current = profile.addresses.filter((a) => a.current).map(formatAddress);
  const others = profile.addresses.filter((a) => !a.current).map(formatAddress);
  if (current.length) {
    add("Current address", current);
    add("Previous addresses", others);
  } else {
    add("Addresses", others);
  }
  add("Phone numbers", profile.phones);
  add("Email addresses", profile.emails);
  add("Page where my information appears", [listingUrl]);
  return lines;
}

function closing(profile: Profile): string[] {
  const name = profile.fullName.trim();
  return name ? ["Thank you,", name] : ["Thank you."];
}

export function fillTemplate(
  id: TemplateId,
  profile: Profile,
  broker: Broker,
  listingUrl: string,
): { subject: string; body: string } {
  const details = detailLines(profile, listingUrl);
  const detailBlock = details.length ? [details.join("\n")] : [];

  if (id === "tdpsa") {
    const paragraphs = [
      `To the privacy team at ${broker.name},`,
      "I am a Texas resident. Under the Texas Data Privacy and Security Act, I am exercising my right to have my personal data deleted. Please delete all personal data you hold about me, stop selling or sharing it, and remove any public profile or listing about me. My identifying details are below.",
      ...detailBlock,
      "Please use these details only to find and delete my records. The Texas Data Privacy and Security Act requires a response within 45 days. Please confirm in writing when the deletion is complete.",
      closing(profile).join("\n"),
    ];
    return {
      subject: "Request to delete my personal data — Texas Data Privacy and Security Act",
      body: paragraphs.join("\n\n"),
    };
  }

  const paragraphs = [
    `Hello ${broker.name} team,`,
    "I am asking you to remove my personal information from your website and records, and to stop selling or sharing it. My identifying details are below.",
    ...detailBlock,
    "Please use these details only to find and remove my records, and confirm in writing when this is done.",
    closing(profile).join("\n"),
  ];
  return { subject: "Request to remove my personal information", body: paragraphs.join("\n\n") };
}

export function mailtoLink(to: string | null, subject: string, body: string): string {
  return `mailto:${to ?? ""}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
}
