import Link from 'next/link';
import { ShieldCheck } from 'lucide-react';

// Self-service sign-up is disabled: an admin creates accounts from
// Admin → Users, which issues the initial email and password directly.
export default function RegisterPage() {
  return (
    <div className="w-full flex-1 min-h-screen flex items-center justify-center bg-[#dde6ed] p-4">
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-40 -left-40 w-80 h-80 bg-[#9db2bf] rounded-full blur-3xl opacity-20" />
        <div className="absolute -bottom-40 -right-40 w-80 h-80 bg-[#526d82] rounded-full blur-3xl opacity-15" />
      </div>

      <div className="relative bg-white/95 backdrop-blur-sm rounded-2xl shadow-2xl w-full max-w-md p-8 text-center">
        <div className="flex justify-center mb-6">
          <div className="w-16 h-16 rounded-2xl bg-[#526d82] flex items-center justify-center shadow-lg shadow-slate-500/25">
            <ShieldCheck className="w-8 h-8 text-white" />
          </div>
        </div>
        <h1 className="text-2xl font-bold text-slate-900 mb-2">Sign-up is by invitation only</h1>
        <p className="text-sm text-slate-500 mb-8">
          Your school&apos;s admin creates your account and gives you your email
          and password. Ask them to add you from Admin → Users, then log in
          with those details.
        </p>

        <Link
          href="/login"
          className="inline-flex w-full items-center justify-center bg-[#526d82] hover:bg-[#27374d] text-white font-semibold py-3 rounded-xl text-sm shadow-lg shadow-slate-500/25"
        >
          Back to log in
        </Link>
      </div>
    </div>
  );
}
