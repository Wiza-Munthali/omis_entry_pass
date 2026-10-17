import type { MetadataRoute } from "next";
import { tokens } from "@/lib/tokens";

// Installable pass: opens straight to /pass, full-screen like an app.
export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "OMIS Entry",
    short_name: "OMIS Entry",
    description: "Your gate pass",
    start_url: "/pass",
    scope: "/",
    display: "standalone",
    orientation: "portrait",
    background_color: tokens.bg,
    theme_color: tokens.bg,
    icons: [
      { src: "/icons/icon-192.png", sizes: "192x192", type: "image/png" },
      { src: "/icons/icon-512.png", sizes: "512x512", type: "image/png" },
      {
        src: "/icons/maskable-512.png",
        sizes: "512x512",
        type: "image/png",
        purpose: "maskable",
      },
    ],
  };
}
