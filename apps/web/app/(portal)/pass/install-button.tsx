"use client";

import { useEffect, useState } from "react";
import { SquarePlus } from "lucide-react";
import { Button } from "@/components/ui/button";

type InstallPromptEvent = Event & {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: string }>;
};

/**
 * "Add to home screen". Android/Chrome: the browser's install prompt.
 * iPhone: Safari has no prompt, so show the Share → Add to Home Screen steps.
 * Hidden once the pass is already running as an installed app.
 */
export function InstallButton() {
  const [prompt, setPrompt] = useState<InstallPromptEvent | null>(null);
  const [installed, setInstalled] = useState(false);
  const [showIosHelp, setShowIosHelp] = useState(false);
  const [isIos, setIsIos] = useState(false);

  useEffect(() => {
    setInstalled(window.matchMedia("(display-mode: standalone)").matches);
    setIsIos(/iphone|ipad|ipod/i.test(navigator.userAgent));
    const onPrompt = (e: Event) => {
      e.preventDefault();
      setPrompt(e as InstallPromptEvent);
    };
    const onInstalled = () => setInstalled(true);
    window.addEventListener("beforeinstallprompt", onPrompt);
    window.addEventListener("appinstalled", onInstalled);
    return () => {
      window.removeEventListener("beforeinstallprompt", onPrompt);
      window.removeEventListener("appinstalled", onInstalled);
    };
  }, []);

  if (installed || (!prompt && !isIos)) return null;

  return (
    <div className="grid gap-2">
      <Button
        variant="secondary"
        className="border border-border"
        onClick={async () => {
          if (prompt) {
            await prompt.prompt();
            setPrompt(null);
          } else {
            setShowIosHelp((v) => !v);
          }
        }}
      >
        <SquarePlus className="text-brand-strong" aria-hidden />
        <span className="h-6 w-px bg-border" aria-hidden />
        Add to home screen
      </Button>
      {showIosHelp && (
        <p className="rounded-card bg-surface px-5 py-4 text-label text-text-muted">
          In Safari, tap the{" "}
          <span className="font-medium text-text">Share</span> button, then{" "}
          <span className="font-medium text-text">Add to Home Screen</span>.
          Your pass then opens like an app, even without data.
        </p>
      )}
    </div>
  );
}
