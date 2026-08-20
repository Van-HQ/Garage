"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { Car, Loader2, Mail, Lock, CheckCircle2 } from "lucide-react";

type Mode = "signin" | "signup";

export default function LoginPage() {
  const router = useRouter();
  const [mode, setMode] = useState<Mode>("signin");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [status, setStatus] = useState<"idle" | "loading" | "check-email" | "error">("idle");
  const [error, setError] = useState("");

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setStatus("loading");
    setError("");
    const supabase = createClient();

    if (mode === "signin") {
      const { error } = await supabase.auth.signInWithPassword({ email, password });
      if (error) {
        setError(error.message);
        setStatus("error");
        return;
      }
      router.push("/");
      router.refresh();
      return;
    }

    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: { emailRedirectTo: `${window.location.origin}/auth/callback` },
    });
    if (error) {
      setError(error.message);
      setStatus("error");
      return;
    }
    if (data.session) {
      router.push("/");
      router.refresh();
      return;
    }
    setStatus("check-email");
  }

  return (
    <main className="min-h-dvh flex items-center justify-center px-6">
      <div className="w-full max-w-sm">
        <div className="flex flex-col items-center gap-3 mb-8">
          <div className="glass-panel w-16 h-16 rounded-[22px] flex items-center justify-center">
            <Car className="w-8 h-8 text-accent" strokeWidth={1.75} />
          </div>
          <h1 className="text-2xl font-semibold tracking-tight">Garage</h1>
          <p className="text-sm text-muted text-center">
            {mode === "signin" ? "Sign in to track your vehicles" : "Create an account"}
          </p>
        </div>

        <div className="glass-panel rounded-[28px] p-6">
          {status === "check-email" ? (
            <div className="flex flex-col items-center gap-3 py-4 text-center">
              <CheckCircle2 className="w-9 h-9 text-accent" strokeWidth={1.5} />
              <p className="font-medium">Confirm your email</p>
              <p className="text-sm text-muted">
                We sent a confirmation link to {email}. Once confirmed, sign in with your password.
              </p>
            </div>
          ) : (
            <form onSubmit={submit} className="flex flex-col gap-4">
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
                    className="bg-transparent outline-none w-0 min-w-full text-sm"
                  />
                </div>
              </label>

              <label className="flex flex-col gap-2">
                <span className="text-xs font-medium text-muted uppercase tracking-wide">Password</span>
                <div className="glass-input flex items-center gap-2 px-4 py-3 rounded-2xl">
                  <Lock className="w-4 h-4 text-muted shrink-0" />
                  <input
                    type="password"
                    required
                    minLength={6}
                    autoComplete={mode === "signin" ? "current-password" : "new-password"}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="••••••••"
                    className="bg-transparent outline-none w-0 min-w-full text-sm"
                  />
                </div>
              </label>

              {error && <p className="text-xs text-red-400">{error}</p>}

              <button
                type="submit"
                disabled={status === "loading"}
                className="btn-accent rounded-2xl py-3 text-sm font-medium flex items-center justify-center gap-2 disabled:opacity-60"
              >
                {status === "loading" && <Loader2 className="w-4 h-4 animate-spin" />}
                {mode === "signin" ? "Sign in" : "Create account"}
              </button>

              <button
                type="button"
                onClick={() => {
                  setMode(mode === "signin" ? "signup" : "signin");
                  setError("");
                }}
                className="text-xs text-muted"
              >
                {mode === "signin" ? "Need an account? Create one" : "Already have an account? Sign in"}
              </button>
            </form>
          )}
        </div>
      </div>
    </main>
  );
}
