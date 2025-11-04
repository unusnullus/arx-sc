import { useCallback, useEffect, useState } from "react";

import { PermitSettings } from "../types";

export const usePermitSettings = () => {
  const [settings, setSettings] = useState({
    approve: false,
    slippage: 1,
  });

  useEffect(() => {
    setSettings((prev) => ({
      ...prev,
      approve: localStorage.getItem("permit-approve") === "true",
    }));
  }, []);

  const updateSettings = useCallback((newSettings: Partial<PermitSettings>) => {
    setSettings((prev) => ({ ...prev, ...newSettings }));
    if (newSettings.approve !== undefined) {
      localStorage.setItem("permit-approve", newSettings.approve.toString());
    }
  }, []);

  return { settings, updateSettings };
};
