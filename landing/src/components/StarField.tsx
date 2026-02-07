"use client";

import { useEffect, useState } from "react";

export default function StarField() {
  const [stars, setStars] = useState<
    { left: string; top: string; delay: string; opacity: number }[]
  >([]);

  useEffect(() => {
    setStars(
      Array.from({ length: 50 }, () => ({
        left: `${Math.random() * 100}%`,
        top: `${Math.random() * 100}%`,
        delay: `${Math.random() * 3}s`,
        opacity: Math.random() * 0.7 + 0.3,
      }))
    );
  }, []);

  return (
    <div className="absolute inset-0 overflow-hidden pointer-events-none">
      {stars.map((star, i) => (
        <div
          key={i}
          className="star absolute w-1 h-1 bg-white rounded-full"
          style={{
            left: star.left,
            top: star.top,
            animationDelay: star.delay,
            opacity: star.opacity,
          }}
        />
      ))}
    </div>
  );
}
