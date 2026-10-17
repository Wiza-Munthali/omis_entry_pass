"use client";

import { useRef } from "react";

/** "View QR": the pass's QR (rendered on the server) in a dialog. */
export function QrDialog({
  name,
  children,
}: {
  name: string;
  children: React.ReactNode;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  return (
    <>
      <button
        type="button"
        onClick={() => ref.current?.showModal()}
        className="inline-flex h-9 items-center rounded-full border border-border px-4 text-label font-medium hover:bg-surface-2"
      >
        View QR
      </button>
      <dialog
        ref={ref}
        className="m-auto w-[min(92vw,360px)] rounded-card bg-surface p-6 backdrop:bg-ink/40"
      >
        <h2 className="text-title font-semibold text-ink">{name}</h2>
        <div className="mx-auto mt-4 w-64">{children}</div>
        <form method="dialog" className="mt-4 text-right">
          <button className="h-10 rounded-full border border-border px-4 font-medium hover:bg-surface-2">
            Close
          </button>
        </form>
      </dialog>
    </>
  );
}
