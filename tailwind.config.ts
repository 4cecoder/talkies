import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        // Design tokens for consistent color usage
        background: {
          DEFAULT: "#0a0a0f",
          card: "rgba(255, 255, 255, 0.05)",
          "card-hover": "rgba(255, 255, 255, 0.08)",
          input: "rgba(255, 255, 255, 0.05)",
        },
        border: {
          DEFAULT: "rgba(255, 255, 255, 0.1)",
          hover: "rgba(255, 255, 255, 0.2)",
          focus: "rgba(168, 85, 247, 0.5)", // purple-500/50
        },
        text: {
          primary: "#ffffff",
          secondary: "rgba(255, 255, 255, 0.7)",
          tertiary: "rgba(255, 255, 255, 0.5)",
          muted: "rgba(255, 255, 255, 0.4)",
        },
        accent: {
          purple: "#a855f7",
          pink: "#ec4899",
          blue: "#3b82f6",
          cyan: "#06b6d4",
          orange: "#f97316",
        },
      },
      borderRadius: {
        card: "1.5rem", // 24px
        button: "0.75rem", // 12px
        input: "0.75rem", // 12px
      },
      boxShadow: {
        glow: "0 0 40px rgba(168, 85, 247, 0.3)",
        "glow-sm": "0 0 20px rgba(168, 85, 247, 0.2)",
        card: "0 8px 32px rgba(0, 0, 0, 0.12)",
        "card-hover": "0 12px 48px rgba(0, 0, 0, 0.2)",
      },
      animation: {
        "gradient-shift": "gradient-shift 8s ease infinite",
        "gradient-fast": "gradient-fast 4s ease infinite",
        "glow-pulse": "glow-pulse 3s ease-in-out infinite",
        "fade-in": "fade-in 0.3s ease-out",
        "slide-up": "slide-up 0.3s ease-out",
        "scale-in": "scale-in 0.2s ease-out",
      },
      keyframes: {
        "gradient-shift": {
          "0%, 100%": { backgroundPosition: "0% 50%" },
          "50%": { backgroundPosition: "100% 50%" },
        },
        "gradient-fast": {
          "0%, 100%": { backgroundPosition: "0% 50%" },
          "50%": { backgroundPosition: "100% 50%" },
        },
        "glow-pulse": {
          "0%, 100%": { opacity: "0.5", transform: "scale(1)" },
          "50%": { opacity: "0.8", transform: "scale(1.05)" },
        },
        "fade-in": {
          "0%": { opacity: "0" },
          "100%": { opacity: "1" },
        },
        "slide-up": {
          "0%": { transform: "translateY(10px)", opacity: "0" },
          "100%": { transform: "translateY(0)", opacity: "1" },
        },
        "scale-in": {
          "0%": { transform: "scale(0.95)", opacity: "0" },
          "100%": { transform: "scale(1)", opacity: "1" },
        },
      },
      transitionTimingFunction: {
        "smooth": "cubic-bezier(0.4, 0, 0.2, 1)",
        "bounce-soft": "cubic-bezier(0.34, 1.56, 0.64, 1)",
      },
      backdropBlur: {
        glass: "24px",
      },
    },
  },
  plugins: [],
};

export default config;
