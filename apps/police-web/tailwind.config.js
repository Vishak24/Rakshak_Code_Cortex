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
          950: '#0B0F17',
          900: '#111724',
          800: '#1A2333',
          700: '#253248',
          600: '#32435F',
        },
        police: {
          teal: '#00D4B4',
          cyan: '#00D4FF',
          amber: '#F59E0B',
          red: '#EF4444',
          green: '#22C55E',
        }
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
      }
    },
  },
  plugins: [],
}
