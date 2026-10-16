import { useCallback, useEffect, useState } from "react";
import { NavLink, Route, Routes, useLocation, useNavigate } from "react-router-dom";
import { api, ApiError, onApiSuccess } from "./api";
import { ServerBanner } from "./components/ServerBanner";
import { ReportErrorContext } from "./errors";
import BrokerDetail from "./pages/BrokerDetail";
import Dashboard from "./pages/Dashboard";
import Profile from "./pages/Profile";
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
      <header className="topbar">
        <span className="brand">Unlist</span>
        <nav>
          <NavLink to="/" end>
            Dashboard
          </NavLink>
          <NavLink to="/profile">Profile</NavLink>
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
    </ReportErrorContext.Provider>
  );
}
