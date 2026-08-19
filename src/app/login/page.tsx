"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { Car, Loader2, Mail, CheckCircle2 } from "lucide-react";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<"idle" | "sending" | "sent" | "error">("idle");
  const [error, setError] = useState("");

  async function sendLink(e: React.FormEvent) {
    e.preventDefault();
    setStatus("sending");
    setError("");
    const supabase = createClient();
    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: {
        emailRedirectTo: `${window.location.origin}/auth/callback`,
      },
    });
    if (error) {
      setError(error.message);
      setStatus("error");
    } else {
      setStatus("sent");
    }
  }

  return (
    <main className="min-h-dvh flex items-center justify-center px-6">
      <div className="w-full max-w-sm">
        <div className="flex flex-col items-center gap-3 mb-8">
          <div className="glass-panel w-16 h-16 rounded-[22px] flex items-center justify-center">
            <Car className="w-8 h-8 text-accent" strokeWidth={1.75} />
          </div>
          <h1 className="text-2xl font-semibold tracking-tight">Garage</h1>
          <p className="text-sm text-muted text-center">Sign in to track your vehicles</p>
        </div>

        <div className="glass-panel rounded-[28px] p-6">
          {status === "sent" ? (
            <div className="flex flex-col items-center gap-3 py-4 text-center">
              <CheckCircle2 className="w-9 h-9 text-accent" strokeWidth={1.5} />
              <p className="font-medium">Check your email</p>
              <p className="text-sm text-muted">We sent a sign-in link to {email}</p>
            </div>
          ) : (
            <form onSubmit={sendLink} className="flex flex-col gap-4">
              <label className="flex flex-col gap-2">
                <span className="text-xs font-medium text-muted uppercase tracking-wide">Email</span>
                <div className="glass-input flex items-center gap-2 px-4 py-3 rounded-2xl">
                  <Mail className="w-4 h-4 text-muted shrink-0" />
                  <input
                    type="email"
                    required
                    autoFocus
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="you@example.com"
                    className="bg-transparent outline-none w-full min-w-0 text-sm"
                  />
                </div>
              </label>
              {error && <p className="text-xs text-red-400">{error}</p>}
              <button
                type="submit"
                disabled={status === "sending"}
                className="btn-accent rounded-2xl py-3 text-sm font-medium flex items-center justify-center gap-2 disabled:opacity-60"
              >
                {status === "sending" && <Loader2 className="w-4 h-4 animate-spin" />}
                Send sign-in link
              </button>
            </form>
          )}
        </div>
      </div>
    </main>
  );
}
