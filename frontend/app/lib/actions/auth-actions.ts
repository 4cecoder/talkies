"use server";

import { z } from "zod";
import { signInSchema, signUpSchema } from "../validations/auth";
import { headers, cookies } from "next/headers";

// Server-side validation and auth actions for extra security
// These actions validate on the server before forwarding to BetterAuth

interface ActionResult<T = unknown> {
  success: boolean;
  data?: T;
  error?: string;
  fieldErrors?: Record<string, string[]>;
}

export async function signInAction(
  formData: z.infer<typeof signInSchema>
): Promise<ActionResult> {
  try {
    // Server-side validation
    const validatedData = signInSchema.safeParse(formData);

    if (!validatedData.success) {
      return {
        success: false,
        error: "Validation failed",
        fieldErrors: validatedData.error.flatten().fieldErrors,
      };
    }

    const { email, password } = validatedData.data;

    // Get the site URL for auth requests
    const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000";

    // Forward to BetterAuth API
    const response = await fetch(`${siteUrl}/api/auth/sign-in/email`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(await getForwardedHeaders()),
      },
      body: JSON.stringify({ email, password }),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      return {
        success: false,
        error: errorData.message || "Invalid email or password",
      };
    }

    const data = await response.json();

    // Set auth cookies from response
    const setCookieHeader = response.headers.get("set-cookie");
    if (setCookieHeader) {
      await handleSetCookies(setCookieHeader);
    }

    return {
      success: true,
      data,
    };
  } catch (error) {
    console.error("Sign in error:", error);
    return {
      success: false,
      error: "An unexpected error occurred. Please try again.",
    };
  }
}

export async function signUpAction(
  formData: z.infer<typeof signUpSchema>
): Promise<ActionResult> {
  try {
    // Server-side validation
    const validatedData = signUpSchema.safeParse(formData);

    if (!validatedData.success) {
      return {
        success: false,
        error: "Validation failed",
        fieldErrors: validatedData.error.flatten().fieldErrors,
      };
    }

    const { name, email, password } = validatedData.data;

    // Get the site URL for auth requests
    const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000";

    // Forward to BetterAuth API
    const response = await fetch(`${siteUrl}/api/auth/sign-up/email`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(await getForwardedHeaders()),
      },
      body: JSON.stringify({ name, email, password }),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      return {
        success: false,
        error: errorData.message || "Failed to create account",
      };
    }

    const data = await response.json();

    // Set auth cookies from response
    const setCookieHeader = response.headers.get("set-cookie");
    if (setCookieHeader) {
      await handleSetCookies(setCookieHeader);
    }

    return {
      success: true,
      data,
    };
  } catch (error) {
    console.error("Sign up error:", error);
    return {
      success: false,
      error: "An unexpected error occurred. Please try again.",
    };
  }
}

export async function signOutAction(): Promise<ActionResult> {
  try {
    const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000";

    const response = await fetch(`${siteUrl}/api/auth/sign-out`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(await getForwardedHeaders()),
      },
    });

    if (!response.ok) {
      return {
        success: false,
        error: "Failed to sign out",
      };
    }

    // Clear auth cookies
    const cookieStore = await cookies();
    cookieStore.delete("better-auth.session_token");

    return { success: true };
  } catch (error) {
    console.error("Sign out error:", error);
    return {
      success: false,
      error: "An unexpected error occurred",
    };
  }
}

export async function getSessionAction(): Promise<ActionResult> {
  try {
    const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000";

    const response = await fetch(`${siteUrl}/api/auth/get-session`, {
      method: "GET",
      headers: await getForwardedHeaders(),
    });

    if (!response.ok) {
      return { success: false, error: "Not authenticated" };
    }

    const data = await response.json();
    return { success: true, data };
  } catch (error) {
    console.error("Get session error:", error);
    return { success: false, error: "Failed to get session" };
  }
}

// Helper to get headers for forwarding cookies
async function getForwardedHeaders(): Promise<Record<string, string>> {
  const headersList = await headers();
  const cookieHeader = headersList.get("cookie");

  return cookieHeader ? { Cookie: cookieHeader } : {};
}

// Helper to handle setting cookies from response
async function handleSetCookies(setCookieHeader: string): Promise<void> {
  const cookieStore = await cookies();

  // Parse and set each cookie
  const cookieParts = setCookieHeader.split(",").map((c) => c.trim());

  for (const cookiePart of cookieParts) {
    const [nameValue] = cookiePart.split(";");
    const [name, value] = nameValue.split("=");

    if (name && value) {
      cookieStore.set(name.trim(), value.trim(), {
        httpOnly: true,
        secure: process.env.NODE_ENV === "production",
        sameSite: "lax",
        path: "/",
      });
    }
  }
}
