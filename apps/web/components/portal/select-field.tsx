import { ChevronDown } from "lucide-react";
import { Label } from "@/components/ui/label";
import { cn } from "@/lib/utils";

type SelectFieldProps = React.ComponentProps<"select"> & {
  label: string;
  name: string;
  options: readonly { value: string; label: string }[];
  placeholder: string;
  error?: string;
};

/** Native select in the pill style (best on cheap phones: uses the OS picker). */
export function SelectField({
  label,
  name,
  options,
  placeholder,
  error,
  className,
  ...props
}: SelectFieldProps) {
  const describedBy = error ? `${name}-desc` : undefined;
  return (
    <div className="grid gap-2">
      <Label htmlFor={name} className="px-1">
        {label}
      </Label>
      <div className="relative">
        <select
          id={name}
          name={name}
          aria-invalid={error ? true : undefined}
          aria-describedby={describedBy}
          className={cn(
            "h-14 w-full appearance-none rounded-full border border-transparent bg-surface-2 pr-12 pl-5 text-body text-text outline-none invalid:text-text-muted focus-visible:border-brand focus-visible:ring-[3px] focus-visible:ring-brand/30 aria-invalid:border-danger",
            className,
          )}
          {...props}
        >
          <option value="" disabled>
            {placeholder}
          </option>
          {options.map((o) => (
            <option key={o.value} value={o.value}>
              {o.label}
            </option>
          ))}
        </select>
        <ChevronDown className="pointer-events-none absolute top-1/2 right-5 size-5 -translate-y-1/2 text-text-muted" />
      </div>
      {error && (
        <p
          id={describedBy}
          role="alert"
          className="px-1 text-label text-danger"
        >
          {error}
        </p>
      )}
    </div>
  );
}
