"use client";

import { useEffect, useState } from "react";

const MOBILE_BREAKPOINT = 768;
const TABLET_BREAKPOINT = 1024;

export type DeviceType = "mobile" | "tablet" | "desktop";

export function useDeviceType(): DeviceType {
  const getType = () => {
    if (typeof window === "undefined") return "desktop";

    const width = window.innerWidth;
    if (width < MOBILE_BREAKPOINT) return "mobile";
    if (width < TABLET_BREAKPOINT) return "tablet";
    return "desktop";
  };

  const [deviceType, setDeviceType] = useState<DeviceType>(getType);

  useEffect(() => {
    const handleResize = () => setDeviceType(getType());
    window.addEventListener("resize", handleResize);

    return () => window.removeEventListener("resize", handleResize);
  }, []);

  return deviceType;
}

export const useIsMobile = () => {
  const deviceType = useDeviceType();
  return deviceType === "mobile";
};

export const useIsTablet = () => {
  const deviceType = useDeviceType();
  return deviceType === "tablet";
};

export const useIsDesktop = () => {
  const deviceType = useDeviceType();
  return deviceType === "desktop";
};
