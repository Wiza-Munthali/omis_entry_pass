import type { NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/middleware";

export async function middleware(request: NextRequest) {
  return updateSession(request);
}

export const config = {
  // Everything except static files, images and PWA assets.
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|logo.png|icons/|sw.js|manifest.webmanifest).*)",
  ],
};
