import { httpRouter } from "convex/server";
import { registerRoutes } from "@convex-dev/better-auth";
import { auth } from "./auth";
import { components } from "./_generated/api";

const http = httpRouter();

// Register Better Auth routes
registerRoutes(http, auth, { components });

export default http;
