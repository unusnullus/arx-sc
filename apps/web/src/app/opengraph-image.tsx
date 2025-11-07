import { ImageResponse } from "next/og";

export const runtime = "edge";
export const alt = "The Arx Network";
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
          <svg
            width="72"
            height="72"
            viewBox="0 0 43 43"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
          >
            <path
              d="M14.4363 3.27654C17.9965 -1.09218 24.6701 -1.09218 28.2303 3.27654L32.6678 8.72186C33.0488 9.18938 33.4766 9.6172 33.9442 9.99822L39.3904 14.4367C43.7588 17.9969 43.7588 24.6695 39.3904 28.2297L33.9442 32.6681C33.4766 33.0492 33.0488 33.477 32.6678 33.9445L28.2303 39.3898C24.6701 43.7585 17.9965 43.7585 14.4363 39.3898L9.99884 33.9445C9.61782 33.477 9.19001 33.0492 8.72247 32.6681L3.27618 28.2297C-1.09206 24.6695 -1.09206 17.9969 3.27618 14.4367L8.72247 9.99822C9.19001 9.61718 9.61782 9.18941 9.99884 8.72186L14.4363 3.27654ZM21.3338 6.41229C13.0923 6.41229 6.41107 13.0928 6.41095 21.3342C6.41095 29.5756 13.0923 36.257 21.3338 36.257C29.5752 36.2569 36.2567 29.5756 36.2567 21.3342C36.2565 13.0929 29.5752 6.41243 21.3338 6.41229Z"
              fill="white"
            />
          </svg>
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
