import { ImageResponse } from "next/og";

export const alt = "Rick Sanchez CTO Orchestrator — De genialste CTO in het multiversum";
export const size = {
  width: 1200,
  height: 630,
};
export const contentType = "image/png";

export default async function Image() {
  // Fetch the hero image
  const heroImageUrl = "https://ricksanchez.tech/hero-portal.png";

  return new ImageResponse(
    (
      <div
        style={{
          background: "linear-gradient(135deg, #0a0a0f 0%, #1a1a2e 50%, #0a0a0f 100%)",
          width: "100%",
          height: "100%",
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          fontFamily: "system-ui",
          position: "relative",
          padding: "40px 60px",
        }}
      >
        {/* Left side - Text content */}
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            justifyContent: "center",
            maxWidth: "55%",
          }}
        >
          {/* Title */}
          <div
            style={{
              fontSize: 64,
              fontWeight: "bold",
              color: "#39ff14",
              textShadow: "0 0 30px rgba(57, 255, 20, 0.5)",
              marginBottom: 8,
              lineHeight: 1.1,
            }}
          >
            Rick Sanchez
          </div>

          <div
            style={{
              fontSize: 42,
              fontWeight: "bold",
              color: "white",
              marginBottom: 24,
            }}
          >
            CTO Orchestrator
          </div>

          {/* Subtitle */}
          <div
            style={{
              fontSize: 24,
              color: "#a8d8ea",
              lineHeight: 1.4,
              marginBottom: 24,
            }}
          >
            De genialste CTO in het multiversum stuurt je project aan via een leger van Morty sub-agents
          </div>

          {/* Tagline */}
          <div
            style={{
              fontSize: 20,
              color: "#f0e14a",
              fontWeight: "bold",
            }}
          >
            Wubba Lubba Dub Dub! 🛸
          </div>
        </div>

        {/* Right side - Hero image */}
        <div
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            width: "45%",
            height: "100%",
          }}
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={heroImageUrl}
            alt="Rick and Morty"
            style={{
              maxHeight: "100%",
              maxWidth: "100%",
              objectFit: "contain",
            }}
          />
        </div>
      </div>
    ),
    {
      ...size,
    }
  );
}
