import type { Metadata, Viewport } from "next";
import { Inter } from "next/font/google";
import { tokens } from "@/lib/tokens";
import "./globals.css";

const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "OMIS Entry",
  description: "Get your gate pass",
  icons: { icon: "/icons/icon-192.png", apple: "/icons/apple-touch-icon.png" },
  appleWebApp: {
    capable: true,
    title: "OMIS Entry",
    statusBarStyle: "default",
  },
};

export const viewport: Viewport = {
  themeColor: tokens.bg,
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`${inter.variable} antialiased`}>{children}</body>
    </html>
  );
}
