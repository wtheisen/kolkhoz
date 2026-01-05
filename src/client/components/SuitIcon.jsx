import React from 'react';

// Crop-based suit icons for kolkhoz theme
// Wheat & Sunflower = cream/gold suits
// Potato & Beet = red suits

// Explicit colors for iOS Safari compatibility (currentColor inheritance is unreliable)
const CREAM = '#e8dcc4';
const RED = '#c41e3a';

// ============================================
// Navigation Icons - Soviet themed, monochrome
// ============================================

const MenuIcon = () => (
  <svg viewBox="0 0 24 24" width="24" height="24" className="nav-svg">
    <rect x="3" y="5" width="18" height="2" rx="1" fill="currentColor"/>
    <rect x="3" y="11" width="18" height="2" rx="1" fill="currentColor"/>
    <rect x="3" y="17" width="18" height="2" rx="1" fill="currentColor"/>
  </svg>
);

const BrigadeIcon = () => (
  <svg viewBox="0 0 24 24" width="24" height="24" className="nav-svg">
    {/* Central figure */}
    <circle cx="12" cy="7" r="3" fill="currentColor"/>
    <path d="M7 20 L12 13 L17 20 Z" fill="currentColor"/>
    {/* Left figure */}
    <circle cx="5" cy="10" r="2.2" fill="currentColor"/>
    <path d="M2 19 L5 14 L8 19 Z" fill="currentColor"/>
    {/* Right figure */}
    <circle cx="19" cy="10" r="2.2" fill="currentColor"/>
    <path d="M16 19 L19 14 L22 19 Z" fill="currentColor"/>
  </svg>
);

const FieldsIcon = () => (
  <svg viewBox="0 0 24 24" width="24" height="24" className="nav-svg">
    {/* Wheat stalks in field rows */}
    <path d="M4 20 L20 20" stroke="currentColor" strokeWidth="2" fill="none"/>
    {/* Left wheat */}
    <path d="M7 20 L7 12" stroke="currentColor" strokeWidth="1.5" fill="none"/>
    <ellipse cx="5.5" cy="10" rx="1.8" ry="1" transform="rotate(-30 5.5 10)" fill="currentColor"/>
    <ellipse cx="8.5" cy="10" rx="1.8" ry="1" transform="rotate(30 8.5 10)" fill="currentColor"/>
    <ellipse cx="7" cy="8" rx="1.2" ry="2" fill="currentColor"/>
    {/* Right wheat */}
    <path d="M17 20 L17 12" stroke="currentColor" strokeWidth="1.5" fill="none"/>
    <ellipse cx="15.5" cy="10" rx="1.8" ry="1" transform="rotate(-30 15.5 10)" fill="currentColor"/>
    <ellipse cx="18.5" cy="10" rx="1.8" ry="1" transform="rotate(30 18.5 10)" fill="currentColor"/>
    <ellipse cx="17" cy="8" rx="1.2" ry="2" fill="currentColor"/>
    {/* Center wheat */}
    <path d="M12 20 L12 10" stroke="currentColor" strokeWidth="1.5" fill="none"/>
    <ellipse cx="10.5" cy="8" rx="1.8" ry="1" transform="rotate(-30 10.5 8)" fill="currentColor"/>
    <ellipse cx="13.5" cy="8" rx="1.8" ry="1" transform="rotate(30 13.5 8)" fill="currentColor"/>
    <ellipse cx="12" cy="6" rx="1.2" ry="2" fill="currentColor"/>
  </svg>
);

const NorthIcon = () => (
  <svg viewBox="0 0 24 24" width="24" height="24" className="nav-svg">
    {/* Snowflake - 6 spokes with arms */}
    <rect x="11" y="2" width="2" height="20" rx="1" fill="currentColor"/>
    <rect x="2" y="11" width="20" height="2" rx="1" fill="currentColor"/>
    <rect x="11" y="2" width="2" height="20" rx="1" transform="rotate(60 12 12)" fill="currentColor"/>
    <rect x="11" y="2" width="2" height="20" rx="1" transform="rotate(-60 12 12)" fill="currentColor"/>
    {/* Small diamonds at tips */}
    <circle cx="12" cy="12" r="2" fill="currentColor"/>
  </svg>
);

const CellarIcon = () => (
  <svg viewBox="0 0 24 24" width="24" height="24" className="nav-svg">
    {/* Stairs going down */}
    <path d="M4 4 L4 8 L8 8 L8 12 L12 12 L12 16 L16 16 L16 20 L20 20"
          stroke="currentColor" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
    {/* Door frame at top */}
    <path d="M2 2 L2 8 L4 8" stroke="currentColor" strokeWidth="1.5" fill="none"/>
    <path d="M2 2 L8 2" stroke="currentColor" strokeWidth="1.5" fill="none"/>
  </svg>
);

