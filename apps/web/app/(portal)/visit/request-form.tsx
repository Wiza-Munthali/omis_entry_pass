"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { ArrowRight, CalendarDays, Car, LoaderCircle } from "lucide-react";
import { Field } from "@/components/portal/field";
import { Notice } from "@/components/portal/notice";
import { ScreenHeader } from "@/components/portal/screen-header";
import { SelectField } from "@/components/portal/select-field";
import { StepIndicator } from "@/components/portal/step-indicator";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { displayPlate } from "@/lib/format";
import { cn } from "@/lib/utils";
import { fieldErrors } from "@/lib/validation";
import {
  MAX_DAYS_AHEAD,
  PASS_TYPES,
  PURPOSES,
  aboutYouSchema,
  addDays,
  submitErrorMessage,
  yourVisitSchema,
} from "@/lib/visitor";

type Data = {
  fullName: string;
  phone: string;
  email: string;
  idNumber: string;
  hostName: string;
  purpose: string;
  passType: "day" | "week";
  startDate: string;
  plate: string;
};

const STEP_OF_FIELD: Record<string, 1 | 2> = {
  fullName: 1,
  phone: 1,
  email: 1,
  idNumber: 1,
  hostName: 2,
  purpose: 2,
  passType: 2,
  startDate: 2,
  plate: 2,
};

const FIELD_LABEL: Record<string, string> = {
  fullName: "Check your name.",
  phone: "Check your phone number.",
  email: "Check your email address.",
  idNumber: "Check your ID number.",
  hostName: "Check who you are visiting.",
  purpose: "Choose the purpose of your visit.",
  passType: "Choose a pass type.",
  startDate: "Choose a start date from today to 14 days ahead.",
  plate: "Use letters and numbers only, e.g. BT 4521.",
};

function formatDay(isoDate: string) {
  return new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "short",
    year: "numeric",
    timeZone: "UTC",
  }).format(new Date(`${isoDate}T00:00:00Z`));
}

