export default function VehicleGlyph({ icon, className }: { icon: string; className?: string }) {
  if (icon === "car") {
    return (
      <svg viewBox="0 0 240 120" fill="none" className={className}>
        <path
          d="M14,78 C14,66 14,58 24,54 L48,44 L64,22 C67,17.5 72,15 77.5,15 L158,15 C164,15 169.5,18 172.5,23 L188,46 C196,48 202,55 202,64 L202,78 Z"
          fill="currentColor"
        />
        <path d="M60,40 L74,21 L156,21 L172,42 Z" fill="#000" fillOpacity="0.3" />
        <rect x="14" y="70" width="188" height="8" fill="currentColor" />
        <circle cx="52" cy="80" r="17" fill="#0a0f14" />
        <circle cx="52" cy="80" r="7" fill="currentColor" fillOpacity="0.5" />
        <circle cx="168" cy="80" r="17" fill="#0a0f14" />
        <circle cx="168" cy="80" r="7" fill="currentColor" fillOpacity="0.5" />
      </svg>
    );
  }

  return (
    <svg viewBox="0 0 240 120" fill="none" className={className}>
      <path
        d="M10,78 L10,64 C10,58 12,54 16,50 C22,44 30,42 40,41 L70,38 L85,17 C88,12.5 93,10 98.5,10 L138,10 C143,10 147.5,12.5 150,17 L156,28 L200,28 C209,28 216,35 216,44 L216,64 C216,72 210,78 202,78 Z"
        fill="currentColor"
      />
      <path d="M90,34 L102,16 L136,16 L148,34 Z" fill="#000" fillOpacity="0.32" />
      <rect x="156" y="36" width="52" height="42" fill="currentColor" />
      <rect x="151" y="36" width="6" height="42" fill="#000" fillOpacity="0.24" />
      <rect x="10" y="70" width="206" height="8" fill="currentColor" />
      <circle cx="60" cy="80" r="17" fill="#15110c" />
      <circle cx="60" cy="80" r="7" fill="currentColor" fillOpacity="0.5" />
      <circle cx="184" cy="80" r="17" fill="#15110c" />
      <circle cx="184" cy="80" r="7" fill="currentColor" fillOpacity="0.5" />
      <rect x="106" y="4" width="26" height="6" rx="2" fill="currentColor" fillOpacity="0.85" />
    </svg>
  );
}
