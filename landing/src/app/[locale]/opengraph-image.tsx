import { ImageResponse } from "next/og";

export const runtime = "edge";
export const alt = "CTO Orchestrator — Rick Sanchez als je CTO";
export const size = {
  width: 1200,
  height: 630,
};
export const contentType = "image/png";

export default async function Image() {
  return new ImageResponse(
    (
      <div
        style={{
          background: "linear-gradient(135deg, #0a0a0f 0%, #1a1a2e 50%, #16213e 100%)",
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          fontFamily: "system-ui",
          position: "relative",
        }}
      >
        {/* Stars effect */}
        <div
          style={{
            position: "absolute",
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            display: "flex",
            flexWrap: "wrap",
          }}
        >
          {[...Array(30)].map((_, i) => (
            <div
              key={i}
              style={{
                position: "absolute",
                width: 4,
                height: 4,
                borderRadius: "50%",
                background: "white",
                opacity: 0.3 + Math.random() * 0.4,
                left: `${(i * 37) % 100}%`,
                top: `${(i * 23) % 100}%`,
              }}
            />
          ))}
        </div>

        {/* Portal icon */}
        <div
          style={{
            fontSize: 120,
            marginBottom: 20,
          }}
        >
          🧪
        </div>

        {/* Title */}
        <div
          style={{
            fontSize: 72,
            fontWeight: "bold",
            color: "#39ff14",
            textShadow: "0 0 30px rgba(57, 255, 20, 0.5)",
            marginBottom: 10,
          }}
        >
          Rick Sanchez
        </div>

        <div
          style={{
            fontSize: 48,
            fontWeight: "bold",
            color: "white",
            marginBottom: 30,
          }}
        >
          CTO Orchestrator
        </div>

        {/* Subtitle */}
        <div
          style={{
            fontSize: 28,
            color: "#a8d8ea",
            maxWidth: 800,
            textAlign: "center",
            lineHeight: 1.4,
          }}
        >
          De genialste CTO in het multiversum stuurt je project aan
          via een leger van Morty sub-agents
        </div>

        {/* Bottom tagline */}
        <div
          style={{
            position: "absolute",
            bottom: 40,
            fontSize: 24,
            color: "#f0e14a",
            fontWeight: "bold",
          }}
        >
          Wubba Lubba Dub Dub! 🛸
        </div>
      </div>
    ),
    {
      ...size,
    }
  );
}
