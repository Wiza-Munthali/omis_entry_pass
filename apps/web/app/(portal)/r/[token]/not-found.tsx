import Link from "next/link";
import { Notice } from "@/components/portal/notice";
import { buttonVariants } from "@/components/ui/button";

export default function RequestNotFound() {
  return (
    <div className="grid gap-6 pt-12">
      <Notice tone="warning">
        We can&apos;t find this request. Check that you opened the full link
        from your confirmation page or email.
      </Notice>
      <Link href="/visit" className={buttonVariants()}>
        Request a visitor pass
      </Link>
    </div>
  );
}
