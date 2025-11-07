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
  title: "The Arx Network",
  description:
    "Speak privately, pay natively, connect securely. Run by the community, not Big Tech. Download Arx and buy $ARX to help govern ArxNet.",
  applicationName: "ArxNet",
  openGraph: {
    title: "The Arx Network",
    description: "Own your Conversation and money — Get Your ARX",
    type: "website",
    url: "https://www.arxnet.io",
    siteName: "The Arx Network",
    images: [
      {
        url: "/opengraph-image",
        width: 1200,
        height: 630,
        alt: "The Arx Network",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "The Arx Network",
    description:
      "Arx is a fortress for private communication and money—built on a decentralized relay network with an EVM PoS chain.",
    images: ["/opengraph-image"],
  },
  metadataBase: new URL("https://www.arxnet.io"),
  themeColor: "#171717",
  viewport: {
    width: "device-width",
    initialScale: 1,
    viewportFit: "cover",
  },
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
          <div className="relative container h-full">
            <AppHeader />
            <main className="flex min-h-screen flex-col items-center p-4 md:p-8 md:pt-20">
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
