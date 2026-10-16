import { createContext, useContext, useEffect } from "react";

export const UNSAVED_MESSAGE = "You have unsaved changes to your details. Leave without saving?";

// A page reports whether it has unsaved edits; App asks before leaving.
export const UnsavedContext = createContext<(dirty: boolean) => void>(() => {});

export function useUnsavedChanges(dirty: boolean) {
  const setDirty = useContext(UnsavedContext);
  useEffect(() => {
    setDirty(dirty);
    return () => setDirty(false);
  }, [dirty, setDirty]);
}
