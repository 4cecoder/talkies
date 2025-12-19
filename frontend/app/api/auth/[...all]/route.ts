import { NextRequest, NextResponse } from "next/server";
import { handler } from "@/app/lib/auth-server";

type HandlerType = {
  GET: (req: Request) => Promise<Response>;
  POST: (req: Request) => Promise<Response>;
};

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ all: string[] }> }
) {
  await params;

  if (handler && typeof handler === 'object' && 'GET' in handler) {
    return (handler as HandlerType).GET(request);
  }

  return NextResponse.json({ error: "Not found" }, { status: 404 });
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ all: string[] }> }
) {
  await params;

  if (handler && typeof handler === 'object' && 'POST' in handler) {
    return (handler as HandlerType).POST(request);
  }

  return NextResponse.json({ error: "Not found" }, { status: 404 });
}
