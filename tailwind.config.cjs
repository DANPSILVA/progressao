module.exports = {
  content: [
    './app/**/*.{ts,tsx,js,jsx,mdx}',
    './src/**/*.{ts,tsx,js,jsx,mdx}',
    './components/**/*.{ts,tsx,js,jsx}'
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        // Tibia-inspired palette (warm, earthy + modern accents)
        'bg-900': '#081014',
        'bg-800': '#0b1a1a',
        'surface-700': 'rgba(255,255,255,0.02)',
        'glass': 'rgba(255,255,255,0.03)',
        'accent': '#E8B93D', // trophy gold accent
        'accent-2': '#F0C24B', // lighter gold
        'neon': '#00E0FF',
        'muted-300': '#9aa6a6',
        'text-100': '#E6F3FF',
        'series-1': '#3987e5',
        'series-2': '#008300',
        'series-3': '#d55181',
        'series-4': '#c98500',
        'series-5': '#199e70',
        'series-6': '#d95926',
        'series-7': '#9085e9',
        'series-8': '#e66767'
      },
      borderRadius: {
        sm: '8px',
        md: '12px',
        lg: '16px',
        xl: '22px'
      },
      boxShadow: {
        low: '0 6px 20px rgba(2,6,23,0.55)',
        glow: '0 10px 30px rgba(155,214,107,0.06)'
      },
      keyframes: {
        'pop': {
          '0%': { transform: 'scale(0.985)', opacity: '0' },
          '100%': { transform: 'scale(1)', opacity: '1' }
        }
      },
      animation: {
        pop: 'pop 180ms cubic-bezier(.2,.9,.2,1)'
      }
    }
  },
  plugins: []
};
