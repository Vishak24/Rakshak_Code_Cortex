/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        dark: {
          950: '#070A10',
          900: '#0C101B',
          800: '#141A29',
          700: '#1E2638',
          600: '#2A344B',
        },
        brand: {
          red: '#FF2E54',
          cyan: '#00D4FF',
          emerald: '#00E6A5',
          amber: '#F59E0B',
          purple: '#8B5CF6',
        }
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
      },
      animation: {
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'ripple': 'ripple 2s cubic-bezier(0, 0.2, 0.8, 1) infinite',
        'glow': 'glow 2s ease-in-out infinite alternate',
      },
      keyframes: {
        ripple: {
          '0%': { transform: 'scale(0.8)', opacity: '1' },
          '100%': { transform: 'scale(2.2)', opacity: '0' },
        },
        glow: {
          '0%': { boxShadow: '0 0 15px rgba(255, 46, 84, 0.4)' },
          '100%': { boxShadow: '0 0 35px rgba(255, 46, 84, 0.8)' },
        }
      }
    },
  },
  plugins: [],
}
