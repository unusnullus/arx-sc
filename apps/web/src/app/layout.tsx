import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "@arx/ui/globals.css";
import Providers from "@/providers";
import { Toaster } from "@arx/ui/components";
import { AppHeader } from "@/widgets/app-header";

const geistSans = Geist({
  variable: "--font-geist-sans",
  weight: ["400", "500", "600", "700"],
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "ARX",
  description: "ARX is the token that connects users, operators, and builders.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body
        className={`${geistSans.variable} ${geistMono.variable} flex flex-col items-center antialiased`}
      >
        <Providers>
          <div className="container">
            <AppHeader />
            <main className="flex min-h-screen flex-col items-center p-8">
              {children}
            </main>
          </div>
          <Toaster />
        </Providers>
      </body>
    </html>
  );
}

export const dynamic = "force-dynamic";
