import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Ops Hub | Cloudigan",
  description: "Unified calendar, tasks, and time tracking for Cloudigan operations.",
  applicationName: "Cloudigan Ops Hub",
  icons: {
    icon: [
      { url: "/favicon.ico", sizes: "any" },
      { url: "/icon.svg", type: "image/svg+xml" },
    ],
    apple: [{ url: "/apple-icon.png", type: "image/png" }],
  },
  themeColor: "#2d388a",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
