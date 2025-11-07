import { ImageResponse } from "next/og";
import Image from "next/image";

export const runtime = "edge";

export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default async function OG() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "center",
          alignItems: "center",
          background:
            "linear-gradient(135deg, #0B0F1A 0%, #1A1330 60%, #0B0F1A 100%)",
          color: "#FEFEFE",
          fontFamily: "sans-serif",
        }}
      >
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 16,
            marginBottom: 24,
          }}
        >
          <Image
            src="/logo-arx.svg"
            alt="The Arx Network"
            width={72}
            height={72}
          />
          <div style={{ fontSize: 64, fontWeight: 800, letterSpacing: 2 }}>
            ARX
          </div>
        </div>
        <div
          style={{
            fontSize: 44,
            fontWeight: 700,
            textAlign: "center",
            maxWidth: 960,
            lineHeight: 1.2,
          }}
        >
          Own your Conversation and money — Get Your ARX
        </div>
      </div>
    ),
    { ...size },
  );
}
