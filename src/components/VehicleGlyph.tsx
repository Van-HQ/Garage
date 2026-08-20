export default function VehicleGlyph({ icon, className }: { icon: string; className?: string }) {
  const datum = (
    <line x1="4" y1="80" x2="236" y2="80" stroke="currentColor" strokeWidth="1" strokeOpacity="0.3" strokeDasharray="1 5" strokeLinecap="round" />
  );

  function wheel(cx: number) {
    return (
      <g key={cx} stroke="currentColor" fill="none">
        <circle cx={cx} cy="80" r="17" strokeWidth="2" />
        <circle cx={cx} cy="80" r="5" strokeWidth="1.5" />
        {[0, 60, 120].map((deg) => (
          <line
            key={deg}
            x1={cx + 5 * Math.cos((deg * Math.PI) / 180)}
            y1={80 + 5 * Math.sin((deg * Math.PI) / 180)}
            x2={cx + 15 * Math.cos((deg * Math.PI) / 180)}
            y2={80 + 15 * Math.sin((deg * Math.PI) / 180)}
            strokeWidth="1.2"
          />
        ))}
        {[0, 60, 120].map((deg) => (
          <line
            key={"b" + deg}
            x1={cx - 5 * Math.cos((deg * Math.PI) / 180)}
            y1={80 - 5 * Math.sin((deg * Math.PI) / 180)}
            x2={cx - 15 * Math.cos((deg * Math.PI) / 180)}
            y2={80 - 15 * Math.sin((deg * Math.PI) / 180)}
            strokeWidth="1.2"
          />
        ))}
      </g>
    );
  }

  if (icon === "car") {
    return (
      <svg viewBox="0 0 240 120" fill="none" className={className}>
        {datum}
        <path
          d="M14,78 C14,66 14,58 24,54 L48,44 L64,22 C67,17.5 72,15 77.5,15 L158,15 C164,15 169.5,18 172.5,23 L188,46 C196,48 202,55 202,64 L202,78 Z"
          stroke="currentColor"
          strokeWidth="2.5"
          strokeLinejoin="round"
        />
        <path d="M60,40 L74,21 L156,21 L172,42 Z" stroke="currentColor" strokeWidth="1.4" strokeOpacity="0.75" />
        <line x1="116" y1="21" x2="116" y2="40" stroke="currentColor" strokeWidth="1" strokeOpacity="0.5" />
        <line x1="14" y1="70" x2="202" y2="70" stroke="currentColor" strokeWidth="1.4" strokeOpacity="0.8" />
        <line x1="72" y1="20" x2="76" y2="4" stroke="currentColor" strokeWidth="1" strokeOpacity="0.4" strokeDasharray="1 3" />
        {wheel(52)}
        {wheel(168)}
      </svg>
    );
  }

  return (
    <svg viewBox="0 0 240 120" fill="none" className={className}>
      {datum}
      <path
        d="M10,78 L10,64 C10,58 12,54 16,50 C22,44 30,42 40,41 L70,38 L85,17 C88,12.5 93,10 98.5,10 L138,10 C143,10 147.5,12.5 150,17 L156,28 L200,28 C209,28 216,35 216,44 L216,64 C216,72 210,78 202,78 Z"
        stroke="currentColor"
        strokeWidth="2.5"
        strokeLinejoin="round"
      />
      <path d="M90,34 L102,16 L136,16 L148,34 Z" stroke="currentColor" strokeWidth="1.4" strokeOpacity="0.75" />
      <line x1="117" y1="16" x2="117" y2="34" stroke="currentColor" strokeWidth="1" strokeOpacity="0.5" />
      <line x1="151" y1="28" x2="151" y2="78" stroke="currentColor" strokeWidth="1.4" strokeOpacity="0.8" />
      <line x1="10" y1="70" x2="216" y2="70" stroke="currentColor" strokeWidth="1.4" strokeOpacity="0.8" />
      <rect x="106" y="4" width="26" height="6" rx="2" stroke="currentColor" strokeWidth="1.2" strokeOpacity="0.7" />
      <line x1="98" y1="9" x2="94" y2="1" stroke="currentColor" strokeWidth="1" strokeOpacity="0.4" strokeDasharray="1 3" />
      {wheel(60)}
      {wheel(184)}
    </svg>
  );
}
