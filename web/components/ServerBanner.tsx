import type { ApiError } from "../api";

export function ServerBanner({ error, onRestore }: { error: ApiError | null; onRestore(): void }) {
  if (!error) return null;
  if (error.code === "UNREACHABLE") {
    return (
      <div className="banner" role="alert">
        Can't reach Unlist server — is <code>npm run dev</code> running?
      </div>
    );
  }
  if (error.code === "DATA_CORRUPT") {
    return (
      <div className="banner" role="alert">
        Your data file couldn't be read ({error.message}). Restoring keeps a copy of the unreadable file next to it.
        <button type="button" onClick={onRestore}>
          Restore from backup
        </button>
      </div>
    );
  }
  return (
    <div className="banner" role="alert">
      {error.message}
    </div>
  );
}
