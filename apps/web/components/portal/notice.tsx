import { cn } from "@/lib/utils";
import { CircleAlert, CircleCheck, Info, TriangleAlert } from "lucide-react";

const TONES = {
  success: { className: "bg-success-soft text-success", Icon: CircleCheck },
  warning: { className: "bg-warning-soft text-warning", Icon: TriangleAlert },
  danger: { className: "bg-danger-soft text-danger", Icon: CircleAlert },
  info: { className: "bg-info-soft text-info", Icon: Info },
} as const;

/** Soft-coloured banner for status messages. */
export function Notice({
  tone,
  children,
  className,
}: {
  tone: keyof typeof TONES;
  children: React.ReactNode;
  className?: string;
}) {
  const { className: toneClass, Icon } = TONES[tone];
  return (
    <div
      role={tone === "danger" || tone === "warning" ? "alert" : "status"}
      className={cn(
        "flex items-start gap-3 rounded-card px-5 py-4 text-label font-medium",
        toneClass,
        className,
      )}
    >
      <Icon className="mt-0.5 size-5 shrink-0" aria-hidden />
      <div>{children}</div>
    </div>
  );
}
