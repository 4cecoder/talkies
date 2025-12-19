import { betterAuth } from "better-auth";
import { convexAdapter } from "@convex-dev/better-auth/adapter";
import { convex } from "@convex-dev/better-auth/plugins";
import { components } from "./_generated/api";

export const auth = betterAuth({
  database: convexAdapter({ components }),
  emailAndPassword: {
    enabled: true,
    requireEmailVerification: false,
  },
  plugins: [convex()],
  trustedOrigins: [
    process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000",
  ],
});
