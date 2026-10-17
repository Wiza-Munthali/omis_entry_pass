import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { ScreenHeader } from "@/components/portal/screen-header";
import { VerifyForm } from "./verify-form";

// P3 Verify code
export default async function VerifyPage() {
  const email = (await cookies()).get("otp_email")?.value;
  if (!email) redirect("/staff");

  return (
    <>
      <ScreenHeader backHref="/staff" />
      <h1 className="mt-8 text-display font-semibold text-ink">
        Enter the 6-digit code
      </h1>
      <p className="mt-2 text-body text-text-muted">
        Sent to <span className="font-medium break-all text-text">{email}</span>
      </p>
      <VerifyForm />
    </>
  );
}
