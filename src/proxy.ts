import { type NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/middleware";

export async function proxy(request: NextRequest) {
  // No Supabase project configured yet — skip the auth gate so /login's
  // demo data (see lib/demo-data.ts) can be previewed without credentials.
  if (process.env.NEXT_PUBLIC_SUPABASE_URL?.includes("placeholder")) {
    return;
  }
  return updateSession(request);
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|manifest.json|icons|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)"],
};
