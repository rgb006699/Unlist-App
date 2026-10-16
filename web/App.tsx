import { useCallback, useEffect, useRef, useState, type MouseEvent } from "react";
import { LayoutDashboard, ShieldCheck, UserRound } from "lucide-react";
import { NavLink, Route, Routes, useLocation, useNavigate } from "react-router-dom";
import { api, ApiError, onApiSuccess } from "./api";
import { ServerBanner } from "./components/ServerBanner";
import { ReportErrorContext } from "./errors";
import BrokerDetail from "./pages/BrokerDetail";
import Dashboard from "./pages/Dashboard";
import Profile from "./pages/Profile";
import { UNSAVED_MESSAGE, UnsavedContext } from "./unsaved";
import "./styles.css";

export default function App() {
  const [error, setError] = useState<ApiError | null>(null);
  const [reloadKey, setReloadKey] = useState(0);
  const navigate = useNavigate();
  const location = useLocation();

  const report = useCallback((e: unknown) => {
    setError(e instanceof ApiError ? e : new ApiError("UNKNOWN", 0, String(e)));
  }, []);

  useEffect(() => onApiSuccess(() => setError(null)), []);

  const dirty = useRef(false);
  const setDirty = useCallback((d: boolean) => {
    dirty.current = d;
  }, []);

  useEffect(() => {
    const onUnload = (e: BeforeUnloadEvent) => {
      if (!dirty.current) return;
      e.preventDefault();
      e.returnValue = "";
    };
    window.addEventListener("beforeunload", onUnload);
    return () => window.removeEventListener("beforeunload", onUnload);
  }, []);

  const guard = (e: MouseEvent) => {
    if (dirty.current && !window.confirm(UNSAVED_MESSAGE)) e.preventDefault();
  };

  useEffect(() => {
    api
      .getProfile()
      .then((p) => {
        if (!p.fullName.trim() && location.pathname === "/") navigate("/profile", { replace: true });
      })
      .catch(report);
    // Only on first load and after a restore.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [reloadKey]);

  const restore = async () => {
    try {
      await api.restore();
      setError(null);
      setReloadKey((k) => k + 1);
    } catch (e) {
      if (e instanceof ApiError && e.code === "NOTHING_TO_RESTORE") {
        // The file is readable again (e.g. fixed by hand): just reload it.
        setError(null);
        setReloadKey((k) => k + 1);
      } else {
        report(e);
      }
    }
  };

  return (
    <ReportErrorContext.Provider value={report}>
      <UnsavedContext.Provider value={setDirty}>
        <header className="topbar">
          <span className="brand">
            <ShieldCheck size={22} strokeWidth={2.25} aria-hidden="true" />
            Unlist
          </span>
          <nav>
            <NavLink to="/" end onClick={guard}>
              <LayoutDashboard size={17} aria-hidden="true" />
              Dashboard
            </NavLink>
            <NavLink to="/profile" onClick={guard}>
              <UserRound size={17} aria-hidden="true" />
              Profile
            </NavLink>
          </nav>
        </header>
        <ServerBanner error={error} onRestore={restore} />
        <main key={reloadKey}>
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/broker/:id" element={<BrokerDetail />} />
            <Route path="/profile" element={<Profile />} />
          </Routes>
        </main>
      </UnsavedContext.Provider>
    </ReportErrorContext.Provider>
  );
}
