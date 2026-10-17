"use client";

import { signOut } from "../staff/actions";

/** Signs out and removes the offline copy of the pass from this device. */
export function SignOutButton() {
  return (
    <form
      action={async () => {
        if ("caches" in window) await caches.delete("omis-pass");
        await signOut();
      }}
    >
      <button
        type="submit"
        className="font-medium text-text-muted hover:underline"
      >
        Sign out
      </button>
    </form>
  );
}
