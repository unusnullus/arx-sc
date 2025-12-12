"use client";

import { useMounted } from "@arx/ui/hooks";
import { Spinner } from "@arx/ui/components";

export default function GovernorLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const mounted = useMounted();

  if (!mounted) {
    return (
      <div className="flex h-full items-center justify-center">
        <Spinner variant="circle" />
      </div>
    );
  }

  return <>{children}</>;
}
