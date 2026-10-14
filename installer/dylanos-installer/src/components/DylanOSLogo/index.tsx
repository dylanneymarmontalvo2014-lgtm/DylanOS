import logoImg from "@/assets/logos/dylanos-logo.png";

interface LogoProps {
  size?: number;
}

export default function DylanOSLogo({ size = 56 }: LogoProps) {
  return (
    <img
      src={logoImg}
      alt="DylanOS logo"
      width={size}
      height={size}
      style={{ objectFit: "contain", display: "block" }}
    />
  );
}
