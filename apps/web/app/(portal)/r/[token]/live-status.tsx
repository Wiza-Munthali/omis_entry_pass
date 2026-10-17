"use client";

import { useRouter } from "next/navigation";
import { useEffect, useTransition } from "react";
import { RefreshCw } from "lucide-react";
import { Button } from "@/components/ui/button";
import { createClient } from "@/lib/supabase/client";

const POLL_MS = 15_000;

/**
 * Keeps a pending request's page current: listens for the database's broadcast on
 * request:{token} and, in case Realtime is blocked or drops, re-checks every 15 s.
 */
export function LiveStatus({ token }: { token: string }) {
  const router = useRouter();
  const [checking, startCheck] = useTransition();

  useEffect(() => {
    const supabase = createClient();
    const channel = supabase
      .channel(`request:${token}`)
      .on("broadcast", { event: "status_changed" }, () => router.refresh())
      .subscribe();
    const timer = setInterval(() => router.refresh(), POLL_MS);
    const onVisible = () =>
      document.visibilityState === "visible" && router.refresh();
    document.addEventListener("visibilitychange", onVisible);
    return () => {
      clearInterval(timer);
      document.removeEventListener("visibilitychange", onVisible);
      supabase.removeChannel(channel);
    };
  }, [token, router]);

  return (
    <Button
      onClick={() => startCheck(() => router.refresh())}
      disabled={checking}
    >
      <RefreshCw
        className={checking ? "animate-spin" : undefined}
        aria-hidden
      />
      Check for updates
    </Button>
  );
}
