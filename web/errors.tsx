import { createContext, useContext } from "react";

// Pages report API failures here; App shows them in the ServerBanner.
export const ReportErrorContext = createContext<(e: unknown) => void>(() => {});

export const useReportError = () => useContext(ReportErrorContext);
