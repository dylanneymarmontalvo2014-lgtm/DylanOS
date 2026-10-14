import bannerImg from "@/assets/backgrounds/banner.png";
import type { CSSProperties } from "react";

interface HeroImageProps {
  className?: string;
  compact?: boolean;
  style?: CSSProperties;
}

export default function HeroImage({ className = "", style }: HeroImageProps) {
  return (
    <div
      className={`relative overflow-hidden rounded-xl ${className}`}
      style={style}
    >
      <img
        src={bannerImg}
        alt="DylanOS banner"
        className="w-full h-full object-cover"
        style={{ display: "block" }}
      />
    </div>
  );
}
