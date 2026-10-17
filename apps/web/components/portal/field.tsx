import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

type FieldProps = React.ComponentProps<typeof Input> & {
  label: string;
  name: string;
  hint?: string;
  error?: string;
};

/** Label, pill input, and either a hint or an error underneath. */
export function Field({ label, name, hint, error, id, ...props }: FieldProps) {
  const inputId = id ?? name;
  const describedBy = error || hint ? `${inputId}-desc` : undefined;
  return (
    <div className="grid gap-2">
      <Label htmlFor={inputId} className="px-1">
        {label}
      </Label>
      <Input
        id={inputId}
        name={name}
        aria-invalid={error ? true : undefined}
        aria-describedby={describedBy}
        {...props}
      />
      {(error || hint) && (
        <p
          id={describedBy}
          role={error ? "alert" : undefined}
          className={
            error
              ? "px-1 text-label text-danger"
              : "px-1 text-label text-text-muted"
          }
        >
          {error ?? hint}
        </p>
      )}
    </div>
  );
}
