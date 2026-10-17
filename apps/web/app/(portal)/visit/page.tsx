import { localToday } from "@/lib/visitor";
import { RequestForm } from "./request-form";

export const dynamic = "force-dynamic";

// P6–P8 Visitor request. "Today" is computed on the server in Africa/Blantyre.
export default function VisitPage() {
  return <RequestForm today={localToday()} />;
}