// P6–P8 Visitor request, three steps in one client component.
export function RequestForm({ today }: { today: string }) {
  const router = useRouter();
  const [step, setStep] = useState<1 | 2 | 3>(1);
  const [data, setData] = useState<Data>({
    fullName: "",
    phone: "",
    email: "",
    idNumber: "",
    hostName: "",
    purpose: "",
    passType: "day",
    startDate: today,
    plate: "",
  });
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [consent, setConsent] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string>();

  const set =
    (key: keyof Data) =>
    (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
      setData((d) => ({ ...d, [key]: e.target.value }));

  function next() {
    const result =
      step === 1
        ? aboutYouSchema.safeParse(data)
        : yourVisitSchema(today).safeParse(data);
    if (!result.success) {
      setErrors(fieldErrors(result.error));
      return;
    }
    setErrors({});
    setStep((s) => (s === 1 ? 2 : 3));
    window.scrollTo({ top: 0 });
  }

  async function submit() {
    if (!consent) {
      setErrors({ consent: "Please agree so we can process your request." });
      return;
    }
    setSubmitting(true);
    setSubmitError(undefined);
    try {
      const response = await fetch(
        `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/submit-visitor-request`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            apikey: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? "",
          },
          body: JSON.stringify({
            ...data,
            consent,
            plate: data.plate || undefined,
          }),
        },
      );
      const body = await response.json().catch(() => ({}));
      if (response.ok && body.status_token) {
        router.push(`/r/${body.status_token}`);
        return;
      }
      const fields: string[] = body.fields ?? [];
      if (fields.length) {
        setErrors(
          Object.fromEntries(
            fields.map((f) => [f, FIELD_LABEL[f] ?? "Check this field."]),
          ),
        );
        setStep(Math.min(...fields.map((f) => STEP_OF_FIELD[f] ?? 1)) as 1 | 2);
      }
      setSubmitError(submitErrorMessage(response.status, body.error));
    } catch {
      setSubmitError(submitErrorMessage(0));
    }
    setSubmitting(false);
  }

  return (
    <>
      <ScreenHeader
        title="Request visitor pass"
        backHref={step === 1 ? "/" : undefined}
        onBack={step > 1 ? () => setStep((s) => (s === 3 ? 2 : 1)) : undefined}
      />
      <div className="mt-4">
        <StepIndicator step={step} total={3} />
      </div>

      {submitError && (
        <Notice tone="danger" className="mt-6">
          {submitError}
        </Notice>
      )}

      {step === 1 && (
        <section
          className="mt-6 grid gap-5 rounded-card bg-surface p-5"
          aria-label="About you"
        >
          <h2 className="text-title font-semibold text-ink">About you</h2>
          <Field
            label="Full name"
            name="fullName"
            autoComplete="name"
            value={data.fullName}
            onChange={set("fullName")}
            error={errors.fullName}
            className="bg-surface-2"
          />
          <Field
            label="Phone"
            name="phone"
            type="tel"
            inputMode="tel"
            autoComplete="tel"
            placeholder="+265 991 234 567"
            value={data.phone}
            onChange={set("phone")}
            error={errors.phone}
            className="bg-surface-2"
          />
          <Field
            label="Email"
            name="email"
            type="email"
            inputMode="email"
            autoComplete="email"
            autoCapitalize="none"
            hint="We'll email your pass here once it's approved."
            value={data.email}
            onChange={set("email")}
            error={errors.email}
            className="bg-surface-2"
          />
          <Field
            label="ID number"
            name="idNumber"
            autoCapitalize="characters"
            hint="National ID or passport. The guard may ask to see it."
            value={data.idNumber}
            onChange={set("idNumber")}
            error={errors.idNumber}
            className="bg-surface-2"
          />
        </section>
      )}

      {step === 2 && (
        <section
          className="mt-6 grid gap-5 rounded-card bg-surface p-5"
          aria-label="Your visit"
        >
          <Field
            label="Visiting"
            name="hostName"
            placeholder="Person or department"
            value={data.hostName}
            onChange={set("hostName")}
            error={errors.hostName}
            className="bg-surface-2"
          />
          <SelectField
            label="Purpose"
            name="purpose"
            placeholder="Select purpose"
            options={PURPOSES}
            value={data.purpose}
            onChange={set("purpose")}
            error={errors.purpose}
            required
          />

          <fieldset className="grid gap-2">
            <legend className="mb-2 px-1 text-label font-medium text-text">
              Pass type
            </legend>
            <div className="grid grid-cols-2 gap-3">
              {PASS_TYPES.map((t) => {
                const selected = data.passType === t.value;
                return (
                  <label
                    key={t.value}
                    className={cn(
                      "flex cursor-pointer flex-col gap-1 rounded-card border-2 p-4 transition-colors has-[:focus-visible]:ring-[3px] has-[:focus-visible]:ring-brand/30",
                      selected
                        ? "border-brand bg-brand-soft"
                        : "border-transparent bg-surface-2",
                    )}
                  >
                    <span className="flex items-center gap-2">
                      <input
                        type="radio"
                        name="passType"
                        value={t.value}
                        checked={selected}
                        onChange={() =>
                          setData((d) => ({ ...d, passType: t.value }))
                        }
                        className="size-5 accent-brand-strong"
                      />
                      <span className="text-body font-semibold text-ink">
                        {t.label}
                      </span>
                    </span>
                    <span className="text-label text-text-muted">{t.hint}</span>
                  </label>
                );
              })}
            </div>
          </fieldset>

          <Field
            label="Start date"
            name="startDate"
            type="date"
            min={today}
            max={addDays(today, MAX_DAYS_AHEAD)}
            value={data.startDate}
            onChange={set("startDate")}
            error={errors.startDate}
            hint={`Today or up to ${MAX_DAYS_AHEAD} days ahead.`}
            className="bg-surface-2"
          />
          <Field
            label="Vehicle plate (optional)"
            name="plate"
            autoCapitalize="characters"
            placeholder="e.g. BT 4521"
            value={data.plate}
            onChange={set("plate")}
            error={errors.plate}
            className="bg-surface-2"
          />
        </section>
      )}

      {step === 3 && (
        <section className="mt-6 grid gap-5" aria-label="Review">
          <div className="grid gap-4 rounded-card bg-surface p-5">
            <ReviewGroup title="About you" onEdit={() => setStep(1)}>
              <ReviewRow label="Name" value={data.fullName} />
              <ReviewRow label="Phone" value={data.phone} />
              <ReviewRow label="Email" value={data.email} />
              <ReviewRow label="ID number" value={data.idNumber} />
            </ReviewGroup>
            <div className="h-px bg-border" />
            <ReviewGroup title="Your visit" onEdit={() => setStep(2)}>
              <ReviewRow label="Visiting" value={data.hostName} />
              <ReviewRow
                label="Purpose"
                value={
                  PURPOSES.find((p) => p.value === data.purpose)?.label ?? ""
                }
              />
              <ReviewRow
                label="Pass"
                value={`${PASS_TYPES.find((t) => t.value === data.passType)?.label}, from ${formatDay(data.startDate)}`}
                icon={<CalendarDays />}
              />
              {data.plate && (
                <ReviewRow
                  label="Vehicle"
                  value={displayPlate(
                    data.plate.replace(/\s+/g, "").toUpperCase(),
                  )}
                  icon={<Car />}
                />
              )}
            </ReviewGroup>
          </div>

          <div className="grid gap-2">
            <Label className="items-start gap-3 rounded-card bg-surface p-5 text-body font-normal">
              <input
                type="checkbox"
                checked={consent}
                onChange={(e) => setConsent(e.target.checked)}
                aria-invalid={errors.consent ? true : undefined}
                className="mt-1 size-5 shrink-0 accent-brand-strong"
              />
              <span>
                I agree that GHII may use these details to manage my visit and
                keep a record of when I enter and leave.
              </span>
            </Label>
            {errors.consent && (
              <p role="alert" className="px-1 text-label text-danger">
                {errors.consent}
              </p>
            )}
          </div>
        </section>
      )}

      <div className="mt-8">
        {step < 3 ? (
          <Button onClick={next}>
            Continue <ArrowRight aria-hidden />
          </Button>
        ) : (
          <Button onClick={submit} disabled={submitting} aria-busy={submitting}>
            {submitting ? (
              <>
                <LoaderCircle className="animate-spin" aria-hidden /> Sending…
              </>
            ) : (
              "Send request"
            )}
          </Button>
        )}
      </div>
    </>
  );
}

function ReviewGroup({
  title,
  onEdit,
  children,
}: {
  title: string;
  onEdit: () => void;
  children: React.ReactNode;
}) {
  return (
    <div className="grid gap-3">
      <div className="flex items-center justify-between">
        <h2 className="text-title font-semibold text-ink">{title}</h2>
        <button
          type="button"
          onClick={onEdit}
          className="text-label font-medium text-brand-strong hover:underline"
        >
          Edit
        </button>
      </div>
      <dl className="grid gap-2">{children}</dl>
    </div>
  );
}

function ReviewRow({
  label,
  value,
  icon,
}: {
  label: string;
  value: string;
  icon?: React.ReactNode;
}) {
  return (
    <div className="flex items-start justify-between gap-4">
      <dt className="flex items-center gap-2 text-label text-text-muted [&_svg]:size-4">
        {icon}
        {label}
      </dt>
      <dd className="text-right text-body font-medium break-all text-ink">
        {value}
      </dd>
    </div>
  );
}
