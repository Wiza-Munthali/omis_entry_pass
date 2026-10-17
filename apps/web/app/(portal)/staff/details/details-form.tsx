"use client";

import { useActionState, useEffect, useState } from "react";
import { Car } from "lucide-react";
import { Field } from "@/components/portal/field";
import { Notice } from "@/components/portal/notice";
import { SubmitButton } from "@/components/portal/submit-button";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { saveDetails, type FormState } from "../actions";

type Defaults = {
  fullName: string;
  idNumber: string;
  drives: boolean;
  plate: string;
};

export function DetailsForm({
  defaults,
  isEdit,
}: {
  defaults: Defaults;
  isEdit: boolean;
}) {
  const [state, action] = useActionState<FormState, FormData>(saveDetails, {});
  const values = { ...defaults, ...state.values };
  const [drives, setDrives] = useState(Boolean(values.drives));

  // React resets the form after each action and Radix's Switch follows that reset
  // back to its initial value; restore what was submitted.
  useEffect(() => {
    if (state.values) setDrives(Boolean(state.values.drives));
  }, [state]);

  return (
    <form action={action} className="mt-8 grid gap-6" noValidate>
      {state.error && <Notice tone="danger">{state.error}</Notice>}

      <Field
        label="Full name"
        name="fullName"
        autoComplete="name"
        defaultValue={String(values.fullName)}
        error={state.fields?.fullName}
        required
      />
      <Field
        label="ID number"
        name="idNumber"
        autoComplete="off"
        autoCapitalize="characters"
        defaultValue={String(values.idNumber)}
        hint="National ID or staff ID number."
        error={state.fields?.idNumber}
        required
      />

      <div className="flex items-center justify-between gap-4 rounded-card bg-surface px-5 py-4">
        <Label htmlFor="drives" className="gap-3 text-body">
          <span className="inline-flex size-10 items-center justify-center rounded-full bg-surface-2 text-ink">
            <Car className="size-5" aria-hidden />
          </span>
          I drive to work
        </Label>
        {/* Submitted through our own field: Radix's hidden checkbox can fall out of sync after a form reset. */}
        <input type="hidden" name="drives" value={drives ? "on" : "off"} />
        <Switch id="drives" checked={drives} onCheckedChange={setDrives} />
      </div>

      {drives && (
        <Field
          label="Number plate"
          name="plate"
          autoCapitalize="characters"
          placeholder="BT 4521"
          defaultValue={String(values.plate ?? "")}
          error={state.fields?.plate}
          required
        />
      )}

      <SubmitButton pendingText="Saving…">
        {isEdit ? "Save details" : "Get my pass"}
      </SubmitButton>
    </form>
  );
}