export function NavIcon({ type, className = '' }) {
  const icons = {
    menu: MenuIcon,
    brigade: BrigadeIcon,
    fields: FieldsIcon,
    north: NorthIcon,
    cellar: CellarIcon,
  };

  const IconComponent = icons[type];
  if (!IconComponent) {
    return <span className={className}>?</span>;
  }
  return (
    <span className={`nav-icon-wrapper ${className}`}>
      <IconComponent />
    </span>
  );
}

const WheatIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" className="suit-svg">
    <path d="M12 2 L12 22" stroke={CREAM} strokeWidth="1.5" fill="none"/>
    <ellipse cx="9" cy="5" rx="2.5" ry="1.2" transform="rotate(-30 9 5)" fill={CREAM}/>
    <ellipse cx="8.5" cy="8" rx="2.5" ry="1.2" transform="rotate(-25 8.5 8)" fill={CREAM}/>
    <ellipse cx="9" cy="11" rx="2.5" ry="1.2" transform="rotate(-20 9 11)" fill={CREAM}/>
    <ellipse cx="15" cy="5" rx="2.5" ry="1.2" transform="rotate(30 15 5)" fill={CREAM}/>
    <ellipse cx="15.5" cy="8" rx="2.5" ry="1.2" transform="rotate(25 15.5 8)" fill={CREAM}/>
    <ellipse cx="15" cy="11" rx="2.5" ry="1.2" transform="rotate(20 15 11)" fill={CREAM}/>
    <ellipse cx="12" cy="3" rx="1.8" ry="2.5" fill={CREAM}/>
  </svg>
);

const SunflowerIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" className="suit-svg">
    <circle cx="12" cy="10" r="4" fill={CREAM}/>
    <ellipse cx="12" cy="3" rx="2" ry="3" fill={CREAM}/>
    <ellipse cx="17" cy="5" rx="2" ry="3" transform="rotate(45 17 5)" fill={CREAM}/>
    <ellipse cx="19" cy="10" rx="3" ry="2" fill={CREAM}/>
    <ellipse cx="17" cy="15" rx="2" ry="3" transform="rotate(-45 17 15)" fill={CREAM}/>
    <ellipse cx="12" cy="17" rx="2" ry="3" fill={CREAM}/>
    <ellipse cx="7" cy="15" rx="2" ry="3" transform="rotate(45 7 15)" fill={CREAM}/>
    <ellipse cx="5" cy="10" rx="3" ry="2" fill={CREAM}/>
    <ellipse cx="7" cy="5" rx="2" ry="3" transform="rotate(-45 7 5)" fill={CREAM}/>
    <path d="M12 14 L12 23" stroke={CREAM} strokeWidth="2" fill="none"/>
  </svg>
);

const PotatoIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" className="suit-svg">
    <path d="M12 3 C6 3 3 8 3 12 C3 17 6 21 12 21 C18 21 21 17 21 12 C21 8 18 3 12 3 Z" fill={RED}/>
    <circle cx="8" cy="9" r="1" fill="none" stroke={RED} strokeWidth="0.8" opacity="0.6"/>
    <circle cx="15" cy="11" r="0.8" fill="none" stroke={RED} strokeWidth="0.8" opacity="0.6"/>
    <circle cx="10" cy="15" r="0.9" fill="none" stroke={RED} strokeWidth="0.8" opacity="0.6"/>
  </svg>
);

const BeetIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" className="suit-svg">
    <path d="M12 8 C7 8 5 12 6 16 C7 19 10 22 12 22 C14 22 17 19 18 16 C19 12 17 8 12 8 Z" fill={RED}/>
    <path d="M10 8 C9 5 7 3 6 2 C8 3 10 4 11 7" fill={RED}/>
    <path d="M12 7 C12 4 12 2 12 1 C12 2 12 4 12 7" fill={RED}/>
    <path d="M14 8 C15 5 17 3 18 2 C16 3 14 4 13 7" fill={RED}/>
    <path d="M8 12 Q12 13 16 12" stroke={RED} strokeWidth="0.5" fill="none" opacity="0.4"/>
    <path d="M9 15 Q12 16 15 15" stroke={RED} strokeWidth="0.5" fill="none" opacity="0.4"/>
  </svg>
);

const SUIT_ICONS = {
  Wheat: WheatIcon,
  Sunflower: SunflowerIcon,
  Potato: PotatoIcon,
  Beet: BeetIcon,
};

export function SuitIcon({ suit, className = '' }) {
  if (!suit) {
    return <span className={className}>?</span>;
  }
  // Normalize suit name to match SUIT_ICONS keys (capitalize first letter)
  const normalizedSuit = suit.charAt(0).toUpperCase() + suit.slice(1).toLowerCase();
  const IconComponent = SUIT_ICONS[normalizedSuit];
  if (!IconComponent) {
    console.warn('SuitIcon: Unknown suit:', suit);
    return <span className={className}>?</span>;
  }
  return (
    <span className={`suit-icon ${normalizedSuit.toLowerCase()} ${className}`}>
      <IconComponent />
    </span>
  );
}

export default SuitIcon;
