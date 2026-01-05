import React from 'react';

// Crop-based icons for kolkhoz theme

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

// Suit icon paths - using <img> tags for iOS compatibility
const SUIT_PATHS = {
  Wheat: 'assets/suits/wheat.svg',
  Sunflower: 'assets/suits/sunflower.svg',
  Potato: 'assets/suits/potato.svg',
  Beet: 'assets/suits/beet.svg',
};

export function SuitIcon({ suit, className = '' }) {
  if (!suit) {
    return <span className={className}>?</span>;
  }
  // Normalize suit name to match SUIT_PATHS keys (capitalize first letter)
  const normalizedSuit = suit.charAt(0).toUpperCase() + suit.slice(1).toLowerCase();
  const iconPath = SUIT_PATHS[normalizedSuit];
  if (!iconPath) {
    console.warn('SuitIcon: Unknown suit:', suit);
    return <span className={className}>?</span>;
  }
  return (
    <span className={`suit-icon ${normalizedSuit.toLowerCase()} ${className}`}>
      <img src={iconPath} alt={normalizedSuit} className="suit-svg" />
    </span>
  );
}

export default SuitIcon;
