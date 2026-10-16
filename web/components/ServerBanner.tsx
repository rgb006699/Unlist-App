import { CircleAlert, RotateCcw } from "lucide-react";
import type { ApiError } from "../api";

export function ServerBanner({ error, onRestore }: { error: ApiError | null; onRestore(): void }) {
  if (!error) return null;
  if (error.code === "UNREACHABLE") {
    return (
      <div className="banner" role="alert">
        <CircleAlert size={20} aria-hidden="true" />
        <span>
          Can't reach Unlist server — is <code>npm start</code> running?
        </span>
      </div>
    );
  }
  if (error.code === "DATA_CORRUPT") {
    return (
      <div className="banner" role="alert">
        <CircleAlert size={20} aria-hidden="true" />
        <span>
          Your data file couldn't be read ({error.message}). Restoring keeps a copy of the unreadable file next to it.
        </span>
        <button type="button" onClick={onRestore}>
          <RotateCcw size={16} aria-hidden="true" />
          Restore from backup
        </button>
      </div>
    );
  }
  return (
    <div className="banner" role="alert">
      <CircleAlert size={20} aria-hidden="true" />
      <span>{error.message}</span>
    </div>
  );
}
