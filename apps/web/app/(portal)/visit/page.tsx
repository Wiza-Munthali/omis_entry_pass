import { ScreenHeader } from "@/components/portal/screen-header";
import { Notice } from "@/components/portal/notice";

// Visitor requests arrive in Phase 4 (P6–P9).
export default function VisitPage() {
  return (
    <>
      <ScreenHeader title="Visitor pass" backHref="/" />
      <Notice tone="info" className="mt-8">
        Online visitor requests are coming soon. For now, please ask the guard
        at the gate.
      </Notice>
    </>
  );
}
